package config

import (
	"os"
	"strconv"
	"strings"
)

type Config struct {
	AppName           string
	Env               string
	Port              string
	Driver            string
	DBPath            string
	DBHost            string
	DBPort            string
	DBName            string
	DBUser            string
	DBPass            string
	JWTSecret         string
	JWTTTL            int // minutes
	GoogleMapsAPIKey  string
}

func Load() Config {
	loadDotEnv(".env")
	ttl, _ := strconv.Atoi(env("JWT_TTL", "60"))
	if ttl <= 0 {
		ttl = 60
	}
	return Config{
		AppName:          env("APP_NAME", "IndoFish"),
		Env:              env("APP_ENV", "local"),
		Port:             env("APP_PORT", "8080"),
		Driver:           strings.ToLower(env("DB_DRIVER", "mysql")),
		DBPath:           env("DB_PATH", "indofish.db"),
		DBHost:           env("DB_HOST", "127.0.0.1"),
		DBPort:           env("DB_PORT", "3306"),
		DBName:           env("DB_DATABASE", "indofish"),
		DBUser:           env("DB_USERNAME", "root"),
		DBPass:           env("DB_PASSWORD", ""),
		JWTSecret:        env("JWT_SECRET", "ganti-secret-indofish-di-produksi"),
		JWTTTL:           ttl,
		GoogleMapsAPIKey: env("GOOGLE_MAPS_API_KEY", ""),
	}
}

func env(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

func loadDotEnv(path string) {
	b, err := os.ReadFile(path)
	if err != nil {
		return
	}
	for _, line := range strings.Split(string(b), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		k = strings.TrimSpace(k)
		v = strings.Trim(strings.TrimSpace(v), `"'`)
		if os.Getenv(k) == "" {
			_ = os.Setenv(k, v)
		}
	}
}
