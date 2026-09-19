package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"

	"indofish/internal/httpx"
)

func (s *Server) placesAutocomplete(w http.ResponseWriter, r *http.Request) {
	key := strings.TrimSpace(s.cfg.GoogleMapsAPIKey)
	if key == "" {
		httpx.Fail(w, http.StatusServiceUnavailable, "Google Maps API key belum disetel di server")
		return
	}
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	if len(q) < 2 {
		httpx.OK(w, []any{}, "OK")
		return
	}
	endpoint := "https://maps.googleapis.com/maps/api/place/autocomplete/json?" + url.Values{
		"input":      {q},
		"key":        {key},
		"language":   {"id"},
		"components": {"country:id"},
	}.Encode()
	var raw struct {
		Status      string `json:"status"`
		ErrorMessage string `json:"error_message"`
		Predictions []struct {
			Description string `json:"description"`
			PlaceID     string `json:"place_id"`
		} `json:"predictions"`
	}
	if err := s.fetchGoogleJSON(endpoint, &raw); err != nil {
		httpx.Fail(w, http.StatusBadGateway, "Gagal menghubungi Google Places")
		return
	}
	if raw.Status != "OK" && raw.Status != "ZERO_RESULTS" {
		msg := "Google Places: " + raw.Status
		if raw.ErrorMessage != "" {
			msg = raw.ErrorMessage
		}
		httpx.Fail(w, http.StatusBadGateway, msg)
		return
	}
	out := make([]map[string]string, 0, len(raw.Predictions))
	for _, p := range raw.Predictions {
		out = append(out, map[string]string{
			"description": p.Description,
			"place_id":    p.PlaceID,
		})
	}
	httpx.OK(w, out, "OK")
}

func (s *Server) placesDetails(w http.ResponseWriter, r *http.Request) {
	key := strings.TrimSpace(s.cfg.GoogleMapsAPIKey)
	if key == "" {
		httpx.Fail(w, http.StatusServiceUnavailable, "Google Maps API key belum disetel di server")
		return
	}
	placeID := strings.TrimSpace(r.URL.Query().Get("place_id"))
	if placeID == "" {
		httpx.Fail(w, http.StatusBadRequest, "place_id wajib")
		return
	}
	endpoint := "https://maps.googleapis.com/maps/api/place/details/json?" + url.Values{
		"place_id": {placeID},
		"fields":   {"formatted_address,name,geometry"},
		"key":      {key},
		"language": {"id"},
	}.Encode()
	var raw struct {
		Status       string `json:"status"`
		ErrorMessage string `json:"error_message"`
		Result       struct {
			Name             string `json:"name"`
			FormattedAddress string `json:"formatted_address"`
			Geometry         struct {
				Location struct {
					Lat float64 `json:"lat"`
					Lng float64 `json:"lng"`
				} `json:"location"`
			} `json:"geometry"`
		} `json:"result"`
	}
	if err := s.fetchGoogleJSON(endpoint, &raw); err != nil {
		httpx.Fail(w, http.StatusBadGateway, "Gagal menghubungi Google Places")
		return
	}
	if raw.Status != "OK" {
		msg := "Google Places: " + raw.Status
		if raw.ErrorMessage != "" {
			msg = raw.ErrorMessage
		}
		httpx.Fail(w, http.StatusBadGateway, msg)
		return
	}
	name := strings.TrimSpace(raw.Result.Name)
	addr := strings.TrimSpace(raw.Result.FormattedAddress)
	label := addr
	if name != "" && !strings.Contains(addr, name) {
		label = name + ", " + addr
	}
	if label == "" {
		label = name
	}
	httpx.OK(w, map[string]any{
		"name":      label,
		"latitude":  raw.Result.Geometry.Location.Lat,
		"longitude": raw.Result.Geometry.Location.Lng,
	}, "OK")
}

func (s *Server) placesReverse(w http.ResponseWriter, r *http.Request) {
	key := strings.TrimSpace(s.cfg.GoogleMapsAPIKey)
	if key == "" {
		httpx.Fail(w, http.StatusServiceUnavailable, "Google Maps API key belum disetel di server")
		return
	}
	lat := strings.TrimSpace(r.URL.Query().Get("lat"))
	lng := strings.TrimSpace(r.URL.Query().Get("lng"))
	if lat == "" || lng == "" {
		httpx.Fail(w, http.StatusBadRequest, "lat dan lng wajib")
		return
	}
	endpoint := "https://maps.googleapis.com/maps/api/geocode/json?" + url.Values{
		"latlng":   {fmt.Sprintf("%s,%s", lat, lng)},
		"key":      {key},
		"language": {"id"},
	}.Encode()
	var raw struct {
		Status       string `json:"status"`
		ErrorMessage string `json:"error_message"`
		Results      []struct {
			FormattedAddress string `json:"formatted_address"`
		} `json:"results"`
	}
	if err := s.fetchGoogleJSON(endpoint, &raw); err != nil {
		httpx.Fail(w, http.StatusBadGateway, "Gagal menghubungi Google Geocoding")
		return
	}
	if raw.Status != "OK" || len(raw.Results) == 0 {
		msg := "Lokasi tidak ditemukan"
		if raw.ErrorMessage != "" {
			msg = raw.ErrorMessage
		} else if raw.Status != "OK" && raw.Status != "ZERO_RESULTS" {
			msg = "Google Geocoding: " + raw.Status
		}
		httpx.Fail(w, http.StatusNotFound, msg)
		return
	}
	httpx.OK(w, map[string]any{
		"name":      raw.Results[0].FormattedAddress,
		"latitude":  lat,
		"longitude": lng,
	}, "OK")
}

func (s *Server) fetchGoogleJSON(endpoint string, dest any) error {
	req, err := http.NewRequest(http.MethodGet, endpoint, nil)
	if err != nil {
		return err
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	return json.NewDecoder(res.Body).Decode(dest)
}
