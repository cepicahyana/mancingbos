package server

import (
	"database/sql"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"indofish/internal/auth"
	"indofish/internal/httpx"
)

const uploadDir = "uploads"

func (s *Server) ensureUploadDir() error {
	return os.MkdirAll(uploadDir, 0o755)
}

func (s *Server) listPosts(w http.ResponseWriter, r *http.Request) {
	page, perPage := httpx.PageParams(r)
	viewer := currentUser(r)
	var total int
	if err := s.store.DB.QueryRow(`SELECT COUNT(*) FROM posts`).Scan(&total); err != nil {
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
		ORDER BY p.created_at DESC
		LIMIT ? OFFSET ?`, viewer.ID, perPage, (page-1)*perPage)
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

func (s *Server) getPost(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	p, err := s.findPost(id, currentUser(r).ID)
	if err != nil {
		httpx.Fail(w, http.StatusNotFound, "Postingan tidak ditemukan")
		return
	}
	httpx.OK(w, p, "OK")
}

func (s *Server) createPost(w http.ResponseWriter, r *http.Request) {
	if err := s.ensureUploadDir(); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal menyiapkan penyimpanan foto")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 40<<20) // 40MB for up to 4 photos
	if err := r.ParseMultipartForm(40 << 20); err != nil {
		httpx.Fail(w, http.StatusBadRequest, "Ukuran file terlalu besar atau form tidak valid")
		return
	}
	caption := strings.TrimSpace(r.FormValue("caption"))
	location := strings.TrimSpace(r.FormValue("location"))
	if len(location) > 500 {
		httpx.Validation(w, map[string][]string{"location": {"Lokasi maksimal 500 karakter"}})
		return
	}
	if len([]rune(location)) > 180 {
		// keep DB column friendly; prefer readable short label
		r := []rune(location)
		location = string(r[:177]) + "..."
	}
	var latVal, lngVal any
	if latStr := strings.TrimSpace(r.FormValue("latitude")); latStr != "" {
		if v, err := strconv.ParseFloat(latStr, 64); err == nil {
			latVal = v
		}
	}
	if lngStr := strings.TrimSpace(r.FormValue("longitude")); lngStr != "" {
		if v, err := strconv.ParseFloat(lngStr, 64); err == nil {
			lngVal = v
		}
	}

	headers := r.MultipartForm.File["photos"]
	if len(headers) == 0 {
		if one, h, err := r.FormFile("photo"); err == nil {
			_ = one.Close()
			headers = []*multipart.FileHeader{h}
		}
	}
	if len(headers) == 0 {
		httpx.Validation(w, map[string][]string{"photos": {"Minimal 1 foto wajib diunggah"}})
		return
	}
	if len(headers) > 4 {
		httpx.Validation(w, map[string][]string{"photos": {"Maksimal 4 foto per postingan"}})
		return
	}

	saved := make([]string, 0, len(headers))
	u := currentUser(r)
	for i, header := range headers {
		ext := strings.ToLower(filepath.Ext(header.Filename))
		switch ext {
		case ".jpg", ".jpeg", ".png", ".webp":
		default:
			for _, p := range saved {
				_ = os.Remove(filepath.Join(uploadDir, p))
			}
			httpx.Validation(w, map[string][]string{"photos": {"Format harus JPG, PNG, atau WEBP"}})
			return
		}
		file, err := header.Open()
		if err != nil {
			for _, p := range saved {
				_ = os.Remove(filepath.Join(uploadDir, p))
			}
			httpx.Fail(w, http.StatusBadRequest, "Gagal membaca foto")
			return
		}
		name := fmt.Sprintf("%d_%d_%d%s", time.Now().UnixNano(), u.ID, i, ext)
		destPath := filepath.Join(uploadDir, name)
		out, err := os.Create(destPath)
		if err != nil {
			_ = file.Close()
			for _, p := range saved {
				_ = os.Remove(filepath.Join(uploadDir, p))
			}
			httpx.Fail(w, http.StatusInternalServerError, "Gagal menyimpan foto")
			return
		}
		_, copyErr := io.Copy(out, file)
		_ = out.Close()
		_ = file.Close()
		if copyErr != nil {
			_ = os.Remove(destPath)
			for _, p := range saved {
				_ = os.Remove(filepath.Join(uploadDir, p))
			}
			httpx.Fail(w, http.StatusInternalServerError, "Gagal menyimpan foto")
			return
		}
		saved = append(saved, name)
	}

	now := s.store.Now()
	res, err := s.store.DB.Exec(
		`INSERT INTO posts (user_id, caption, location, latitude, longitude, image_path, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		u.ID, caption, nullIfEmpty(location), latVal, lngVal, saved[0], now, now,
	)
	if err != nil {
		for _, p := range saved {
			_ = os.Remove(filepath.Join(uploadDir, p))
		}
		httpx.Fail(w, http.StatusInternalServerError, "Gagal membuat postingan")
		return
	}
	id, _ := res.LastInsertId()
	for i, name := range saved {
		if _, err := s.store.DB.Exec(
			`INSERT INTO post_images (post_id, image_path, sort_order) VALUES (?, ?, ?)`,
			id, name, i,
		); err != nil {
			httpx.Fail(w, http.StatusInternalServerError, "Gagal menyimpan galeri foto")
			return
		}
	}
	p, _ := s.findPost(id, u.ID)
	httpx.Created(w, p, "Postingan berhasil diunggah")
}

func (s *Server) deletePost(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	p, err := s.findPost(id, currentUser(r).ID)
	if err != nil {
		httpx.Fail(w, http.StatusNotFound, "Postingan tidak ditemukan")
		return
	}
	u := currentUser(r)
	if p.UserID != u.ID && !auth.IsAdmin(u.Role) {
		httpx.Fail(w, http.StatusForbidden, "Tidak dapat menghapus postingan ini")
		return
	}
	var paths []string
	imgRows, qerr := s.store.DB.Query(`SELECT image_path FROM post_images WHERE post_id = ? ORDER BY sort_order ASC, id ASC`, id)
	if qerr == nil {
		defer imgRows.Close()
		for imgRows.Next() {
			var imgPath string
			if imgRows.Scan(&imgPath) == nil && imgPath != "" {
				paths = append(paths, imgPath)
			}
		}
	}
	if len(paths) == 0 && p.ImageURL != "" {
		paths = append(paths, filepath.Base(p.ImageURL))
	}
	for _, imgPath := range paths {
		_ = os.Remove(filepath.Join(uploadDir, filepath.Base(imgPath)))
	}
	if _, err := s.store.DB.Exec(`DELETE FROM posts WHERE id = ?`, id); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal menghapus postingan")
		return
	}
	httpx.OK(w, nil, "Postingan dihapus")
}

