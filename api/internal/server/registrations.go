package server

import (
	"database/sql"
	"net/http"
	"strings"

	"indofish/internal/auth"
	"indofish/internal/httpx"
)

var allowedCategories = map[string]bool{
	"galatama":   true,
	"galapung":   true,
	"kilogebrus": true,
	"casting":    true,
	"feeder":     true,
	"beregu":     true,
}

// registerEvent creates a pending_payment registration (Xendit later).
func (s *Server) registerEvent(w http.ResponseWriter, r *http.Request) {
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
	if ev.OwnerID == u.ID {
		httpx.Fail(w, http.StatusUnprocessableEntity, "Pemilik event tidak perlu mendaftar")
		return
	}
	var existing int
	_ = s.store.DB.QueryRow(
		`SELECT COUNT(*) FROM event_registrations WHERE event_id = ? AND user_id = ? AND status != 'cancelled'`,
		id, u.ID,
	).Scan(&existing)
	if existing > 0 {
		httpx.Fail(w, http.StatusUnprocessableEntity, "Anda sudah terdaftar di event ini")
		return
	}
	if ev.MaxParticipants > 0 && ev.ParticipantsCount >= ev.MaxParticipants {
		httpx.Fail(w, http.StatusUnprocessableEntity, "Kuota peserta sudah penuh")
		return
	}

	now := s.store.Now()
	status := "pending_payment"
	if ev.RegistrationFee <= 0 {
		status = "paid" // gratis
	}
	// ponytail: Xendit invoice/QR belum diintegrasikan — status pending_payment siap webhook.
	res, err := s.store.DB.Exec(
		`INSERT INTO event_registrations (event_id, user_id, status, amount, payment_provider, external_id, created_at, updated_at)
		 VALUES (?, ?, ?, ?, 'xendit', NULL, ?, ?)`,
		id, u.ID, status, ev.RegistrationFee, now, now,
	)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal mendaftar event")
		return
	}
	regID, _ := res.LastInsertId()
	_ = s.addUserPoints(u.ID, 5) // +5 daftar masuk event
	reg, _ := s.findRegistration(regID)
	msg := "Pendaftaran berhasil"
	if status == "pending_payment" {
		msg = "Pendaftaran dibuat — menunggu pembayaran Xendit"
	}
	httpx.Created(w, reg, msg)
}

func (s *Server) listEventRegistrations(w http.ResponseWriter, r *http.Request) {
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
	if !canManageEvent(u, ev.OwnerID) && u.Role != "operator" {
		httpx.Fail(w, http.StatusForbidden, "Akses daftar peserta ditolak")
		return
	}
	rows, err := s.store.DB.Query(`
		SELECT r.id, r.event_id, e.title, r.user_id, u.name, r.status, r.amount, r.payment_provider,
		       COALESCE(r.external_id, ''), r.created_at, r.updated_at
		FROM event_registrations r
		JOIN events e ON e.id = r.event_id
		JOIN users u ON u.id = r.user_id
		WHERE r.event_id = ?
		ORDER BY r.created_at DESC`, id)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat pendaftaran")
		return
	}
	defer rows.Close()
	list := []EventRegistration{}
	for rows.Next() {
		reg, err := scanRegistration(rows)
		if err != nil {
			httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat pendaftaran")
			return
		}
		list = append(list, reg)
	}
	httpx.OK(w, list, "OK")
}

type regStatusReq struct {
	Status string `json:"status"`
}

func (s *Server) updateRegistration(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	reg, err := s.findRegistration(id)
	if err != nil {
		httpx.Fail(w, http.StatusNotFound, "Pendaftaran tidak ditemukan")
		return
	}
	ev, err := s.findEvent(reg.EventID)
	if err != nil {
		httpx.Fail(w, http.StatusNotFound, "Event tidak ditemukan")
		return
	}
	u := currentUser(r)
	if !canManageEvent(u, ev.OwnerID) && !auth.IsAdmin(u.Role) {
		httpx.Fail(w, http.StatusForbidden, "Tidak dapat mengubah status pendaftaran")
		return
	}
	var req regStatusReq
	if err := httpx.Decode(r, &req); err != nil {
		httpx.Fail(w, http.StatusBadRequest, "Body JSON tidak valid")
		return
	}
	req.Status = strings.TrimSpace(req.Status)
	if req.Status != "paid" && req.Status != "cancelled" && req.Status != "pending_payment" {
		httpx.Validation(w, map[string][]string{"status": {"Status harus paid, cancelled, atau pending_payment"}})
		return
	}
	_, err = s.store.DB.Exec(
		`UPDATE event_registrations SET status=?, updated_at=? WHERE id=?`,
		req.Status, s.store.Now(), id,
	)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal mengubah status")
		return
	}
	reg, _ = s.findRegistration(id)
	httpx.OK(w, reg, "Status pendaftaran diperbarui")
}

func (s *Server) findRegistration(id int64) (EventRegistration, error) {
	row := s.store.DB.QueryRow(`
		SELECT r.id, r.event_id, e.title, r.user_id, u.name, r.status, r.amount, r.payment_provider,
		       COALESCE(r.external_id, ''), r.created_at, r.updated_at
		FROM event_registrations r
		JOIN events e ON e.id = r.event_id
		JOIN users u ON u.id = r.user_id
		WHERE r.id = ?`, id)
	return scanRegistration(row)
}

func scanRegistration(sc scanner) (EventRegistration, error) {
	var reg EventRegistration
	err := sc.Scan(
		&reg.ID, &reg.EventID, &reg.EventTitle, &reg.UserID, &reg.UserName,
		&reg.Status, &reg.Amount, &reg.PaymentProvider, &reg.ExternalID,
		&reg.CreatedAt, &reg.UpdatedAt,
	)
	return reg, err
}

func (s *Server) countParticipants(eventID int64) int {
	var n int
	_ = s.store.DB.QueryRow(
		`SELECT COUNT(*) FROM event_registrations
		 WHERE event_id = ? AND status IN ('pending_payment','paid')`,
		eventID,
	).Scan(&n)
	return n
}

func nullInt64(v sql.NullInt64) *int64 {
	if !v.Valid {
		return nil
	}
	x := v.Int64
	return &x
}
