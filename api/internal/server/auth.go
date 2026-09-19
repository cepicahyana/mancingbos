package server

import (
	"net/http"
	"strings"

	"indofish/internal/auth"
	"indofish/internal/httpx"
)

type registerReq struct {
	Name     string `json:"name"`
	Email    string `json:"email"`
	Password string `json:"password"`
	Role     string `json:"role"`
}

type loginReq struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (s *Server) register(w http.ResponseWriter, r *http.Request) {
	var req registerReq
	if err := httpx.Decode(r, &req); err != nil {
		httpx.Fail(w, http.StatusBadRequest, "Body JSON tidak valid")
		return
	}
	req.Name = strings.TrimSpace(req.Name)
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))
	req.Role = strings.ToLower(strings.TrimSpace(req.Role))
	if req.Role == "" {
		req.Role = "user"
	}
	errs := map[string][]string{}
	if req.Name == "" {
		errs["name"] = []string{"Nama wajib diisi"}
	}
	if !strings.Contains(req.Email, "@") {
		errs["email"] = []string{"Email tidak valid"}
	}
	if len(req.Password) < 6 {
		errs["password"] = []string{"Password minimal 6 karakter"}
	}
	if !auth.PublicRegisterRole(req.Role) {
		errs["role"] = []string{"Peran harus user, owner, atau operator"}
	}
	if len(errs) > 0 {
		httpx.Validation(w, errs)
		return
	}
	var exists int
	_ = s.store.DB.QueryRow("SELECT COUNT(*) FROM users WHERE email = ?", req.Email).Scan(&exists)
	if exists > 0 {
		httpx.Validation(w, map[string][]string{"email": {"Email sudah terdaftar"}})
		return
	}
	hash, err := auth.HashPassword(req.Password)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal menyimpan password")
		return
	}
	now := s.store.Now()
	res, err := s.store.DB.Exec(
		`INSERT INTO users (name, email, password, role, points, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		req.Name, req.Email, hash, req.Role, 5, now, now,
	)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal mendaftar")
		return
	}
	id, _ := res.LastInsertId()
	token, err := auth.Sign(s.cfg.JWTSecret, s.cfg.JWTTTL, id, req.Email, req.Role)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal membuat token")
		return
	}
	u := User{ID: id, Name: req.Name, Email: req.Email, Role: req.Role, Points: 5, CreatedAt: now, UpdatedAt: now}
	enrichUserLevel(&u)
	httpx.Created(w, map[string]any{
		"token": token,
		"user":  u,
	}, "Pendaftaran berhasil")
}

func (s *Server) login(w http.ResponseWriter, r *http.Request) {
	var req loginReq
	if err := httpx.Decode(r, &req); err != nil {
		httpx.Fail(w, http.StatusBadRequest, "Body JSON tidak valid")
		return
	}
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))
	if req.Email == "" || req.Password == "" {
		httpx.Validation(w, map[string][]string{
			"email":    {"Email wajib diisi"},
			"password": {"Password wajib diisi"},
		})
		return
	}
	var u User
	var hash string
	err := s.store.DB.QueryRow(
		`SELECT id, name, email, password, role, COALESCE(points, 0), created_at, updated_at FROM users WHERE email = ?`,
		req.Email,
	).Scan(&u.ID, &u.Name, &u.Email, &hash, &u.Role, &u.Points, &u.CreatedAt, &u.UpdatedAt)
	if err != nil || !auth.CheckPassword(hash, req.Password) {
		httpx.Fail(w, http.StatusUnauthorized, "Email atau password salah")
		return
	}
	enrichUserLevel(&u)
	token, err := auth.Sign(s.cfg.JWTSecret, s.cfg.JWTTTL, u.ID, u.Email, u.Role)
	if err != nil {
		httpx.Fail(w, http.StatusInternalServerError, "Gagal membuat token")
		return
	}
	httpx.OK(w, map[string]any{"token": token, "user": u}, "Login berhasil")
}

func (s *Server) me(w http.ResponseWriter, r *http.Request) {
	au := currentUser(r)
	u, err := s.findUser(au.ID)
	if err != nil {
		httpx.Fail(w, http.StatusUnauthorized, "Pengguna tidak ditemukan")
		return
	}
	httpx.OK(w, u, "OK")
}
