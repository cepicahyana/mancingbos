package main

import (
	"log"
	"net/http"
	"os"
	"time"

	"indofish/internal/config"
	"indofish/internal/server"
	"indofish/internal/store"
)

func main() {
	cfg := config.Load()
	st, err := store.Open(cfg)
	if err != nil {
		log.Fatalf("database: %v", err)
	}
	defer st.DB.Close()

	addr := ":" + cfg.Port
	srv := &http.Server{
		Addr:              addr,
		Handler:           server.New(cfg, st),
		ReadHeaderTimeout: 10 * time.Second,
	}
	log.Printf("%s API listening on %s (db=%s)", cfg.AppName, addr, cfg.Driver)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Println(err)
		os.Exit(1)
	}
}
