package server

import (
	"fmt"
	"net/http"
	"strings"

	"indofish/internal/auth"
	"indofish/internal/httpx"
)

type userUpdateReq struct {
	Name string `json:"name"`
	Role string `json:"role"`
}

func (s *Server) listUsers(w http.ResponseWriter, r *http.Request) {
	page, perPage := httpx.PageParams(r)
	search := httpx.Search(r)
	where := "1=1"
	args := []any{}
	if search != "" {
		where = "(name LIKE ? OR email LIKE ?)"
		q := "%" + search + "%"
		args = append(args, q, q)
	}
	var total int
	if err := s.store.DB.QueryRow("SELECT COUNT(*) FROM users WHERE "+where, args...).Scan(&total); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat pengguna")
		return
	}
	q := fmt.Sprintf(`SELECT id, name, email, role, created_at, updated_at FROM users WHERE %s ORDER BY created_at DESC LIMIT ? OFFSET ?`, where)
	args = append(args, perPage, (page-1)*perPage)
	rows, err := s.store.DB.Query(q, args...)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat pengguna")
		return
	}
	defer rows.Close()
	list := []User{}
	for rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Name, &u.Email, &u.Role, &u.CreatedAt, &u.UpdatedAt); err != nil {
			httpx.Fail(w, http.StatusInternalServerError, "Gagal memuat pengguna")
			return
		}
		list = append(list, u)
	}
	httpx.Page(w, list, page, perPage, total)
}

func (s *Server) getUser(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	u, err := s.findUser(id)
	if err != nil {
		httpx.Fail(w, http.StatusNotFound, "Pengguna tidak ditemukan")
		return
	}
	httpx.OK(w, u, "OK")
}

func (s *Server) updateUser(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	u, err := s.findUser(id)
	if err != nil {
		httpx.Fail(w, http.StatusNotFound, "Pengguna tidak ditemukan")
		return
	}
	var req userUpdateReq
	if err := httpx.Decode(r, &req); err != nil {
		httpx.Fail(w, http.StatusBadRequest, "Body JSON tidak valid")
		return
	}
	req.Name = strings.TrimSpace(req.Name)
	req.Role = strings.ToLower(strings.TrimSpace(req.Role))
	errs := map[string][]string{}
	if req.Name == "" {
		errs["name"] = []string{"Nama wajib diisi"}
	}
	if !auth.ValidRole(req.Role) {
		errs["role"] = []string{"Peran tidak valid"}
	}
	if len(errs) > 0 {
		httpx.Validation(w, errs)
		return
	}
	if _, err := s.store.DB.Exec(
		`UPDATE users SET name=?, role=?, updated_at=? WHERE id=?`,
		req.Name, req.Role, s.store.Now(), id,
	); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal mengubah pengguna")
		return
	}
	u.Name = req.Name
	u.Role = req.Role
	httpx.OK(w, u, "Pengguna diperbarui")
}

func (s *Server) deleteUser(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(r)
	if !ok {
		httpx.Fail(w, http.StatusBadRequest, "ID tidak valid")
		return
	}
	if currentUser(r).ID == id {
		httpx.Fail(w, http.StatusUnprocessableEntity, "Tidak dapat menghapus akun sendiri")
		return
	}
	if _, err := s.findUser(id); err != nil {
		httpx.Fail(w, http.StatusNotFound, "Pengguna tidak ditemukan")
		return
	}
	if _, err := s.store.DB.Exec("DELETE FROM users WHERE id = ?", id); err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal menghapus pengguna")
		return
	}
	httpx.OK(w, nil, "Pengguna dihapus")
}

func (s *Server) findUser(id int64) (User, error) {
	var u User
	err := s.store.DB.QueryRow(
		`SELECT id, name, email, role, COALESCE(points, 0), created_at, updated_at FROM users WHERE id = ?`, id,
	).Scan(&u.ID, &u.Name, &u.Email, &u.Role, &u.Points, &u.CreatedAt, &u.UpdatedAt)
	if err == nil {
		enrichUserLevel(&u)
	}
	return u, err
}
