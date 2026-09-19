package main

import (
	"database/sql"
	"fmt"
	"os"
	"strings"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

func env(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
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
		i := strings.IndexByte(line, '=')
		if i < 1 {
			continue
		}
		k := strings.TrimSpace(line[:i])
		v := strings.TrimSpace(line[i+1:])
		v = strings.Trim(v, `"'`)
		_ = os.Setenv(k, v)
	}
}

func main() {
	loadDotEnv(`c:\ANDROID APK\mancingbos\api\.env`)
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&loc=Local",
		env("DB_USERNAME", "root"),
		env("DB_PASSWORD", ""),
		env("DB_HOST", "127.0.0.1"),
		env("DB_PORT", "3306"),
		env("DB_DATABASE", "indofish"),
	)
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		panic(err)
	}
	defer db.Close()

	_, _ = db.Exec(`ALTER TABLE stalls ADD COLUMN capacity INT NOT NULL DEFAULT 10`)
	_, _ = db.Exec(`ALTER TABLE stalls ADD COLUMN harian_enabled TINYINT(1) NOT NULL DEFAULT 0`)
	_, _ = db.Exec(`ALTER TABLE stalls ADD COLUMN scheme VARCHAR(40) NOT NULL DEFAULT 'kilogebrus'`)
	_, _ = db.Exec(`CREATE TABLE IF NOT EXISTS stall_open_dates (
		id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
		stall_id BIGINT UNSIGNED NOT NULL,
		open_date DATE NOT NULL,
		created_at DATETIME NOT NULL,
		UNIQUE KEY uq_stall_open (stall_id, open_date)
	)`)

	var harianUsers, harianStalls, openDates, open19 int
	_ = db.QueryRow(`SELECT COUNT(*) FROM users WHERE email LIKE 'harian.%'`).Scan(&harianUsers)
	_ = db.QueryRow(`SELECT COUNT(*) FROM stalls WHERE COALESCE(harian_enabled,0)=1`).Scan(&harianStalls)
	_ = db.QueryRow(`SELECT COUNT(*) FROM stall_open_dates`).Scan(&openDates)
	_ = db.QueryRow(`SELECT COUNT(*) FROM stall_open_dates WHERE open_date='2026-09-19'`).Scan(&open19)
	fmt.Printf("users_harian=%d stalls_harian=%d open_dates=%d on_2026-09-19=%d\n", harianUsers, harianStalls, openDates, open19)

	rows, err := db.Query(`SELECT id, name, COALESCE(harian_enabled,0), COALESCE(scheme,''), active FROM stalls ORDER BY id DESC LIMIT 15`)
	if err != nil {
		panic(err)
	}
	defer rows.Close()
	for rows.Next() {
		var id int64
		var name, scheme string
		var hen, active int
		_ = rows.Scan(&id, &name, &hen, &scheme, &active)
		fmt.Printf("stall#%d hen=%d active=%d scheme=%s name=%s\n", id, hen, active, scheme, name)
	}

	// force open today+21 for every active stall (demo)
	now := time.Now().Format("2006-01-02 15:04:05")
	today := time.Now()
	ids := []int64{}
	r2, _ := db.Query(`SELECT id FROM stalls WHERE active=1`)
	for r2 != nil && r2.Next() {
		var id int64
		_ = r2.Scan(&id)
		ids = append(ids, id)
	}
	if r2 != nil {
		r2.Close()
	}
	_, _ = db.Exec(`UPDATE stalls SET harian_enabled=1, scheme=IF(scheme='' OR scheme IS NULL,'kilogebrus',scheme) WHERE active=1`)
	for _, id := range ids {
		for d := 0; d < 21; d++ {
			ds := today.AddDate(0, 0, d).Format("2006-01-02")
			_, _ = db.Exec(`INSERT IGNORE INTO stall_open_dates (stall_id, open_date, created_at) VALUES (?,?,?)`, id, ds, now)
		}
	}
	_ = db.QueryRow(`SELECT COUNT(*) FROM stalls WHERE COALESCE(harian_enabled,0)=1`).Scan(&harianStalls)
	_ = db.QueryRow(`SELECT COUNT(*) FROM stall_open_dates WHERE open_date=?`, today.Format("2006-01-02")).Scan(&open19)
	fmt.Printf("AFTER force: stalls_harian=%d open_today=%d\n", harianStalls, open19)
}