func (s *Server) listComments(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	viewer := currentUser(r)
	if _, err := s.findPost(id, viewer.ID); err != nil {
		httpx.Fail(w, http.StatusNotFound, "Postingan tidak ditemukan")
		return
	}
	rows, err := s.store.DB.Query(`
		SELECT c.id, c.post_id, c.user_id, u.name, c.parent_id, COALESCE(c.reply_to_name, ''), c.body, c.created_at,
		       (SELECT COUNT(*) FROM comment_likes cl WHERE cl.comment_id = c.id),
		       (SELECT COUNT(*) FROM comment_likes cl WHERE cl.comment_id = c.id AND cl.user_id = ?)
		FROM comments c
		JOIN users u ON u.id = c.user_id
		WHERE c.post_id = ?
		ORDER BY COALESCE(c.parent_id, c.id), c.created_at ASC`, viewer.ID, id)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat komentar")
		return
	}
	defer rows.Close()
	list := []Comment{}
	for rows.Next() {
		var c Comment
		var parent sql.NullInt64
		var liked int
		if err := rows.Scan(&c.ID, &c.PostID, &c.UserID, &c.UserName, &parent, &c.ReplyToName, &c.Body, &c.CreatedAt, &c.LikesCount, &liked); err != nil {
			httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat komentar")
			return
		}
		if parent.Valid {
			v := parent.Int64
			c.ParentID = &v
		}
		c.LikedByMe = liked > 0
		list = append(list, c)
	}
	httpx.OK(w, list, "OK")
}

