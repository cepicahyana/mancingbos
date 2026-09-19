package server

import (
	"database/sql"
	"fmt"
	"net/http"
	"strings"

	"indofish/internal/httpx"
)

type eventReq struct {
	Title           string `json:"title"`
	Description     string `json:"description"`
	Date            string `json:"date"`
	Location        string `json:"location"`
	RentalEnabled   *bool  `json:"rental_enabled"`
	StallID         *int64 `json:"stall_id"`
	MaxParticipants *int   `json:"max_participants"`
	Category        string `json:"category"`
	RegistrationFee *int   `json:"registration_fee"`
}

func (s *Server) listEvents(w http.ResponseWriter, r *http.Request) {
	page, perPage := httpx.PageParams(r)
	search := httpx.Search(r)
	col, dir := httpx.Sort(r, map[string]string{
		"created_at": "e.created_at",
		"date":       "e.date",
		"title":      "e.title",
	}, "e.created_at")
	u := currentUser(r)
	where := []string{"1=1"}
	args := []any{}
	if search != "" {
		where = append(where, "(e.title LIKE ? OR e.location LIKE ?)")
		q := "%" + search + "%"
		args = append(args, q, q)
	}
	if r.URL.Query().Get("mine") == "1" {
		where = append(where, "e.owner_id = ?")
		args = append(args, u.ID)
	}
	clause := strings.Join(where, " AND ")
	var total int
	if err := s.store.DB.QueryRow("SELECT COUNT(*) FROM events e WHERE "+clause, args...).Scan(&total); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat event")
		return
	}
	q := fmt.Sprintf(`
		SELECT e.id, e.owner_id, u.name, e.title, e.description, e.date, e.location, e.rental_enabled,
		       e.stall_id, COALESCE(st.name, ''), COALESCE(e.max_participants, 0), COALESCE(e.category, 'galatama'),
		       COALESCE(e.registration_fee, 0),
		       (SELECT COUNT(*) FROM event_registrations er WHERE er.event_id = e.id AND er.status IN ('pending_payment','paid')),
		       (SELECT COUNT(*) FROM bookings b WHERE b.event_id = e.id AND b.status != 'cancelled'),
		       e.latitude, e.longitude,
		       e.created_at, e.updated_at
		FROM events e
		JOIN users u ON u.id = e.owner_id
		LEFT JOIN stalls st ON st.id = e.stall_id
		WHERE %s
		ORDER BY %s %s
		LIMIT ? OFFSET ?`, clause, col, dir)
	args = append(args, perPage, (page-1)*perPage)
	rows, err := s.store.DB.Query(q, args...)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat event")
		return
	}
	defer rows.Close()
	list, err := scanEvents(rows)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat event")
		return
	}
	httpx.Page(w, list, page, perPage, total)
}

func (s *Server) getEvent(w http.ResponseWriter, r *http.Request) {
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
	httpx.OK(w, ev, "OK")
}

