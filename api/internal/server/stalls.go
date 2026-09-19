package server

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"indofish/internal/httpx"
)

type stallReq struct {
	Name           string `json:"name"`
	Description    string `json:"description"`
	Location       string `json:"location"`
	DailyRentPrice *int   `json:"daily_rent_price"`
	Capacity       *int   `json:"capacity"`
	Active         *bool  `json:"active"`
}

func (s *Server) listStalls(w http.ResponseWriter, r *http.Request) {
	u := currentUser(r)
	mine := r.URL.Query().Get("mine") == "1"
	date := strings.TrimSpace(r.URL.Query().Get("date"))
	search := strings.TrimSpace(r.URL.Query().Get("search"))
	withAvailability := date != ""

	if withAvailability {
		if _, err := time.Parse("2006-01-02", date); err != nil {
			httpx.Validation(w, map[string][]string{"date": {"Format tanggal harus YYYY-MM-DD"}})
			return
		}
	}

	q := `
		SELECT id, owner_id, name, description, location, daily_rent_price,
		       COALESCE(capacity, 10), COALESCE(harian_enabled, 0), COALESCE(scheme, 'kilogebrus'),
		       active, created_at, updated_at
		FROM stalls`
	args := []any{}
	where := []string{}
	if mine {
		where = append(where, "owner_id = ?")
		args = append(args, u.ID)
	} else {
		where = append(where, "active = 1")
	}
	scheme := strings.TrimSpace(r.URL.Query().Get("scheme"))
	if scheme != "" && scheme != "Semua" {
		where = append(where, "COALESCE(scheme, 'kilogebrus') = ?")
		args = append(args, scheme)
	}
	province := strings.TrimSpace(r.URL.Query().Get("province"))
	if province != "" && province != "Semua" {
		where = append(where, "location LIKE ?")
		args = append(args, "%"+province+"%")
	}
	if search != "" {
		where = append(where, "(name LIKE ? OR location LIKE ? OR description LIKE ?)")
		like := "%" + search + "%"
		args = append(args, like, like, like)
	}
	if len(where) > 0 {
		q += ` WHERE ` + strings.Join(where, " AND ")
	}
	if withAvailability {
		q += ` ORDER BY name ASC`
	} else {
		q += ` ORDER BY created_at DESC`
	}
	rows, err := s.store.DB.Query(q, args...)
	if err != nil {
		q2 := `SELECT id, owner_id, name, description, location, daily_rent_price, 10, 0, 'kilogebrus', active, created_at, updated_at FROM stalls`
		where2 := []string{}
		args2 := []any{}
		if mine {
			where2 = append(where2, "owner_id = ?")
			args2 = append(args2, u.ID)
		} else {
			where2 = append(where2, "active = 1")
		}
		if search != "" {
			where2 = append(where2, "(name LIKE ? OR location LIKE ? OR description LIKE ?)")
			like := "%" + search + "%"
			args2 = append(args2, like, like, like)
		}
		if len(where2) > 0 {
			q2 += ` WHERE ` + strings.Join(where2, " AND ")
		}
		q2 += ` ORDER BY created_at DESC`
		rows, err = s.store.DB.Query(q2, args2...)
		if err != nil {
			httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat lapak")
			return
		}
	}
	defer rows.Close()
	list := []Stall{}
	onlyAvail := withAvailability && r.URL.Query().Get("available_only") != "0"
	for rows.Next() {
		st, err := scanStall(rows)
		if err != nil {
			httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat lapak")
			return
		}
		if withAvailability {
			s.fillStallAvailability(&st, date)
			if onlyAvail && !st.Available {
				continue
			}
		}
		list = append(list, st)
	}
	httpx.OK(w, list, "OK")
}

func (s *Server) stallAvailabilityCalendar(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	st, err := s.findStall(id)
	if err != nil {
		httpx.Fail(w, http.StatusNotFound, "Lapak tidak ditemukan")
		return
	}
	days := 45
	if v := strings.TrimSpace(r.URL.Query().Get("days")); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 120 {
			days = n
		}
	}
	from := jakartaToday()
	if v := strings.TrimSpace(r.URL.Query().Get("from")); v != "" {
		if _, err := time.Parse("2006-01-02", v); err == nil {
			from = v
		}
	}
	start, _ := time.Parse("2006-01-02", from)
	out := make([]StallDayAvailability, 0, days)
	for i := 0; i < days; i++ {
		d := start.AddDate(0, 0, i).Format("2006-01-02")
		av := s.stallDayAvailability(st.ID, st.Capacity, d)
		out = append(out, av)
	}
	httpx.OK(w, out, "OK")
}

