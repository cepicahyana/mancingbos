package server

import (
	"database/sql"
	"fmt"
	"net/http"
	"strings"
	"time"

	"indofish/internal/auth"
	"indofish/internal/httpx"
)

type bookingReq struct {
	EventID    int64  `json:"event_id"`
	StallID    int64  `json:"stall_id"`
	StallName  string `json:"stall_name"`
	RentalDate string `json:"rental_date"`
}

type bookingStatusReq struct {
	Status string `json:"status"`
}

const bookingSelect = `
	SELECT b.id, b.event_id, COALESCE(e.title, st.name, b.stall_name, 'Sewa harian'),
	       b.user_id, u.name, b.stall_id, COALESCE(NULLIF(b.stall_name,''), st.name, ''),
	       COALESCE(st.location, ''), COALESCE(st.daily_rent_price, 0),
	       COALESCE(DATE_FORMAT(b.rental_date, '%Y-%m-%d'), ''), b.status, b.created_at, b.updated_at
	FROM bookings b
	LEFT JOIN events e ON e.id = b.event_id
	LEFT JOIN stalls st ON st.id = b.stall_id
	JOIN users u ON u.id = b.user_id`

func (s *Server) listBookings(w http.ResponseWriter, r *http.Request) {
	page, perPage := httpx.PageParams(r)
	u := currentUser(r)
	where := []string{"1=1"}
	args := []any{}
	if !auth.IsAdmin(u.Role) {
		if u.Role == "owner" {
			where = append(where, "(b.user_id = ? OR e.owner_id = ? OR st.owner_id = ?)")
			args = append(args, u.ID, u.ID, u.ID)
		} else {
			where = append(where, "b.user_id = ?")
			args = append(args, u.ID)
		}
	}
	if status := strings.TrimSpace(r.URL.Query().Get("status")); status != "" {
		where = append(where, "b.status = ?")
		args = append(args, status)
	}
	clause := strings.Join(where, " AND ")
	var total int
	qCount := `
		SELECT COUNT(*) FROM bookings b
		LEFT JOIN events e ON e.id = b.event_id
		LEFT JOIN stalls st ON st.id = b.stall_id
		WHERE ` + clause
	if err := s.store.DB.QueryRow(qCount, args...).Scan(&total); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat sewa lapak")
		return
	}
	q := fmt.Sprintf(`%s WHERE %s ORDER BY b.created_at DESC LIMIT ? OFFSET ?`, bookingSelect, clause)
	args = append(args, perPage, (page-1)*perPage)
	rows, err := s.store.DB.Query(q, args...)
	if err != nil {
		// fallback skema lama tanpa stall_id / rental_date
		qOld := fmt.Sprintf(`
			SELECT b.id, b.event_id, e.title, b.user_id, u.name, NULL, b.stall_name, '', 0, '', b.status, b.created_at, b.updated_at
			FROM bookings b
			JOIN events e ON e.id = b.event_id
			JOIN users u ON u.id = b.user_id
			WHERE %s
			ORDER BY b.created_at DESC
			LIMIT ? OFFSET ?`, clause)
		rows, err = s.store.DB.Query(qOld, args...)
		if err != nil {
			httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat sewa harian")
			return
		}
	}
	defer rows.Close()
	list, err := scanBookings(rows)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat sewa lapak")
		return
	}
	httpx.Page(w, list, page, perPage, total)
}

func (s *Server) listEventBookings(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	ev, err := s.findEvent(id)
	if err != nil {
		httpx.Fail(w, http.StatusNotFound, "Event tidak ditemukan")
		return
	}
	u := currentUser(r)
	if !canManageEvent(u, ev.OwnerID) && !auth.IsAdmin(u.Role) && u.Role != "operator" {
		httpx.Fail(w, http.StatusForbidden, "Akses daftar sewa ditolak")
		return
	}
	rows, err := s.store.DB.Query(bookingSelect+` WHERE b.event_id = ? ORDER BY b.created_at DESC`, id)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat sewa lapak")
		return
	}
	defer rows.Close()
	list, err := scanBookings(rows)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat sewa lapak")
		return
	}
	httpx.OK(w, list, "OK")
}

func (s *Server) createBooking(w http.ResponseWriter, r *http.Request) {
	var req bookingReq
	if err := httpx.Decode(r, &req); err != nil {
		httpx.Fail(w, http.StatusBadRequest, "Body JSON tidak valid")
		return
	}
	req.StallName = strings.TrimSpace(req.StallName)
	req.RentalDate = strings.TrimSpace(req.RentalDate)

	// Path A: sewa lapak by tanggal (hotel-style)
	if req.StallID > 0 {
		s.createStallRental(w, r, req)
		return
	}
	// Path B: legacy sewa via event
	s.createEventRental(w, r, req)
}

