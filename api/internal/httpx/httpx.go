package httpx

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
)

func JSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func OK(w http.ResponseWriter, data any, message string) {
	if message == "" {
		message = "OK"
	}
	JSON(w, http.StatusOK, map[string]any{"success": true, "message": message, "data": data})
}

func Page(w http.ResponseWriter, data any, page, perPage, total int) {
	JSON(w, http.StatusOK, map[string]any{
		"success": true,
		"message": "OK",
		"data":    data,
		"meta": map[string]int{
			"page":     page,
			"per_page": perPage,
			"total":    total,
		},
	})
}

func Created(w http.ResponseWriter, data any, message string) {
	JSON(w, http.StatusCreated, map[string]any{"success": true, "message": message, "data": data})
}

func Fail(w http.ResponseWriter, status int, message string) {
	JSON(w, status, map[string]any{"success": false, "message": message})
}

func Validation(w http.ResponseWriter, errors map[string][]string) {
	JSON(w, http.StatusUnprocessableEntity, map[string]any{
		"success": false,
		"message": "Validasi gagal",
		"errors":  errors,
	})
}

func Decode(r *http.Request, dst any) error {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	return dec.Decode(dst)
}

func PageParams(r *http.Request) (page, perPage int) {
	page, _ = strconv.Atoi(r.URL.Query().Get("page"))
	perPage, _ = strconv.Atoi(r.URL.Query().Get("per_page"))
	if page < 1 {
		page = 1
	}
	if perPage < 1 || perPage > 100 {
		perPage = 15
	}
	return page, perPage
}

func Search(r *http.Request) string {
	return strings.TrimSpace(r.URL.Query().Get("search"))
}

func Sort(r *http.Request, allowed map[string]string, fallback string) (col, dir string) {
	col = allowed[r.URL.Query().Get("sort")]
	if col == "" {
		col = fallback
	}
	dir = strings.ToLower(r.URL.Query().Get("order"))
	if dir != "asc" {
		dir = "desc"
	}
	return col, dir
}

func CORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
