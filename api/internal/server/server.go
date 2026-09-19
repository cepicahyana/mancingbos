package server

import (
	"context"
	"net/http"
	"os"
	"strconv"
	"strings"

	"indofish/internal/auth"
	"indofish/internal/config"
	"indofish/internal/httpx"
	"indofish/internal/store"
)

type ctxKey int

const userKey ctxKey = 1

type AuthUser struct {
	ID    int64
	Email string
	Role  string
}

type Server struct {
	cfg   config.Config
	store *store.Store
	mux   *http.ServeMux
}

func New(cfg config.Config, st *store.Store) http.Handler {
	s := &Server{cfg: cfg, store: st, mux: http.NewServeMux()}
	_ = os.MkdirAll("uploads", 0o755)
	s.routes()
	return httpx.CORS(s.mux)
}

func (s *Server) routes() {
	s.mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, r *http.Request) {
		httpx.OK(w, map[string]string{"name": s.cfg.AppName}, "API siap")
	})
	s.mux.HandleFunc("POST /api/auth/register", s.register)
	s.mux.HandleFunc("POST /api/auth/login", s.login)
	s.mux.HandleFunc("GET /api/auth/me", s.auth(s.me))

	s.mux.HandleFunc("GET /api/events", s.auth(s.listEvents))
	s.mux.HandleFunc("POST /api/events", s.auth(s.createEvent)) // semua user (mode pelapak)
	s.mux.HandleFunc("GET /api/events/{id}", s.auth(s.getEvent))
	s.mux.HandleFunc("PUT /api/events/{id}", s.auth(s.updateEvent))
	s.mux.HandleFunc("PATCH /api/events/{id}", s.auth(s.updateEvent))
	s.mux.HandleFunc("DELETE /api/events/{id}", s.auth(s.deleteEvent))
	s.mux.HandleFunc("GET /api/events/{id}/bookings", s.auth(s.listEventBookings))
	s.mux.HandleFunc("GET /api/events/{id}/weights", s.auth(s.listEventWeights))
	s.mux.HandleFunc("POST /api/events/{id}/award-winners", s.auth(s.awardEventWinners))
	s.mux.HandleFunc("GET /api/events/{id}/awards", s.auth(s.listEventAwards))
	s.mux.HandleFunc("POST /api/events/{id}/register", s.auth(s.registerEvent))
	s.mux.HandleFunc("GET /api/events/{id}/registrations", s.auth(s.listEventRegistrations))
	s.mux.HandleFunc("PATCH /api/registrations/{id}", s.auth(s.updateRegistration))

	s.mux.HandleFunc("GET /api/stalls", s.auth(s.listStalls))
	s.mux.HandleFunc("GET /api/stalls/{id}/availability", s.auth(s.stallAvailabilityCalendar))
	s.mux.HandleFunc("POST /api/stalls", s.auth(s.createStall))
	s.mux.HandleFunc("PATCH /api/stalls/{id}", s.auth(s.updateStall))
	s.mux.HandleFunc("DELETE /api/stalls/{id}", s.auth(s.deleteStall))

	s.mux.HandleFunc("GET /api/bookings", s.auth(s.listBookings))
	s.mux.HandleFunc("POST /api/bookings", s.auth(s.createBooking, "user", "owner"))
	s.mux.HandleFunc("PATCH /api/bookings/{id}", s.auth(s.updateBooking))
	s.mux.HandleFunc("DELETE /api/bookings/{id}", s.auth(s.cancelBooking))

	s.mux.HandleFunc("GET /api/weights", s.auth(s.listWeights))
	s.mux.HandleFunc("POST /api/weights", s.auth(s.createWeight, "operator", "admin", "superadmin"))

	s.mux.HandleFunc("GET /api/users", s.auth(s.listUsers, "admin", "superadmin"))
	s.mux.HandleFunc("GET /api/users/{id}", s.auth(s.getUser, "admin", "superadmin"))
	s.mux.HandleFunc("PATCH /api/users/{id}", s.auth(s.updateUser, "admin", "superadmin"))
	s.mux.HandleFunc("DELETE /api/users/{id}", s.auth(s.deleteUser, "admin", "superadmin"))

	s.mux.HandleFunc("GET /api/posts", s.auth(s.listPosts))
	s.mux.HandleFunc("POST /api/posts", s.auth(s.createPost))
	s.mux.HandleFunc("GET /api/posts/{id}", s.auth(s.getPost))
	s.mux.HandleFunc("DELETE /api/posts/{id}", s.auth(s.deletePost))
	s.mux.HandleFunc("POST /api/posts/{id}/like", s.auth(s.likePost))
	s.mux.HandleFunc("DELETE /api/posts/{id}/like", s.auth(s.unlikePost))
	s.mux.HandleFunc("GET /api/posts/{id}/comments", s.auth(s.listComments))
	s.mux.HandleFunc("POST /api/posts/{id}/comments", s.auth(s.createComment))
	s.mux.HandleFunc("DELETE /api/comments/{id}", s.auth(s.deleteComment))
	s.mux.HandleFunc("POST /api/comments/{id}/like", s.auth(s.likeComment))
	s.mux.HandleFunc("DELETE /api/comments/{id}/like", s.auth(s.unlikeComment))

	s.mux.HandleFunc("GET /api/profiles/{id}", s.auth(s.getProfile))
	s.mux.HandleFunc("GET /api/profiles/{id}/posts", s.auth(s.listProfilePosts))
	s.mux.HandleFunc("POST /api/users/{id}/follow", s.auth(s.followUser))
	s.mux.HandleFunc("DELETE /api/users/{id}/follow", s.auth(s.unfollowUser))

	s.mux.HandleFunc("GET /api/places/autocomplete", s.auth(s.placesAutocomplete))
	s.mux.HandleFunc("GET /api/places/details", s.auth(s.placesDetails))
	s.mux.HandleFunc("GET /api/places/reverse", s.auth(s.placesReverse))

	s.mux.Handle("GET /uploads/", http.StripPrefix("/uploads/", http.FileServer(http.Dir("uploads"))))
}

func (s *Server) auth(next http.HandlerFunc, roles ...string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(strings.ToLower(header), "bearer ") {
			httpx.Fail(w, http.StatusUnauthorized, "Autentikasi diperlukan")
			return
		}
		claims, err := auth.Parse(s.cfg.JWTSecret, strings.TrimSpace(header[7:]))
		if err != nil {
			httpx.Fail(w, http.StatusUnauthorized, "Token tidak valid atau kedaluwarsa")
			return
		}
		u := AuthUser{ID: claims.UserID, Email: claims.Email, Role: claims.Role}
		if len(roles) > 0 && !contains(roles, u.Role) {
			httpx.Fail(w, http.StatusForbidden, "Akses ditolak untuk peran ini")
			return
		}
		next(w, r.WithContext(context.WithValue(r.Context(), userKey, u)))
	}
}

func currentUser(r *http.Request) AuthUser {
	u, _ := r.Context().Value(userKey).(AuthUser)
	return u
}

func pathID(r *http.Request) (int64, bool) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	return id, err == nil && id > 0
}

func contains(list []string, v string) bool {
	for _, x := range list {
		if x == v {
			return true
		}
	}
	return false
}

func canManageEvent(u AuthUser, ownerID int64) bool {
	return u.ID == ownerID || auth.IsAdmin(u.Role)
}