func (s *Server) createStallRental(w http.ResponseWriter, r *http.Request, req bookingReq) {
	if _, err := time.Parse("2006-01-02", req.RentalDate); err != nil {
		httpx.Validation(w, map[string][]string{"rental_date": {"Tanggal sewa wajib (YYYY-MM-DD)"}})
		return
	}
	st, err := s.findStall(req.StallID)
	if err != nil || !st.Active {
		httpx.Fail(w, http.StatusNotFound, "Lapak tidak ditemukan atau tidak aktif")
		return
	}
	u := currentUser(r)
	if st.OwnerID == u.ID {
		httpx.Fail(w, http.StatusUnprocessableEntity, "Pemilik lapak tidak dapat menyewa lapak sendiri")
		return
	}
	av := s.stallDayAvailability(st.ID, st.Capacity, req.RentalDate)
	if av.BlockedByEvent {
		httpx.Fail(w, http.StatusUnprocessableEntity, "Lapak tidak tersedia — ada event/kompetisi di tanggal itu")
		return
	}
	if !av.Available {
		httpx.Fail(w, http.StatusUnprocessableEntity, "Kuota sewa penuh di tanggal itu")
		return
	}
	var prior int
	_ = s.store.DB.QueryRow(`
		SELECT COUNT(*) FROM bookings
		WHERE stall_id = ? AND user_id = ? AND SUBSTR(CAST(rental_date AS CHAR), 1, 10) = ? AND status IN ('pending','approved')`,
		st.ID, u.ID, req.RentalDate,
	).Scan(&prior)
	if prior > 0 {
		httpx.Fail(w, http.StatusUnprocessableEntity, "Kamu sudah memesan lapak ini di tanggal tersebut")
		return
	}

	now := s.store.Now()
	res, err := s.store.DB.Exec(
		`INSERT INTO bookings (event_id, user_id, stall_id, stall_name, rental_date, status, created_at, updated_at)
		 VALUES (NULL, ?, ?, ?, ?, 'pending', ?, ?)`,
		u.ID, st.ID, st.Name, req.RentalDate, now, now,
	)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal menyewa lapak")
		return
	}
	id, _ := res.LastInsertId()
	_ = s.addUserPoints(u.ID, 5)
	b, _ := s.findBooking(id)
	httpx.Created(w, b, "Permintaan sewa lapak terkirim")
}

func (s *Server) createEventRental(w http.ResponseWriter, r *http.Request, req bookingReq) {
	errs := map[string][]string{}
	if req.EventID < 1 {
		errs["event_id"] = []string{"Event atau lapak wajib dipilih"}
	}
	if req.StallName == "" {
		errs["stall_name"] = []string{"Nama/nomor lapak wajib diisi"}
	}
	if len(errs) > 0 {
		httpx.Validation(w, errs)
		return
	}
	ev, err := s.findEvent(req.EventID)
	if err != nil {
		httpx.Fail(w, http.StatusNotFound, "Event tidak ditemukan")
		return
	}
	if !ev.RentalEnabled {
		httpx.Fail(w, http.StatusUnprocessableEntity, "Event ini belum mengizinkan penyewaan lapak")
		return
	}
	if ev.StallID != nil && s.stallHasActiveEvent(*ev.StallID) {
		httpx.Fail(w, http.StatusUnprocessableEntity, "Lapak tidak bisa disewa saat ada event aktif")
		return
	}
	u := currentUser(r)
	if ev.OwnerID == u.ID {
		httpx.Fail(w, http.StatusUnprocessableEntity, "Pemilik event tidak dapat menyewa lapak sendiri")
		return
	}
	var taken int
	_ = s.store.DB.QueryRow(
		`SELECT COUNT(*) FROM bookings WHERE event_id = ? AND stall_name = ? AND status IN ('pending','approved')`,
		req.EventID, req.StallName,
	).Scan(&taken)
	if taken > 0 {
		httpx.Validation(w, map[string][]string{"stall_name": {"Lapak ini sudah dipesan"}})
		return
	}
	var prior int
	_ = s.store.DB.QueryRow(`SELECT COUNT(*) FROM bookings WHERE event_id = ? AND user_id = ?`, req.EventID, u.ID).Scan(&prior)

	now := s.store.Now()
	var stallID any
	if ev.StallID != nil {
		stallID = *ev.StallID
	}
	rentalDate := ev.Date
	if len(rentalDate) > 10 {
		rentalDate = rentalDate[:10]
	}
	res, err := s.store.DB.Exec(
		`INSERT INTO bookings (event_id, user_id, stall_id, stall_name, rental_date, status, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, 'pending', ?, ?)`,
		req.EventID, u.ID, stallID, req.StallName, rentalDate, now, now,
	)
	if err != nil {
		res, err = s.store.DB.Exec(
			`INSERT INTO bookings (event_id, user_id, stall_name, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)`,
			req.EventID, u.ID, req.StallName, "pending", now, now,
		)
		if err != nil {
			httpx.Fail(w, http.StatusInternalServerError, "Gagal menyewa lapak")
			return
		}
	}
	id, _ := res.LastInsertId()
	if prior == 0 {
		_ = s.addUserPoints(u.ID, 5)
	}
	b, _ := s.findBooking(id)
	httpx.Created(w, b, "Permintaan sewa lapak terkirim")
}