func (s *Server) createEvent(w http.ResponseWriter, r *http.Request) {
	req, errs := parseEvent(r)
	if len(errs) > 0 {
		httpx.Validation(w, errs)
		return
	}
	u := currentUser(r)
	if req.StallID != nil {
		st, err := s.findStall(*req.StallID)
		if err != nil || st.OwnerID != u.ID {
			httpx.Validation(w, map[string][]string{"stall_id": {"Lapak tidak valid / bukan milik Anda"}})
			return
		}
		if req.Location == "" {
			req.Location = st.Location
		}
	}
	now := s.store.Now()
	enabled := false
	if req.RentalEnabled != nil {
		enabled = *req.RentalEnabled
	}
	maxP := 0
	if req.MaxParticipants != nil {
		maxP = *req.MaxParticipants
	}
	fee := 0
	if req.RegistrationFee != nil {
		fee = *req.RegistrationFee
	}
	cat := req.Category
	if cat == "" {
		cat = "galatama"
	}
	res, err := s.store.DB.Exec(
		`INSERT INTO events (owner_id, title, description, date, location, rental_enabled, stall_id, max_participants, category, registration_fee, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		u.ID, req.Title, req.Description, req.Date, req.Location, boolToInt(enabled), req.StallID, maxP, cat, fee, now, now,
	)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal membuat event")
		return
	}
	id, _ := res.LastInsertId()
	ev, _ := s.findEvent(id)
	httpx.Created(w, ev, "Event berhasil dibuat")
}

func (s *Server) updateEvent(w http.ResponseWriter, r *http.Request) {
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
	if !canManageEvent(u, ev.OwnerID) {
		httpx.Fail(w, http.StatusForbidden, "Hanya pemilik event atau admin yang dapat mengubah")
		return
	}
	req, errs := parseEvent(r)
	if len(errs) > 0 {
		httpx.Validation(w, errs)
		return
	}
	if req.StallID != nil {
		st, err := s.findStall(*req.StallID)
		if err != nil || (st.OwnerID != u.ID && !canManageEvent(u, st.OwnerID)) {
			httpx.Validation(w, map[string][]string{"stall_id": {"Lapak tidak valid / bukan milik Anda"}})
			return
		}
	}
	enabled := ev.RentalEnabled
	if req.RentalEnabled != nil {
		enabled = *req.RentalEnabled
	}
	maxP := ev.MaxParticipants
	if req.MaxParticipants != nil {
		maxP = *req.MaxParticipants
	}
	fee := ev.RegistrationFee
	if req.RegistrationFee != nil {
		fee = *req.RegistrationFee
	}
	cat := req.Category
	if cat == "" {
		cat = ev.Category
	}
	stallID := req.StallID
	if stallID == nil {
		stallID = ev.StallID
	}
	_, err = s.store.DB.Exec(
		`UPDATE events SET title=?, description=?, date=?, location=?, rental_enabled=?, stall_id=?, max_participants=?, category=?, registration_fee=?, updated_at=? WHERE id=?`,
		req.Title, req.Description, req.Date, req.Location, boolToInt(enabled), stallID, maxP, cat, fee, s.store.Now(), id,
	)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal mengubah event")
		return
	}
	ev, _ = s.findEvent(id)
	httpx.OK(w, ev, "Event diperbarui")
}

func (s *Server) deleteEvent(w http.ResponseWriter, r *http.Request) {
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
	if !canManageEvent(currentUser(r), ev.OwnerID) {
		httpx.Fail(w, http.StatusForbidden, "Hanya pemilik event atau admin yang dapat menghapus")
		return
	}
	if _, err := s.store.DB.Exec("DELETE FROM events WHERE id = ?", id); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal menghapus event")
		return
	}
	httpx.OK(w, nil, "Event dihapus")
}

func parseEvent(r *http.Request) (eventReq, map[string][]string) {
	var req eventReq
	errs := map[string][]string{}
	if err := httpx.Decode(r, &req); err != nil {
		errs["_"] = []string{"Body JSON tidak valid"}
		return req, errs
	}
	req.Title = strings.TrimSpace(req.Title)
	req.Description = strings.TrimSpace(req.Description)
	req.Date = strings.TrimSpace(req.Date)
	req.Location = strings.TrimSpace(req.Location)
	req.Category = strings.TrimSpace(req.Category)
	if req.Title == "" {
		errs["title"] = []string{"Judul wajib diisi"}
	}
	if len(req.Date) < 10 {
		errs["date"] = []string{"Tanggal wajib diisi (YYYY-MM-DD)"}
	} else {
		req.Date = req.Date[:10]
	}
	if req.Location == "" && req.StallID == nil {
		errs["location"] = []string{"Lokasi wajib diisi"}
	}
	if req.Category != "" && !allowedCategories[req.Category] {
		errs["category"] = []string{"Kategori tidak valid"}
	}
	if req.MaxParticipants != nil && *req.MaxParticipants < 0 {
		errs["max_participants"] = []string{"Jumlah peserta tidak valid"}
	}
	if req.RegistrationFee != nil && *req.RegistrationFee < 0 {
		errs["registration_fee"] = []string{"Harga pendaftaran tidak valid"}
	}
	return req, errs
}

func (s *Server) findEvent(id int64) (Event, error) {
	row := s.store.DB.QueryRow(`
		SELECT e.id, e.owner_id, u.name, e.title, e.description, e.date, e.location, e.rental_enabled,
		       e.stall_id, COALESCE(st.name, ''), COALESCE(e.max_participants, 0), COALESCE(e.category, 'galatama'),
		       COALESCE(e.registration_fee, 0),
		       (SELECT COUNT(*) FROM event_registrations er WHERE er.event_id = e.id AND er.status IN ('pending_payment','paid')),
		       (SELECT COUNT(*) FROM bookings b WHERE b.event_id = e.id AND b.status != 'cancelled'),
		       e.latitude, e.longitude,
		       e.created_at, e.updated_at
		FROM events e
		JOIN users u ON u.id = e.owner_id
		LEFT JOIN stalls st ON st.id = e.stall_id
		WHERE e.id = ?`, id)
	return scanEvent(row)
}

func scanEvents(rows *sql.Rows) ([]Event, error) {
	list := []Event{}
	for rows.Next() {
		ev, err := scanEvent(rows)
		if err != nil {
			return nil, err
		}
		list = append(list, ev)
	}
	return list, rows.Err()
}

type scanner interface {
	Scan(dest ...any) error
}

func scanEvent(sc scanner) (Event, error) {
	var ev Event
	var enabled int
	var stallID sql.NullInt64
	var lat, lng sql.NullFloat64
	err := sc.Scan(
		&ev.ID, &ev.OwnerID, &ev.OwnerName, &ev.Title, &ev.Description, &ev.Date, &ev.Location, &enabled,
		&stallID, &ev.StallName, &ev.MaxParticipants, &ev.Category, &ev.RegistrationFee,
		&ev.ParticipantsCount, &ev.BookingsCount,
		&lat, &lng,
		&ev.CreatedAt, &ev.UpdatedAt,
	)
	ev.RentalEnabled = enabled == 1
	ev.StallID = nullInt64(stallID)
	if lat.Valid {
		v := lat.Float64
		ev.Latitude = &v
	}
	if lng.Valid {
		v := lng.Float64
		ev.Longitude = &v
	}
	if len(ev.Date) > 10 {
		ev.Date = ev.Date[:10]
	}
	if ev.Category == "" {
		ev.Category = "galatama"
	}
	if ev.StallID != nil {
		today := jakartaToday()
		ev.RentalLocked = ev.Date == today
	}
	return ev, err
}

func boolToInt(v bool) int {
	if v {
		return 1
	}
	return 0
}