func (s *Server) createComment(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	if _, err := s.findPost(id, currentUser(r).ID); err != nil {
		httpx.Fail(w, http.StatusNotFound, "Postingan tidak ditemukan")
		return
	}
	var req struct {
		Body     string `json:"body"`
		ParentID *int64 `json:"parent_id"`
	}
	if err := httpx.Decode(r, &req); err != nil {
		httpx.Fail(w, http.StatusBadRequest, "Body JSON tidak valid")
		return
	}
	req.Body = strings.TrimSpace(req.Body)
	if req.Body == "" {
		httpx.Validation(w, map[string][]string{"body": {"Komentar tidak boleh kosong"}})
		return
	}
	if len(req.Body) > 1000 {
		httpx.Validation(w, map[string][]string{"body": {"Komentar maksimal 1000 karakter"}})
		return
	}

	var replyTo string
	var parentVal any
	if req.ParentID != nil && *req.ParentID > 0 {
		var parentPostID int64
		var parentName string
		var rootParent sql.NullInt64
		err := s.store.DB.QueryRow(
			`SELECT c.post_id, u.name, c.parent_id FROM comments c JOIN users u ON u.id = c.user_id WHERE c.id = ?`,
			*req.ParentID,
		).Scan(&parentPostID, &parentName, &rootParent)
		if err != nil || parentPostID != id {
			httpx.Fail(w, http.StatusUnprocessableEntity, "Komentar yang dibalas tidak valid")
			return
		}
		// flatten: reply to a reply still attaches under the root parent thread
		if rootParent.Valid {
			parentVal = rootParent.Int64
		} else {
			parentVal = *req.ParentID
		}
		replyTo = parentName
		if !strings.HasPrefix(req.Body, "@"+parentName) {
			req.Body = "@" + parentName + " " + req.Body
		}
	} else {
		parentVal = nil
	}

	u := currentUser(r)
	now := s.store.Now()
	res, err := s.store.DB.Exec(
		`INSERT INTO comments (post_id, user_id, parent_id, reply_to_name, body, created_at) VALUES (?, ?, ?, ?, ?, ?)`,
		id, u.ID, parentVal, nullIfEmpty(replyTo), req.Body, now,
	)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal mengirim komentar")
		return
	}
	cid, _ := res.LastInsertId()
	c := Comment{ID: cid, PostID: id, UserID: u.ID, UserName: "", ReplyToName: replyTo, Body: req.Body, CreatedAt: now}
	if parentVal != nil {
		v := parentVal.(int64)
		c.ParentID = &v
	}
	_ = s.store.DB.QueryRow(`SELECT name FROM users WHERE id = ?`, u.ID).Scan(&c.UserName)
	httpx.Created(w, c, "Komentar terkirim")
}

func nullIfEmpty(v string) any {
	if v == "" {
		return nil
	}
	return v
}

func (s *Server) deleteComment(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	var userID int64
	err := s.store.DB.QueryRow(`SELECT user_id FROM comments WHERE id = ?`, id).Scan(&userID)
	if err != nil {
		httpx.Fail(w, http.StatusNotFound, "Komentar tidak ditemukan")
		return
	}
	u := currentUser(r)
	if userID != u.ID && !auth.IsAdmin(u.Role) {
		httpx.Fail(w, http.StatusForbidden, "Tidak dapat menghapus komentar ini")
		return
	}
	if _, err := s.store.DB.Exec(`DELETE FROM comments WHERE id = ?`, id); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal menghapus komentar")
		return
	}
	httpx.OK(w, nil, "Komentar dihapus")
}

func (s *Server) likeComment(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	u := currentUser(r)
	c, err := s.findComment(id, u.ID)
	if err != nil {
		httpx.Fail(w, http.StatusNotFound, "Komentar tidak ditemukan")
		return
	}
	if !c.LikedByMe {
		if _, err := s.store.DB.Exec(
			`INSERT INTO comment_likes (comment_id, user_id, created_at) VALUES (?, ?, ?)`,
			id, u.ID, s.store.Now(),
		); err != nil {
			httpx.Fail(w, http.StatusInternalServerError, "Gagal menyukai komentar")
			return
		}
	}
	c, _ = s.findComment(id, u.ID)
	httpx.OK(w, c, "Disukai")
}

func (s *Server) unlikeComment(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	u := currentUser(r)
	if _, err := s.findComment(id, u.ID); err != nil {
		httpx.Fail(w, http.StatusNotFound, "Komentar tidak ditemukan")
		return
	}
	if _, err := s.store.DB.Exec(`DELETE FROM comment_likes WHERE comment_id = ? AND user_id = ?`, id, u.ID); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal membatalkan like")
		return
	}
	c, _ := s.findComment(id, u.ID)
	httpx.OK(w, c, "Like dibatalkan")
}