func (s *Server) createStall(w http.ResponseWriter, r *http.Request) {
	req, errs := parseStall(r)
	if len(errs) > 0 {
		httpx.Validation(w, errs)
		return
	}
	u := currentUser(r)
	now := s.store.Now()
	price := 0
	if req.DailyRentPrice != nil {
		price = *req.DailyRentPrice
	}
	capacity := 10
	if req.Capacity != nil {
		capacity = *req.Capacity
	}
	active := 1
	if req.Active != nil && !*req.Active {
		active = 0
	}
	res, err := s.store.DB.Exec(
		`INSERT INTO stalls (owner_id, name, description, location, daily_rent_price, capacity, active, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		u.ID, req.Name, req.Description, req.Location, price, capacity, active, now, now,
	)
	if err != nil {
		// fallback if capacity column missing mid-migrate
		res, err = s.store.DB.Exec(
			`INSERT INTO stalls (owner_id, name, description, location, daily_rent_price, active, created_at, updated_at)
			 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
			u.ID, req.Name, req.Description, req.Location, price, active, now, now,
		)
		if err != nil {
			httpx.Fail(w, http.StatusInternalServerError, "Gagal membuat lapak")
			return
		}
	}
	id, _ := res.LastInsertId()
	st, _ := s.findStall(id)
	httpx.Created(w, st, "Lapak berhasil ditambahkan")
}

func (s *Server) updateStall(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	st, err := s.findStall(id)
	if err != nil {
		httpx.Fail(w, http.StatusNotFound, "Lapak tidak ditemukan")
		return
	}
	u := currentUser(r)
	if st.OwnerID != u.ID && !canManageEvent(u, st.OwnerID) {
		httpx.Fail(w, http.StatusForbidden, "Hanya pemilik lapak yang dapat mengubah")
		return
	}
	req, errs := parseStall(r)
	if len(errs) > 0 {
		httpx.Validation(w, errs)
		return
	}
	price := st.DailyRentPrice
	if req.DailyRentPrice != nil {
		price = *req.DailyRentPrice
	}
	capacity := st.Capacity
	if capacity < 1 {
		capacity = 10
	}
	if req.Capacity != nil {
		capacity = *req.Capacity
	}
	active := boolToInt(st.Active)
	if req.Active != nil {
		active = boolToInt(*req.Active)
	}
	_, err = s.store.DB.Exec(
		`UPDATE stalls SET name=?, description=?, location=?, daily_rent_price=?, capacity=?, active=?, updated_at=? WHERE id=?`,
		req.Name, req.Description, req.Location, price, capacity, active, s.store.Now(), id,
	)
	if err != nil {
		_, err = s.store.DB.Exec(
			`UPDATE stalls SET name=?, description=?, location=?, daily_rent_price=?, active=?, updated_at=? WHERE id=?`,
			req.Name, req.Description, req.Location, price, active, s.store.Now(), id,
		)
		if err != nil {
			httpx.Fail(w, http.StatusInternalServerError, "Gagal mengubah lapak")
			return
		}
	}
	st, _ = s.findStall(id)
	httpx.OK(w, st, "Lapak diperbarui")
}

func (s *Server) deleteStall(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	st, err := s.findStall(id)
	if err != nil {
		httpx.Fail(w, http.StatusNotFound, "Lapak tidak ditemukan")
		return
	}
	u := currentUser(r)
	if st.OwnerID != u.ID && !canManageEvent(u, st.OwnerID) {
		httpx.Fail(w, http.StatusForbidden, "Hanya pemilik lapak yang dapat menghapus")
		return
	}
	if _, err := s.store.DB.Exec(`UPDATE events SET stall_id = NULL WHERE stall_id = ?`, id); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal melepas event dari lapak")
		return
	}
	if _, err := s.store.DB.Exec(`DELETE FROM stalls WHERE id = ?`, id); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal menghapus lapak")
		return
	}
	httpx.OK(w, nil, "Lapak dihapus")
}

func parseStall(r *http.Request) (stallReq, map[string][]string) {
	var req stallReq
	errs := map[string][]string{}
	if err := httpx.Decode(r, &req); err != nil {
		errs["_"] = []string{"Body JSON tidak valid"}
		return req, errs
	}
	req.Name = strings.TrimSpace(req.Name)
	req.Description = strings.TrimSpace(req.Description)
	req.Location = strings.TrimSpace(req.Location)
	if req.Name == "" {
		errs["name"] = []string{"Nama lapak wajib diisi"}
	}
	if req.Location == "" {
		errs["location"] = []string{"Lokasi wajib diisi"}
	}
	if req.DailyRentPrice != nil && *req.DailyRentPrice < 0 {
		errs["daily_rent_price"] = []string{"Harga sewa tidak valid"}
	}
	if req.Capacity != nil && *req.Capacity < 1 {
		errs["capacity"] = []string{"Kapasitas minimal 1 peserta/hari"}
	}
	return req, errs
}