func (s *Server) updateBooking(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	b, err := s.findBooking(id)
	if err != nil {
		httpx.Fail(w, http.StatusNotFound, "Data sewa tidak ditemukan")
		return
	}
	var req bookingStatusReq
	if err := httpx.Decode(r, &req); err != nil {
		httpx.Fail(w, http.StatusBadRequest, "Body JSON tidak valid")
		return
	}
	req.Status = strings.ToLower(strings.TrimSpace(req.Status))
	if req.Status != "approved" && req.Status != "cancelled" && req.Status != "pending" {
		httpx.Validation(w, map[string][]string{"status": {"Status harus pending, approved, atau cancelled"}})
		return
	}
	u := currentUser(r)
	if !s.canManageBooking(u, b) {
		httpx.Fail(w, http.StatusForbidden, "Hanya pemilik lapak/event atau admin yang dapat mengubah status sewa")
		return
	}
	if _, err := s.store.DB.Exec(`UPDATE bookings SET status=?, updated_at=? WHERE id=?`, req.Status, s.store.Now(), id); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal mengubah status sewa")
		return
	}
	b, _ = s.findBooking(id)
	httpx.OK(w, b, "Status sewa diperbarui")
}

func (s *Server) cancelBooking(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	b, err := s.findBooking(id)
	if err != nil {
		httpx.Fail(w, http.StatusNotFound, "Data sewa tidak ditemukan")
		return
	}
	u := currentUser(r)
	if b.UserID != u.ID && !s.canManageBooking(u, b) {
		httpx.Fail(w, http.StatusForbidden, "Tidak dapat membatalkan sewa ini")
		return
	}
	if _, err := s.store.DB.Exec(`UPDATE bookings SET status='cancelled', updated_at=? WHERE id=?`, s.store.Now(), id); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal membatalkan sewa")
		return
	}
	httpx.OK(w, nil, "Sewa lapak dibatalkan")
}

func (s *Server) canManageBooking(u AuthUser, b Booking) bool {
	if auth.IsAdmin(u.Role) {
		return true
	}
	if b.EventID != nil {
		ev, err := s.findEvent(*b.EventID)
		if err == nil && canManageEvent(u, ev.OwnerID) {
			return true
		}
	}
	if b.StallID != nil {
		st, err := s.findStall(*b.StallID)
		if err == nil && (st.OwnerID == u.ID || canManageEvent(u, st.OwnerID)) {
			return true
		}
	}
	return false
}

func (s *Server) findBooking(id int64) (Booking, error) {
	row := s.store.DB.QueryRow(bookingSelect+` WHERE b.id = ?`, id)
	return scanBooking(row)
}

func scanBookings(rows *sql.Rows) ([]Booking, error) {
	list := []Booking{}
	for rows.Next() {
		b, err := scanBooking(rows)
		if err != nil {
			return nil, err
		}
		list = append(list, b)
	}
	return list, rows.Err()
}

func scanBooking(sc scanner) (Booking, error) {
	var b Booking
	var eventID sql.NullInt64
	var stallID sql.NullInt64
	err := sc.Scan(
		&b.ID, &eventID, &b.EventTitle, &b.UserID, &b.UserName, &stallID, &b.StallName,
		&b.StallLocation, &b.DailyRentPrice, &b.RentalDate, &b.Status, &b.CreatedAt, &b.UpdatedAt,
	)
	if eventID.Valid {
		v := eventID.Int64
		b.EventID = &v
	}
	if stallID.Valid {
		v := stallID.Int64
		b.StallID = &v
	}
	if len(b.RentalDate) > 10 {
		b.RentalDate = b.RentalDate[:10]
	}
	return b, err
}
