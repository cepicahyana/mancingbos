package server

import (
	"database/sql"
	"fmt"
	"net/http"
	"strconv"

	"indofish/internal/httpx"
)

type weightReq struct {
	EventID int64   `json:"event_id"`
	UserID  int64   `json:"user_id"`
	Weight  float64 `json:"weight"`
}

func (s *Server) listWeights(w http.ResponseWriter, r *http.Request) {
	page, perPage := httpx.PageParams(r)
	where := "1=1"
	args := []any{}
	if ev := r.URL.Query().Get("event_id"); ev != "" {
		id, err := strconv.ParseInt(ev, 10, 64)
		if err != nil || id < 1 {
			httpx.Fail(w, http.StatusBadRequest, "event_id tidak valid")
			return
		}
		where = "w.event_id = ?"
		args = append(args, id)
	}
	var total int
	if err := s.store.DB.QueryRow("SELECT COUNT(*) FROM weights w WHERE "+where, args...).Scan(&total); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat data berat")
		return
	}
	q := fmt.Sprintf(`
		SELECT w.id, w.event_id, w.user_id, u.name, w.weight, w.created_at
		FROM weights w
		JOIN users u ON u.id = w.user_id
		WHERE %s
		ORDER BY w.weight DESC, w.created_at DESC
		LIMIT ? OFFSET ?`, where)
	args = append(args, perPage, (page-1)*perPage)
	rows, err := s.store.DB.Query(q, args...)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat data berat")
		return
	}
	defer rows.Close()
	list, err := scanWeights(rows)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat data berat")
		return
	}
	httpx.Page(w, list, page, perPage, total)
}

func (s *Server) listEventWeights(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	if _, err := s.findEvent(id); err != nil {
		httpx.Fail(w, http.StatusNotFound, "Event tidak ditemukan")
		return
	}
	rows, err := s.store.DB.Query(`
		SELECT w.id, w.event_id, w.user_id, u.name, w.weight, w.created_at
		FROM weights w
		JOIN users u ON u.id = w.user_id
		WHERE w.event_id = ?
		ORDER BY w.weight DESC, w.created_at DESC`, id)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat data berat")
		return
	}
	defer rows.Close()
	list, err := scanWeights(rows)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat data berat")
		return
	}
	httpx.OK(w, list, "OK")
}

func (s *Server) createWeight(w http.ResponseWriter, r *http.Request) {
	var req weightReq
	if err := httpx.Decode(r, &req); err != nil {
		httpx.Fail(w, http.StatusBadRequest, "Body JSON tidak valid")
		return
	}
	errs := map[string][]string{}
	if req.EventID < 1 {
		errs["event_id"] = []string{"Event wajib dipilih"}
	}
	if req.UserID < 1 {
		errs["user_id"] = []string{"Peserta wajib dipilih"}
	}
	if req.Weight <= 0 {
		errs["weight"] = []string{"Berat ikan harus lebih dari 0"}
	}
	if len(errs) > 0 {
		httpx.Validation(w, errs)
		return
	}
	if _, err := s.findEvent(req.EventID); err != nil {
		httpx.Fail(w, http.StatusNotFound, "Event tidak ditemukan")
		return
	}
	if _, err := s.findUser(req.UserID); err != nil {
		httpx.Fail(w, http.StatusNotFound, "Pengguna tidak ditemukan")
		return
	}
	res, err := s.store.DB.Exec(
		`INSERT INTO weights (event_id, user_id, weight, created_at) VALUES (?, ?, ?, ?)`,
		req.EventID, req.UserID, req.Weight, s.store.Now(),
	)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal menyimpan berat ikan")
		return
	}
	id, _ := res.LastInsertId()
	row := s.store.DB.QueryRow(`
		SELECT w.id, w.event_id, w.user_id, u.name, w.weight, w.created_at
		FROM weights w JOIN users u ON u.id = w.user_id WHERE w.id = ?`, id)
	wt, err := scanWeight(row)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat data berat")
		return
	}
	httpx.Created(w, wt, "Berat ikan tersimpan")
}

func scanWeights(rows *sql.Rows) ([]Weight, error) {
	list := []Weight{}
	for rows.Next() {
		wt, err := scanWeight(rows)
		if err != nil {
			return nil, err
		}
		list = append(list, wt)
	}
	return list, rows.Err()
}

func scanWeight(sc scanner) (Weight, error) {
	var wt Weight
	err := sc.Scan(&wt.ID, &wt.EventID, &wt.UserID, &wt.UserName, &wt.Weight, &wt.CreatedAt)
	return wt, err
}