func (s *Server) findStall(id int64) (Stall, error) {
	row := s.store.DB.QueryRow(`
		SELECT id, owner_id, name, description, location, daily_rent_price,
		       COALESCE(capacity, 10), COALESCE(harian_enabled, 0), COALESCE(scheme, 'kilogebrus'),
		       active, created_at, updated_at
		FROM stalls WHERE id = ?`, id)
	st, err := scanStall(row)
	if err != nil {
		row = s.store.DB.QueryRow(`
			SELECT id, owner_id, name, description, location, daily_rent_price, 10, 0, 'kilogebrus', active, created_at, updated_at
			FROM stalls WHERE id = ?`, id)
		return scanStall(row)
	}
	return st, nil
}

func scanStall(sc scanner) (Stall, error) {
	var st Stall
	var active, harian int
	err := sc.Scan(
		&st.ID, &st.OwnerID, &st.Name, &st.Description, &st.Location, &st.DailyRentPrice,
		&st.Capacity, &harian, &st.Scheme, &active, &st.CreatedAt, &st.UpdatedAt,
	)
	st.Active = active == 1
	st.HarianEnabled = harian == 1
	if st.Capacity < 1 {
		st.Capacity = 10
	}
	if st.Scheme == "" {
		st.Scheme = "kilogebrus"
	}
	return st, err
}

func (s *Server) fillStallAvailability(st *Stall, date string) {
	av := s.stallDayAvailability(st.ID, st.Capacity, date)
	st.BookedSlots = av.BookedSlots
	st.RemainingSlots = av.RemainingSlots
	st.Available = av.Available
	st.BlockedByEvent = av.BlockedByEvent
	st.NotOpenOnDate = av.NotOpenOnDate
}

func (s *Server) stallDayAvailability(stallID int64, capacity int, date string) StallDayAvailability {
	if capacity < 1 {
		capacity = 10
	}
	open := s.stallIsOpenOnDate(stallID, date)
	blocked := s.stallHasEventOnDate(stallID, date)
	booked := s.stallBookedSlots(stallID, date)
	remaining := capacity - booked
	if remaining < 0 {
		remaining = 0
	}
	if blocked || !open {
		remaining = 0
	}
	return StallDayAvailability{
		Date:           date,
		Capacity:       capacity,
		BookedSlots:    booked,
		RemainingSlots: remaining,
		Available:      open && !blocked && remaining > 0,
		BlockedByEvent: blocked,
		NotOpenOnDate:  !open,
	}
}

func (s *Server) stallIsOpenOnDate(stallID int64, date string) bool {
	var total int
	err := s.store.DB.QueryRow(`SELECT COUNT(*) FROM stall_open_dates WHERE stall_id = ?`, stallID).Scan(&total)
	if err != nil || total == 0 {
		// Belum ada jadwal → anggap buka setiap hari (demo / default).
		return true
	}
	var n int
	_ = s.store.DB.QueryRow(
		`SELECT COUNT(*) FROM stall_open_dates WHERE stall_id = ? AND SUBSTR(CAST(open_date AS CHAR), 1, 10) = ?`,
		stallID, date,
	).Scan(&n)
	return n > 0
}

func (s *Server) stallBookedSlots(stallID int64, date string) int {
	var n int
	_ = s.store.DB.QueryRow(`
		SELECT COUNT(*) FROM bookings
		WHERE stall_id = ? AND SUBSTR(CAST(rental_date AS CHAR), 1, 10) = ? AND status IN ('pending','approved')`,
		stallID, date,
	).Scan(&n)
	return n
}

func (s *Server) stallHasEventOnDate(stallID int64, date string) bool {
	var n int
	_ = s.store.DB.QueryRow(
		`SELECT COUNT(*) FROM events WHERE stall_id = ? AND SUBSTR(date, 1, 10) = ?`,
		stallID, date,
	).Scan(&n)
	return n > 0
}

func (s *Server) stallHasActiveEvent(stallID int64) bool {
	return s.stallHasEventOnDate(stallID, jakartaToday())
}

func jakartaToday() string {
	loc, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		loc = time.FixedZone("WIB", 7*3600)
	}
	return time.Now().In(loc).Format("2006-01-02")
}
