package server

import (
	"net/http"

	"indofish/internal/auth"
	"indofish/internal/httpx"
)

var juaraPoints = map[int]int{1: 50, 2: 30, 3: 20}

func (s *Server) awardEventWinners(w http.ResponseWriter, r *http.Request) {
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
	if !canManageEvent(u, ev.OwnerID) && u.Role != "operator" && !auth.IsAdmin(u.Role) {
		httpx.Fail(w, http.StatusForbidden, "Tidak dapat menetapkan juara")
		return
	}

	rows, err := s.store.DB.Query(`
		SELECT user_id, MAX(weight) AS best
		FROM weights
		WHERE event_id = ?
		GROUP BY user_id
		ORDER BY best DESC
		LIMIT 3`, id)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal membaca ranking")
		return
	}
	defer rows.Close()

	type winner struct {
		UserID int64   `json:"user_id"`
		UserName string `json:"user_name"`
		Place  int     `json:"place"`
		Points int     `json:"points"`
		Weight float64 `json:"weight"`
		Awarded bool   `json:"awarded"`
	}
	list := []winner{}
	place := 0
	now := s.store.Now()
	for rows.Next() {
		place++
		var uid int64
		var best float64
		if err := rows.Scan(&uid, &best); err != nil {
			httpx.Fail(w, http.StatusInternalServerError, "Gagal membaca ranking")
			return
		}
		pts := juaraPoints[place]
		var name string
		_ = s.store.DB.QueryRow(`SELECT name FROM users WHERE id = ?`, uid).Scan(&name)
		awarded := false
		res, err := s.store.DB.Exec(
			`INSERT INTO event_awards (event_id, user_id, place, points, created_at) VALUES (?, ?, ?, ?, ?)`,
			id, uid, place, pts, now,
		)
		if err == nil {
			if n, _ := res.RowsAffected(); n > 0 {
				_ = s.addUserPoints(uid, pts)
				awarded = true
			}
		}
		list = append(list, winner{UserID: uid, UserName: name, Place: place, Points: pts, Weight: best, Awarded: awarded})
	}
	if len(list) == 0 {
		httpx.Fail(w, http.StatusUnprocessableEntity, "Belum ada data berat untuk menentukan juara")
		return
	}
	httpx.OK(w, list, "Juara ditetapkan")
}

func (s *Server) listEventAwards(w http.ResponseWriter, r *http.Request) {
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
		SELECT a.user_id, u.name, a.place, a.points
		FROM event_awards a
		JOIN users u ON u.id = a.user_id
		WHERE a.event_id = ?
		ORDER BY a.place ASC`, id)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat juara")
		return
	}
	defer rows.Close()
	list := []map[string]any{}
	for rows.Next() {
		var uid int64
		var name string
		var place, pts int
		if rows.Scan(&uid, &name, &place, &pts) == nil {
			list = append(list, map[string]any{
				"user_id": uid, "user_name": name, "place": place, "points": pts,
			})
		}
	}
	httpx.OK(w, list, "OK")
}
