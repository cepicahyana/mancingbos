package server

import (
	"database/sql"
	"net/http"

	"indofish/internal/httpx"
)

func (s *Server) getProfile(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	p, err := s.findProfile(id, currentUser(r).ID)
	if err != nil {
		httpx.Fail(w, http.StatusNotFound, "Pengguna tidak ditemukan")
		return
	}
	httpx.OK(w, p, "OK")
}

func (s *Server) listProfilePosts(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	viewer := currentUser(r)
	if _, err := s.findUser(id); err != nil {
		httpx.Fail(w, http.StatusNotFound, "Pengguna tidak ditemukan")
		return
	}
	page, perPage := httpx.PageParams(r)
	var total int
	if err := s.store.DB.QueryRow(`SELECT COUNT(*) FROM posts WHERE user_id = ?`, id).Scan(&total); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat postingan")
		return
	}
	rows, err := s.store.DB.Query(`
		SELECT p.id, p.user_id, u.name, p.caption, COALESCE(p.location, ''), p.latitude, p.longitude, p.image_path,
		       (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id),
		       (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id),
		       (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id AND l.user_id = ?),
		       p.created_at, p.updated_at
		FROM posts p
		JOIN users u ON u.id = p.user_id
		WHERE p.user_id = ?
		ORDER BY p.created_at DESC
		LIMIT ? OFFSET ?`, viewer.ID, id, perPage, (page-1)*perPage)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat postingan")
		return
	}
	defer rows.Close()
	list := []Post{}
	for rows.Next() {
		var p Post
		var path string
		var liked int
		var lat, lng sql.NullFloat64
		if err := rows.Scan(&p.ID, &p.UserID, &p.UserName, &p.Caption, &p.Location, &lat, &lng, &path, &p.CommentsCount, &p.LikesCount, &liked, &p.CreatedAt, &p.UpdatedAt); err != nil {
			httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat postingan")
			return
		}
		if lat.Valid {
			v := lat.Float64
			p.Latitude = &v
		}
		if lng.Valid {
			v := lng.Float64
			p.Longitude = &v
		}
		p.LikedByMe = liked > 0
		p.ImageURLs = s.postImageURLs(p.ID, path)
		if len(p.ImageURLs) > 0 {
			p.ImageURL = p.ImageURLs[0]
		}
		list = append(list, p)
	}
	httpx.Page(w, list, page, perPage, total)
}

func (s *Server) followUser(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	me := currentUser(r)
	if me.ID == id {
		httpx.Fail(w, http.StatusUnprocessableEntity, "Tidak dapat mengikuti diri sendiri")
		return
	}
	if _, err := s.findUser(id); err != nil {
		httpx.Fail(w, http.StatusNotFound, "Pengguna tidak ditemukan")
		return
	}
	var exists int
	_ = s.store.DB.QueryRow(
		`SELECT COUNT(*) FROM follows WHERE follower_id = ? AND following_id = ?`,
		me.ID, id,
	).Scan(&exists)
	if exists == 0 {
		if _, err := s.store.DB.Exec(
			`INSERT INTO follows (follower_id, following_id, created_at) VALUES (?, ?, ?)`,
			me.ID, id, s.store.Now(),
		); err != nil {
			httpx.Fail(w, http.StatusInternalServerError, "Gagal mengikuti akun")
			return
		}
	}
	p, _ := s.findProfile(id, me.ID)
	httpx.OK(w, p, "Mengikuti")
}

func (s *Server) unfollowUser(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	me := currentUser(r)
	if _, err := s.findUser(id); err != nil {
		httpx.Fail(w, http.StatusNotFound, "Pengguna tidak ditemukan")
		return
	}
	if _, err := s.store.DB.Exec(
		`DELETE FROM follows WHERE follower_id = ? AND following_id = ?`,
		me.ID, id,
	); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal berhenti mengikuti")
		return
	}
	p, _ := s.findProfile(id, me.ID)
	httpx.OK(w, p, "Berhenti mengikuti")
}

func (s *Server) findProfile(id, viewerID int64) (PublicProfile, error) {
	var p PublicProfile
	err := s.store.DB.QueryRow(`SELECT id, name, role, COALESCE(points, 0) FROM users WHERE id = ?`, id).Scan(&p.ID, &p.Name, &p.Role, &p.Points)
	if err != nil {
		return p, err
	}
	p.Level = levelFromPoints(p.Points)
	p.Tier, p.TierName = tierFromLevel(p.Level)
	p.PointsToNext = 50 - (p.Points % 50)
	if p.Level >= 30 {
		p.PointsToNext = 0
	}
	_ = s.store.DB.QueryRow(`SELECT COUNT(*) FROM posts WHERE user_id = ?`, id).Scan(&p.PostsCount)
	_ = s.store.DB.QueryRow(`SELECT COUNT(*) FROM follows WHERE following_id = ?`, id).Scan(&p.FollowersCount)
	_ = s.store.DB.QueryRow(`SELECT COUNT(*) FROM follows WHERE follower_id = ?`, id).Scan(&p.FollowingCount)
	var followed int
	_ = s.store.DB.QueryRow(
		`SELECT COUNT(*) FROM follows WHERE follower_id = ? AND following_id = ?`,
		viewerID, id,
	).Scan(&followed)
	p.FollowedByMe = followed > 0
	p.IsMe = viewerID == id
	return p, nil
}