func (s *Server) findComment(id, viewerID int64) (Comment, error) {
	var c Comment
	var parent sql.NullInt64
	var liked int
	err := s.store.DB.QueryRow(`
		SELECT c.id, c.post_id, c.user_id, u.name, c.parent_id, COALESCE(c.reply_to_name, ''), c.body, c.created_at,
		       (SELECT COUNT(*) FROM comment_likes cl WHERE cl.comment_id = c.id),
		       (SELECT COUNT(*) FROM comment_likes cl WHERE cl.comment_id = c.id AND cl.user_id = ?)
		FROM comments c
		JOIN users u ON u.id = c.user_id
		WHERE c.id = ?`, viewerID, id).Scan(
		&c.ID, &c.PostID, &c.UserID, &c.UserName, &parent, &c.ReplyToName, &c.Body, &c.CreatedAt, &c.LikesCount, &liked,
	)
	if err != nil {
		return c, err
	}
	if parent.Valid {
		v := parent.Int64
		c.ParentID = &v
	}
	c.LikedByMe = liked > 0
	return c, nil
}

func (s *Server) likePost(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	u := currentUser(r)
	if _, err := s.findPost(id, u.ID); err != nil {
		httpx.Fail(w, http.StatusNotFound, "Postingan tidak ditemukan")
		return
	}
	var exists int
	_ = s.store.DB.QueryRow(`SELECT COUNT(*) FROM likes WHERE post_id = ? AND user_id = ?`, id, u.ID).Scan(&exists)
	if exists == 0 {
		if _, err := s.store.DB.Exec(`INSERT INTO likes (post_id, user_id, created_at) VALUES (?, ?, ?)`, id, u.ID, s.store.Now()); err != nil {
			httpx.Fail(w, http.StatusInternalServerError, "Gagal memberi like")
			return
		}
	}
	p, _ := s.findPost(id, u.ID)
	httpx.OK(w, p, "Disukai")
}

func (s *Server) unlikePost(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	u := currentUser(r)
	if _, err := s.findPost(id, u.ID); err != nil {
		httpx.Fail(w, http.StatusNotFound, "Postingan tidak ditemukan")
		return
	}
	if _, err := s.store.DB.Exec(`DELETE FROM likes WHERE post_id = ? AND user_id = ?`, id, u.ID); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal membatalkan like")
		return
	}
	p, _ := s.findPost(id, u.ID)
	httpx.OK(w, p, "Like dibatalkan")
}

func (s *Server) findPost(id, viewerID int64) (Post, error) {
	var p Post
	var path string
	var liked int
	var lat, lng sql.NullFloat64
	err := s.store.DB.QueryRow(`
		SELECT p.id, p.user_id, u.name, p.caption, COALESCE(p.location, ''), p.latitude, p.longitude, p.image_path,
		       (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id),
		       (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id),
		       (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id AND l.user_id = ?),
		       p.created_at, p.updated_at
		FROM posts p
		JOIN users u ON u.id = p.user_id
		WHERE p.id = ?`, viewerID, id).Scan(
		&p.ID, &p.UserID, &p.UserName, &p.Caption, &p.Location, &lat, &lng, &path, &p.CommentsCount, &p.LikesCount, &liked, &p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		return p, err
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
	p.ImageURLs = s.postImageURLs(id, path)
	if len(p.ImageURLs) > 0 {
		p.ImageURL = p.ImageURLs[0]
	}
	return p, nil
}

func (s *Server) postImageURLs(postID int64, fallbackPath string) []string {
	urls := []string{}
	rows, err := s.store.DB.Query(
		`SELECT image_path FROM post_images WHERE post_id = ? ORDER BY sort_order ASC, id ASC`,
		postID,
	)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var p string
			if rows.Scan(&p) == nil && p != "" {
				urls = append(urls, "/uploads/"+filepath.Base(p))
			}
		}
	}
	if len(urls) == 0 && fallbackPath != "" {
		urls = append(urls, "/uploads/"+filepath.Base(fallbackPath))
	}
	return urls
}
