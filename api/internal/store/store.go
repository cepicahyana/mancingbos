package store

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"indofish/internal/auth"
	"indofish/internal/config"
	_ "modernc.org/sqlite"
)

type Store struct {
	DB     *sql.DB
	Driver string
}

func Open(cfg config.Config) (*Store, error) {
	var (
		db  *sql.DB
		err error
	)
	switch cfg.Driver {
	case "mysql":
		db, err = openMySQL(cfg)
	default:
		db, err = sql.Open("sqlite", cfg.DBPath)
	}
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(8)
	db.SetConnMaxLifetime(30 * time.Minute)
	if err := db.Ping(); err != nil {
		return nil, err
	}
	s := &Store{DB: db, Driver: cfg.Driver}
	if cfg.Driver != "mysql" {
		if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
			return nil, err
		}
	}
	if err := s.migrate(); err != nil {
		return nil, err
	}
	if err := s.seed(); err != nil {
		return nil, err
	}
	return s, nil
}

func openMySQL(cfg config.Config) (*sql.DB, error) {
	if !identOK(cfg.DBName) {
		return nil, fmt.Errorf("nama database tidak valid: %s", cfg.DBName)
	}
	serverDSN := fmt.Sprintf("%s:%s@tcp(%s:%s)/?charset=utf8mb4&parseTime=false&loc=Local",
		cfg.DBUser, cfg.DBPass, cfg.DBHost, cfg.DBPort)
	admin, err := sql.Open("mysql", serverDSN)
	if err != nil {
		return nil, err
	}
	defer admin.Close()
	if _, err := admin.Exec("CREATE DATABASE IF NOT EXISTS `" + cfg.DBName + "` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"); err != nil {
		return nil, err
	}
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=false&loc=Local",
		cfg.DBUser, cfg.DBPass, cfg.DBHost, cfg.DBPort, cfg.DBName)
	return sql.Open("mysql", dsn)
}

func identOK(name string) bool {
	if name == "" {
		return false
	}
	for _, r := range name {
		if (r < 'a' || r > 'z') && (r < 'A' || r > 'Z') && (r < '0' || r > '9') && r != '_' {
			return false
		}
	}
	return true
}

func (s *Store) Now() string {
	return time.Now().Format(time.RFC3339)
}

func (s *Store) migrate() error {
	var stmts []string
	if s.Driver == "mysql" {
		stmts = []string{
			`CREATE TABLE IF NOT EXISTS users (
				id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
				name VARCHAR(120) NOT NULL,
				email VARCHAR(190) NOT NULL UNIQUE,
				password VARCHAR(255) NOT NULL,
				role VARCHAR(32) NOT NULL,
				created_at DATETIME NOT NULL,
				updated_at DATETIME NOT NULL
			)`,
			`CREATE TABLE IF NOT EXISTS events (
				id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
				owner_id BIGINT UNSIGNED NOT NULL,
				title VARCHAR(180) NOT NULL,
				description TEXT,
				date DATE NOT NULL,
				location VARCHAR(180) NOT NULL,
				rental_enabled TINYINT(1) NOT NULL DEFAULT 0,
				created_at DATETIME NOT NULL,
				updated_at DATETIME NOT NULL,
				CONSTRAINT fk_events_owner FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS bookings (
				id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
				event_id BIGINT UNSIGNED NOT NULL,
				user_id BIGINT UNSIGNED NOT NULL,
				stall_name VARCHAR(80) NOT NULL,
				status VARCHAR(32) NOT NULL,
				created_at DATETIME NOT NULL,
				updated_at DATETIME NOT NULL,
				CONSTRAINT fk_bookings_event FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
				CONSTRAINT fk_bookings_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS weights (
				id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
				event_id BIGINT UNSIGNED NOT NULL,
				user_id BIGINT UNSIGNED NOT NULL,
				weight DECIMAL(8,2) NOT NULL,
				created_at DATETIME NOT NULL,
				CONSTRAINT fk_weights_event FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
				CONSTRAINT fk_weights_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS posts (
				id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
				user_id BIGINT UNSIGNED NOT NULL,
				caption TEXT,
				image_path VARCHAR(255) NOT NULL,
				created_at DATETIME NOT NULL,
				updated_at DATETIME NOT NULL,
				CONSTRAINT fk_posts_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS comments (
				id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
				post_id BIGINT UNSIGNED NOT NULL,
				user_id BIGINT UNSIGNED NOT NULL,
				parent_id BIGINT UNSIGNED NULL,
				reply_to_name VARCHAR(120) NULL,
				body TEXT NOT NULL,
				created_at DATETIME NOT NULL,
				CONSTRAINT fk_comments_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
				CONSTRAINT fk_comments_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS likes (
				id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
				post_id BIGINT UNSIGNED NOT NULL,
				user_id BIGINT UNSIGNED NOT NULL,
				created_at DATETIME NOT NULL,
				UNIQUE KEY uq_likes_post_user (post_id, user_id),
				CONSTRAINT fk_likes_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
				CONSTRAINT fk_likes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS post_images (
				id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
				post_id BIGINT UNSIGNED NOT NULL,
				image_path VARCHAR(255) NOT NULL,
				sort_order INT NOT NULL DEFAULT 0,
				CONSTRAINT fk_post_images_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS comment_likes (
				id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
				comment_id BIGINT UNSIGNED NOT NULL,
				user_id BIGINT UNSIGNED NOT NULL,
				created_at DATETIME NOT NULL,
				UNIQUE KEY uq_comment_likes_user (comment_id, user_id),
				CONSTRAINT fk_comment_likes_comment FOREIGN KEY (comment_id) REFERENCES comments(id) ON DELETE CASCADE,
				CONSTRAINT fk_comment_likes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS follows (
				follower_id BIGINT UNSIGNED NOT NULL,
				following_id BIGINT UNSIGNED NOT NULL,
				created_at DATETIME NOT NULL,
				PRIMARY KEY (follower_id, following_id),
				CONSTRAINT fk_follows_follower FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
				CONSTRAINT fk_follows_following FOREIGN KEY (following_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
		}
	} else {
		stmts = []string{
			`CREATE TABLE IF NOT EXISTS users (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				name TEXT NOT NULL,
				email TEXT NOT NULL UNIQUE,
				password TEXT NOT NULL,
				role TEXT NOT NULL,
				created_at TEXT NOT NULL,
				updated_at TEXT NOT NULL
			)`,
			`CREATE TABLE IF NOT EXISTS events (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				owner_id INTEGER NOT NULL,
				title TEXT NOT NULL,
				description TEXT,
				date TEXT NOT NULL,
				location TEXT NOT NULL,
				rental_enabled INTEGER NOT NULL DEFAULT 0,
				created_at TEXT NOT NULL,
				updated_at TEXT NOT NULL,
				FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS bookings (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				event_id INTEGER NOT NULL,
				user_id INTEGER NOT NULL,
				stall_name TEXT NOT NULL,
				status TEXT NOT NULL,
				created_at TEXT NOT NULL,
				updated_at TEXT NOT NULL,
				FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
				FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS weights (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				event_id INTEGER NOT NULL,
				user_id INTEGER NOT NULL,
				weight REAL NOT NULL,
				created_at TEXT NOT NULL,
				FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
				FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS posts (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				user_id INTEGER NOT NULL,
				caption TEXT,
				image_path TEXT NOT NULL,
				created_at TEXT NOT NULL,
				updated_at TEXT NOT NULL,
				FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS comments (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				post_id INTEGER NOT NULL,
				user_id INTEGER NOT NULL,
				parent_id INTEGER,
				reply_to_name TEXT,
				body TEXT NOT NULL,
				created_at TEXT NOT NULL,
				FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
				FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS likes (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				post_id INTEGER NOT NULL,
				user_id INTEGER NOT NULL,
				created_at TEXT NOT NULL,
				UNIQUE(post_id, user_id),
				FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
				FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS post_images (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				post_id INTEGER NOT NULL,
				image_path TEXT NOT NULL,
				sort_order INTEGER NOT NULL DEFAULT 0,
				FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS comment_likes (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				comment_id INTEGER NOT NULL,
				user_id INTEGER NOT NULL,
				created_at TEXT NOT NULL,
				UNIQUE(comment_id, user_id),
				FOREIGN KEY (comment_id) REFERENCES comments(id) ON DELETE CASCADE,
				FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
			`CREATE TABLE IF NOT EXISTS follows (
				follower_id INTEGER NOT NULL,
				following_id INTEGER NOT NULL,
				created_at TEXT NOT NULL,
				PRIMARY KEY (follower_id, following_id),
				FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
				FOREIGN KEY (following_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
		}
	}
	for _, q := range stmts {
		if _, err := s.DB.Exec(q); err != nil {
			return err
		}
	}
	s.ensureReplyColumns()
	s.ensureSocialColumns()
	s.ensurePelapakColumns()
	_ = s.seedPelapakDemo()
	_ = s.seedHarianDemo()
	s.backfillHarianOpenDates()
	s.backfillEventCoords()
	return nil
}

func (s *Store) ensureReplyColumns() {
	if s.Driver == "mysql" {
		_, _ = s.DB.Exec(`ALTER TABLE comments ADD COLUMN parent_id BIGINT UNSIGNED NULL`)
		_, _ = s.DB.Exec(`ALTER TABLE comments ADD COLUMN reply_to_name VARCHAR(120) NULL`)
		return
	}
	_, _ = s.DB.Exec(`ALTER TABLE comments ADD COLUMN parent_id INTEGER`)
	_, _ = s.DB.Exec(`ALTER TABLE comments ADD COLUMN reply_to_name TEXT`)
}

func (s *Store) ensureSocialColumns() {
	if s.Driver == "mysql" {
		_, _ = s.DB.Exec(`ALTER TABLE posts ADD COLUMN location VARCHAR(180) NULL`)
		_, _ = s.DB.Exec(`ALTER TABLE posts ADD COLUMN latitude DOUBLE NULL`)
		_, _ = s.DB.Exec(`ALTER TABLE posts ADD COLUMN longitude DOUBLE NULL`)
		_, _ = s.DB.Exec(`ALTER TABLE users ADD COLUMN points INT NOT NULL DEFAULT 0`)
		_, _ = s.DB.Exec(`CREATE TABLE IF NOT EXISTS event_awards (
			id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			event_id BIGINT UNSIGNED NOT NULL,
			user_id BIGINT UNSIGNED NOT NULL,
			place TINYINT NOT NULL,
			points INT NOT NULL,
			created_at DATETIME NOT NULL,
			UNIQUE KEY uq_event_award_place (event_id, place),
			UNIQUE KEY uq_event_award_user (event_id, user_id),
			CONSTRAINT fk_event_awards_event FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
			CONSTRAINT fk_event_awards_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
		)`)
		return
	}
	_, _ = s.DB.Exec(`ALTER TABLE posts ADD COLUMN location TEXT`)
	_, _ = s.DB.Exec(`ALTER TABLE posts ADD COLUMN latitude REAL`)
	_, _ = s.DB.Exec(`ALTER TABLE posts ADD COLUMN longitude REAL`)
	_, _ = s.DB.Exec(`ALTER TABLE users ADD COLUMN points INTEGER NOT NULL DEFAULT 0`)
	_, _ = s.DB.Exec(`CREATE TABLE IF NOT EXISTS event_awards (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		event_id INTEGER NOT NULL,
		user_id INTEGER NOT NULL,
		place INTEGER NOT NULL,
		points INTEGER NOT NULL,
		created_at TEXT NOT NULL,
		UNIQUE(event_id, place),
		UNIQUE(event_id, user_id),
		FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
		FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
	)`)
}

func (s *Store) ensurePelapakColumns() {
	if s.Driver == "mysql" {
		_, _ = s.DB.Exec(`CREATE TABLE IF NOT EXISTS stalls (
			id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			owner_id BIGINT UNSIGNED NOT NULL,
			name VARCHAR(120) NOT NULL,
			description TEXT,
			location VARCHAR(180) NOT NULL,
			daily_rent_price INT NOT NULL DEFAULT 0,
			active TINYINT(1) NOT NULL DEFAULT 1,
			created_at DATETIME NOT NULL,
			updated_at DATETIME NOT NULL,
			CONSTRAINT fk_stalls_owner FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
		)`)
		_, _ = s.DB.Exec(`ALTER TABLE events ADD COLUMN stall_id BIGINT UNSIGNED NULL`)
		_, _ = s.DB.Exec(`ALTER TABLE events ADD COLUMN max_participants INT NOT NULL DEFAULT 0`)
		_, _ = s.DB.Exec(`ALTER TABLE events ADD COLUMN category VARCHAR(40) NOT NULL DEFAULT 'galatama'`)
		_, _ = s.DB.Exec(`ALTER TABLE events ADD COLUMN registration_fee INT NOT NULL DEFAULT 0`)
		_, _ = s.DB.Exec(`ALTER TABLE events ADD COLUMN latitude DOUBLE NULL`)
		_, _ = s.DB.Exec(`ALTER TABLE events ADD COLUMN longitude DOUBLE NULL`)
		_, _ = s.DB.Exec(`CREATE TABLE IF NOT EXISTS event_registrations (
			id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
			event_id BIGINT UNSIGNED NOT NULL,
			user_id BIGINT UNSIGNED NOT NULL,
			status VARCHAR(32) NOT NULL,
			amount INT NOT NULL DEFAULT 0,
			payment_provider VARCHAR(40) NOT NULL DEFAULT 'xendit',
			external_id VARCHAR(120) NULL,
			created_at DATETIME NOT NULL,
			updated_at DATETIME NOT NULL,
			UNIQUE KEY uq_event_reg_user (event_id, user_id),
			CONSTRAINT fk_event_reg_event FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
			CONSTRAINT fk_event_reg_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
		)`)
		s.ensureRentalColumnsMySQL()
		return
	}
	_, _ = s.DB.Exec(`CREATE TABLE IF NOT EXISTS stalls (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		owner_id INTEGER NOT NULL,
		name TEXT NOT NULL,
		description TEXT,
		location TEXT NOT NULL,
		daily_rent_price INTEGER NOT NULL DEFAULT 0,
		active INTEGER NOT NULL DEFAULT 1,
		created_at TEXT NOT NULL,
		updated_at TEXT NOT NULL,
		FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
	)`)
	_, _ = s.DB.Exec(`ALTER TABLE events ADD COLUMN stall_id INTEGER`)
	_, _ = s.DB.Exec(`ALTER TABLE events ADD COLUMN max_participants INTEGER NOT NULL DEFAULT 0`)
	_, _ = s.DB.Exec(`ALTER TABLE events ADD COLUMN category TEXT NOT NULL DEFAULT 'galatama'`)
	_, _ = s.DB.Exec(`ALTER TABLE events ADD COLUMN registration_fee INTEGER NOT NULL DEFAULT 0`)
	_, _ = s.DB.Exec(`ALTER TABLE events ADD COLUMN latitude REAL`)
	_, _ = s.DB.Exec(`ALTER TABLE events ADD COLUMN longitude REAL`)
	_, _ = s.DB.Exec(`CREATE TABLE IF NOT EXISTS event_registrations (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		event_id INTEGER NOT NULL,
		user_id INTEGER NOT NULL,
		status TEXT NOT NULL,
		amount INTEGER NOT NULL DEFAULT 0,
		payment_provider TEXT NOT NULL DEFAULT 'xendit',
		external_id TEXT,
		created_at TEXT NOT NULL,
		updated_at TEXT NOT NULL,
		UNIQUE(event_id, user_id),
		FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
		FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
	)`)
	s.ensureRentalColumnsSQLite()
}

func (s *Store) ensureRentalColumnsMySQL() {
	_, _ = s.DB.Exec(`ALTER TABLE stalls ADD COLUMN capacity INT NOT NULL DEFAULT 10`)
	_, _ = s.DB.Exec(`ALTER TABLE stalls ADD COLUMN harian_enabled TINYINT(1) NOT NULL DEFAULT 0`)
	_, _ = s.DB.Exec(`ALTER TABLE stalls ADD COLUMN scheme VARCHAR(40) NOT NULL DEFAULT 'kilogebrus'`)
	_, _ = s.DB.Exec(`ALTER TABLE bookings ADD COLUMN stall_id BIGINT UNSIGNED NULL`)
	_, _ = s.DB.Exec(`ALTER TABLE bookings ADD COLUMN rental_date DATE NULL`)
	_, _ = s.DB.Exec(`ALTER TABLE bookings MODIFY event_id BIGINT UNSIGNED NULL`)
	_, _ = s.DB.Exec(`UPDATE stalls SET capacity = 10 WHERE capacity IS NULL OR capacity < 1`)
	_, _ = s.DB.Exec(`CREATE TABLE IF NOT EXISTS stall_open_dates (
		id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
		stall_id BIGINT UNSIGNED NOT NULL,
		open_date DATE NOT NULL,
		created_at DATETIME NOT NULL,
		UNIQUE KEY uq_stall_open (stall_id, open_date),
		CONSTRAINT fk_stall_open_stall FOREIGN KEY (stall_id) REFERENCES stalls(id) ON DELETE CASCADE
	)`)
}

func (s *Store) ensureRentalColumnsSQLite() {
	_, _ = s.DB.Exec(`ALTER TABLE stalls ADD COLUMN capacity INTEGER NOT NULL DEFAULT 10`)
	_, _ = s.DB.Exec(`ALTER TABLE stalls ADD COLUMN harian_enabled INTEGER NOT NULL DEFAULT 0`)
	_, _ = s.DB.Exec(`ALTER TABLE stalls ADD COLUMN scheme TEXT NOT NULL DEFAULT 'kilogebrus'`)
	_, _ = s.DB.Exec(`ALTER TABLE bookings ADD COLUMN stall_id INTEGER`)
	_, _ = s.DB.Exec(`ALTER TABLE bookings ADD COLUMN rental_date TEXT`)
	_, _ = s.DB.Exec(`CREATE TABLE IF NOT EXISTS stall_open_dates (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		stall_id INTEGER NOT NULL,
		open_date TEXT NOT NULL,
		created_at TEXT NOT NULL,
		UNIQUE(stall_id, open_date),
		FOREIGN KEY (stall_id) REFERENCES stalls(id) ON DELETE CASCADE
	)`)
}

func (s *Store) seed() error {
	var n int
	if err := s.DB.QueryRow("SELECT COUNT(*) FROM users").Scan(&n); err != nil {
		return err
	}
	if n > 0 {
		return nil
	}
	hash, err := auth.HashPassword("password")
	if err != nil {
		return err
	}
	now := s.Now()
	users := [][3]string{
		{"Super Admin", "superadmin@indofish.test", "superadmin"},
		{"Admin", "admin@example.com", "admin"},
		{"User Biasa", "user@example.com", "user"},
		{"Budi Lapak", "owner@example.com", "owner"},
		{"Operator Event", "operator@example.com", "operator"},
	}
	ids := make([]int64, 0, len(users))
	for _, u := range users {
		res, err := s.DB.Exec(
			`INSERT INTO users (name, email, password, role, points, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)`,
			u[0], u[1], hash, u[2], 5, now, now,
		)
		if err != nil {
			return err
		}
		id, _ := res.LastInsertId()
		ids = append(ids, id)
	}
	ownerID := ids[3]
	userID := ids[2]
	_, err = s.DB.Exec(
		`INSERT INTO events (owner_id, title, description, date, location, rental_enabled, max_participants, category, registration_fee, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		ownerID,
		"Lomba Mancing Danau Cirata",
		"Lomba mancing terbuka. Pemilik lapak mengizinkan penyewaan spot di tepi danau.",
		"2026-10-12",
		"Danau Cirata, Purwakarta",
		1, 50, "kilogebrus", 75000,
		now, now,
	)
	if err != nil {
		return err
	}
	res, err := s.DB.Exec(
		`INSERT INTO events (owner_id, title, description, date, location, rental_enabled, max_participants, category, registration_fee, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		ownerID,
		"Mancing Santai Waduk Jatiluhur",
		"Event santai untuk pencinta mancing. Sewa lapak dibuka terbatas.",
		"2026-11-02",
		"Waduk Jatiluhur, Purwakarta",
		1, 30, "galapung", 25000,
		now, now,
	)
	if err != nil {
		return err
	}
	eventID, _ := res.LastInsertId()
	_, err = s.DB.Exec(
		`INSERT INTO bookings (event_id, user_id, stall_name, status, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?)`,
		eventID, userID, "Lapak A1", "approved", now, now,
	)
	if err != nil {
		return err
	}
	_, err = s.DB.Exec(
		`INSERT INTO weights (event_id, user_id, weight, created_at) VALUES (?, ?, ?, ?)`,
		eventID, userID, 2.35, now,
	)
	return err
}

// seedPelapakDemo mengisi pelapak + lapak + event berbagai daerah (idempotent).
func (s *Store) seedPelapakDemo() error {
	var n int
	_ = s.DB.QueryRow(`SELECT COUNT(*) FROM users WHERE email = ?`, "pelapak.cirata@indofish.test").Scan(&n)
	if n > 0 {
		return nil
	}
	hash, err := auth.HashPassword("password")
	if err != nil {
		return err
	}
	now := s.Now()

	type pelapak struct {
		name, email string
	}
	owners := []pelapak{
		{"Pak Hendra Cirata", "pelapak.cirata@indofish.test"},
		{"Bu Sari Jatiluhur", "pelapak.jatiluhur@indofish.test"},
		{"Om Rudi Gajah Mungkur", "pelapak.gajahmungkur@indofish.test"},
		{"Mas Dedi Saguling", "pelapak.saguling@indofish.test"},
		{"Kang Asep Situ Cileunca", "pelapak.cileunca@indofish.test"},
		{"Bang Rio Muara Angke", "pelapak.muaraangke@indofish.test"},
		{"Pak Yoga Rawa Pening", "pelapak.rawapening@indofish.test"},
		{"Mas Fajar Kedung Ombo", "pelapak.kedungombo@indofish.test"},
	}
	ownerIDs := make([]int64, 0, len(owners))
	for _, o := range owners {
		res, err := s.DB.Exec(
			`INSERT INTO users (name, email, password, role, points, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)`,
			o.name, o.email, hash, "owner", 55, now, now,
		)
		if err != nil {
			return err
		}
		id, _ := res.LastInsertId()
		ownerIDs = append(ownerIDs, id)
	}

	type stallSeed struct {
		ownerIdx                 int
		name, desc, loc          string
		price                    int
	}
	stalls := []stallSeed{
		{0, "Lapak Cirata Utara", "Spot tepi danau, parkir luas, toilet bersih", "Danau Cirata, Purwakarta, Jawa Barat", 75000},
		{0, "Lapak Cirata Selatan", "Dekat dermaga, cocok lomba berat", "Danau Cirata, Purwakarta, Jawa Barat", 85000},
		{1, "Jatiluhur Spot A", "Waduk tenang, umpan pelet & cacing", "Waduk Jatiluhur, Purwakarta, Jawa Barat", 60000},
		{1, "Jatiluhur Spot B", "Area keluarga, warung tersedia", "Waduk Jatiluhur, Purwakarta, Jawa Barat", 55000},
		{2, "Gajah Mungkur Timur", "Spot favorit ikan mas & nila", "Waduk Gajah Mungkur, Wonogiri, Jawa Tengah", 50000},
		{3, "Saguling Riverside", "Aliran tenang, malam boleh mancing", "Waduk Saguling, Bandung Barat, Jawa Barat", 70000},
		{4, "Cileunca Lake View", "Pemandangan pegunungan, udara sejuk", "Situ Cileunca, Bandung, Jawa Barat", 65000},
		{5, "Muara Angke Coastal", "Mancing laut & muara, sewa perahu", "Muara Angke, Jakarta Utara", 90000},
		{6, "Rawa Pening Classic", "Spot klasik Semarang–Salatiga", "Rawa Pening, Semarang, Jawa Tengah", 45000},
		{7, "Kedung Ombo Basecamp", "Area luas, cocok event team", "Waduk Kedung Ombo, Sragen, Jawa Tengah", 55000},
	}
	stallIDs := make([]int64, 0, len(stalls))
	for _, st := range stalls {
		res, err := s.DB.Exec(
			`INSERT INTO stalls (owner_id, name, description, location, daily_rent_price, active, created_at, updated_at)
			 VALUES (?, ?, ?, ?, ?, 1, ?, ?)`,
			ownerIDs[st.ownerIdx], st.name, st.desc, st.loc, st.price, now, now,
		)
		if err != nil {
			return err
		}
		id, _ := res.LastInsertId()
		stallIDs = append(stallIDs, id)
	}

	type eventSeed struct {
		ownerIdx, stallIdx       int
		title, desc, date, loc   string
		rental                   int
		maxP                     int
		category                 string
		fee                      int
	}
	events := []eventSeed{
		{0, 0, "Galatama Cirata Open 2026", "Kompetisi galatama kolam — hadiah trophy + poin IndoFish.", "2026-10-18", "Danau Cirata, Purwakarta, Jawa Barat", 1, 80, "galatama", 100000},
		{0, 1, "Galapung Cirata Weekend", "Kompetisi galapung, sewa lapak dibuka.", "2026-10-25", "Danau Cirata, Purwakarta, Jawa Barat", 1, 40, "galapung", 35000},
		{1, 2, "Jatiluhur Beregu Challenge", "Kompetisi beregu 3 orang per tim.", "2026-11-08", "Waduk Jatiluhur, Purwakarta, Jawa Barat", 0, 60, "beregu", 150000},
		{1, 3, "Jatiluhur Feeder Night", "Kompetisi feeder malam, lampu disediakan.", "2026-11-15", "Waduk Jatiluhur, Purwakarta, Jawa Barat", 1, 35, "feeder", 40000},
		{2, 4, "Gajah Mungkur Kilogebrus", "Siapa total berat tertinggi dalam 6 jam.", "2026-10-20", "Waduk Gajah Mungkur, Wonogiri, Jawa Tengah", 1, 50, "kilogebrus", 75000},
		{3, 5, "Saguling Casting Open", "Kompetisi casting kategori umum & junior.", "2026-11-01", "Waduk Saguling, Bandung Barat, Jawa Barat", 1, 70, "casting", 85000},
		{4, 6, "Cileunca Galapung Morning", "Galapung pagi di dataran tinggi.", "2026-10-12", "Situ Cileunca, Bandung, Jawa Barat", 1, 25, "galapung", 30000},
		{5, 7, "Muara Angke Kilogebrus Cup", "Kompetisi kilogebrus laut & muara.", "2026-11-22", "Muara Angke, Jakarta Utara", 0, 45, "kilogebrus", 125000},
		{6, 8, "Rawa Pening Galatama Classic", "Galatama klasik komunitas Semarang.", "2026-10-28", "Rawa Pening, Semarang, Jawa Tengah", 1, 40, "galatama", 25000},
		{7, 9, "Kedung Ombo Beregu Battle", "Battle beregu antar komunitas Jawa Tengah.", "2026-12-06", "Waduk Kedung Ombo, Sragen, Jawa Tengah", 1, 90, "beregu", 200000},
		{2, 4, "Wonogiri Feeder Cup", "Kompetisi feeder akhir pekan.", "2026-11-29", "Waduk Gajah Mungkur, Wonogiri, Jawa Tengah", 1, 30, "feeder", 20000},
		{5, 7, "Jakarta Casting Meetup", "Kompetisi casting pemancing Jakarta.", "2026-12-13", "Muara Angke, Jakarta Utara", 1, 50, "casting", 50000},
	}
	for _, ev := range events {
		var stallID any
		if ev.stallIdx >= 0 && ev.stallIdx < len(stallIDs) {
			stallID = stallIDs[ev.stallIdx]
		}
		_, err := s.DB.Exec(
			`INSERT INTO events (owner_id, title, description, date, location, rental_enabled, stall_id, max_participants, category, registration_fee, created_at, updated_at)
			 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
			ownerIDs[ev.ownerIdx], ev.title, ev.desc, ev.date, ev.loc, ev.rental, stallID, ev.maxP, ev.category, ev.fee, now, now,
		)
		if err != nil {
			return err
		}
	}

	// beberapa pemancing dummy
	anglers := [][2]string{
		{"Andi Pemancing", "andi.mancing@indofish.test"},
		{"Rina Strike", "rina.strike@indofish.test"},
		{"Tono Galatama", "tono.galatama@indofish.test"},
	}
	for _, a := range anglers {
		_, _ = s.DB.Exec(
			`INSERT INTO users (name, email, password, role, points, created_at, updated_at) VALUES (?, ?, ?, 'user', 25, ?, ?)`,
			a[0], a[1], hash, now, now,
		)
	}
	return nil
}

// seedHarianDemo: kolam/lapak yang buka mancing harian (kilogebrus / borongan) + tanggal buka.
func (s *Store) seedHarianDemo() error {
	var n int
	_ = s.DB.QueryRow(`SELECT COUNT(*) FROM users WHERE email = ?`, "harian.cirata@indofish.test").Scan(&n)
	already := n > 0
	hash, err := auth.HashPassword("password")
	if err != nil {
		return err
	}
	now := s.Now()

	type ownerSeed struct{ name, email string }
	owners := []ownerSeed{
		{"Bang Irwan Harian Cirata", "harian.cirata@indofish.test"},
		{"Kang Ujang Kolam Bandung", "harian.bandung@indofish.test"},
		{"Mas Yoga Harian Semarang", "harian.semarang@indofish.test"},
		{"Pak Dodi Kolam Bekasi", "harian.bekasi@indofish.test"},
		{"Bu Lina Situ Gede", "harian.situgede@indofish.test"},
		{"Om Eko Waduk Pluit", "harian.pluit@indofish.test"},
	}
	ownerIDs := make([]int64, 0, len(owners))
	for _, o := range owners {
		var id int64
		err := s.DB.QueryRow(`SELECT id FROM users WHERE email = ?`, o.email).Scan(&id)
		if err != nil {
			res, err := s.DB.Exec(
				`INSERT INTO users (name, email, password, role, points, created_at, updated_at) VALUES (?, ?, ?, 'owner', 40, ?, ?)`,
				o.name, o.email, hash, now, now,
			)
			if err != nil {
				return err
			}
			id, _ = res.LastInsertId()
		}
		ownerIDs = append(ownerIDs, id)
	}

	var stallN int
	_ = s.DB.QueryRow(`SELECT COUNT(*) FROM stalls WHERE owner_id = ?`, ownerIDs[0]).Scan(&stallN)
	if already && stallN > 0 {
		return nil
	}

	type harianStall struct {
		ownerIdx        int
		name, desc, loc string
		price, capacity int
		scheme          string
		openDays        int
		skipWeekdays    bool
	}
	items := []harianStall{
		{0, "Cirata Harian Kilogebrus", "Kolam buka tiap hari skema kilo gebrus — bayar sesuai total berat ikan. Kapasitas terbatas.", "Danau Cirata, Purwakarta, Jawa Barat", 0, 20, "kilogebrus", 21, false},
		{0, "Cirata Borongan Family", "Paket borongan harian: 1 spot untuk max 4 orang, umpan & air mineral termasuk.", "Danau Cirata, Purwakarta, Jawa Barat", 250000, 8, "borongan", 14, false},
		{1, "Kolam Galatama Bandung Timur", "Harian kilogebrus + borongan. Spot pelet, parkir motor/mobil.", "Cibiru, Bandung, Jawa Barat", 35000, 16, "kilogebrus_borongan", 18, false},
		{1, "Bandung Weekend Borongan", "Khusus akhir pekan — borongan 6 jam, max 6 pemancing per slot.", "Cileunyi, Bandung, Jawa Barat", 400000, 6, "borongan", 30, true},
		{2, "Rawa Pening Harian KG", "Mancing bebas kilo gebrus di rawaan — timbangan di pos pelapak.", "Rawa Pening, Semarang, Jawa Tengah", 0, 24, "kilogebrus", 20, false},
		{2, "Semarang Borongan Siang", "Borongan 08.00–15.00, spot teduh, warung ikan bakar.", "Genuk, Semarang, Jawa Tengah", 180000, 10, "borongan", 16, false},
		{3, "Bekasi Pond Kilogebrus", "Kolam bundar harian, skema kilo gebrus nila & mas. Tutup kalau hujan deras.", "Tambun, Bekasi, Jawa Barat", 25000, 12, "kilogebrus", 21, false},
		{3, "Bekasi Spot Borongan Malam", "Borongan malam 18.00–24.00, lampu LED, kopi gratis.", "Cikarang, Bekasi, Jawa Barat", 220000, 8, "borongan", 14, false},
		{4, "Situ Gede Mix Harian", "Kilogebrus & borongan — pilih skema saat check-in di loket.", "Situ Gede, Tasikmalaya, Jawa Barat", 40000, 15, "kilogebrus_borongan", 18, false},
		{5, "Pluit Muara Harian KG", "Mancing muara harian kilo gebrus, sewa joran tersedia.", "Pluit, Jakarta Utara, DKI Jakarta", 50000, 18, "kilogebrus", 21, false},
		{5, "Pluit Borongan Group", "Borongan grup max 8 orang, cocok komunitas kantor.", "Pluit, Jakarta Utara, DKI Jakarta", 550000, 5, "borongan", 12, false},
	}

	for _, it := range items {
		res, err := s.DB.Exec(
			`INSERT INTO stalls (owner_id, name, description, location, daily_rent_price, capacity, harian_enabled, scheme, active, created_at, updated_at)
			 VALUES (?, ?, ?, ?, ?, ?, 1, ?, 1, ?, ?)`,
			ownerIDs[it.ownerIdx], it.name, it.desc, it.loc, it.price, it.capacity, it.scheme, now, now,
		)
		if err != nil {
			res, err = s.DB.Exec(
				`INSERT INTO stalls (owner_id, name, description, location, daily_rent_price, capacity, active, created_at, updated_at)
				 VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)`,
				ownerIDs[it.ownerIdx], it.name, it.desc, it.loc, it.price, it.capacity, now, now,
			)
			if err != nil {
				return err
			}
		}
		_, _ = res.LastInsertId()
	}
	return nil
}

// backfillHarianOpenDates memastikan semua lapak harian punya tanggal buka (hari ini + 21 hari).
func (s *Store) backfillHarianOpenDates() {
	now := s.Now()
	loc, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		loc = time.FixedZone("WIB", 7*3600)
	}
	today := time.Now().In(loc)

	// aktifkan flag harian untuk lapak seed jika kolom baru belum ter-set
	_, _ = s.DB.Exec(`UPDATE stalls SET harian_enabled = 1 WHERE harian_enabled = 0 AND (
		name LIKE '%Harian%' OR name LIKE '%Kilogebrus%' OR name LIKE '%Borongan%' OR name LIKE '%Pond%' OR name LIKE '%Weekend Borongan%'
	)`)
	_, _ = s.DB.Exec(`UPDATE stalls SET scheme = 'kilogebrus' WHERE (scheme IS NULL OR scheme = '') AND name LIKE '%Kilogebrus%'`)
	_, _ = s.DB.Exec(`UPDATE stalls SET scheme = 'borongan' WHERE (scheme IS NULL OR scheme = '') AND name LIKE '%Borongan%'`)
	_, _ = s.DB.Exec(`UPDATE stalls SET scheme = 'kilogebrus_borongan' WHERE (scheme IS NULL OR scheme = '') AND (name LIKE '%Mix%' OR name LIKE '%Galatama Bandung%')`)

	rows, err := s.DB.Query(`SELECT id, name FROM stalls WHERE active = 1 AND COALESCE(harian_enabled, 0) = 1`)
	if err != nil {
		// fallback: semua stall aktif yang namanya mengandung kata harian
		rows, err = s.DB.Query(`SELECT id, name FROM stalls WHERE active = 1 AND (
			name LIKE '%Harian%' OR name LIKE '%Kilogebrus%' OR name LIKE '%Borongan%' OR description LIKE '%kilogebrus%' OR description LIKE '%borongan%'
		)`)
		if err != nil {
			return
		}
	}
	defer rows.Close()

	type row struct {
		id   int64
		name string
	}
	list := []row{}
	for rows.Next() {
		var r row
		if rows.Scan(&r.id, &r.name) != nil {
			continue
		}
		list = append(list, r)
	}

	for _, r := range list {
		weekendOnly := strings.Contains(strings.ToLower(r.name), "weekend")
		for d := 0; d < 21; d++ {
			day := today.AddDate(0, 0, d)
			if weekendOnly {
				wd := day.Weekday()
				if wd != time.Saturday && wd != time.Sunday {
					continue
				}
			}
			ds := day.Format("2006-01-02")
			_, err := s.DB.Exec(
				`INSERT IGNORE INTO stall_open_dates (stall_id, open_date, created_at) VALUES (?, ?, ?)`,
				r.id, ds, now,
			)
			if err != nil {
				_, _ = s.DB.Exec(
					`INSERT OR IGNORE INTO stall_open_dates (stall_id, open_date, created_at) VALUES (?, ?, ?)`,
					r.id, ds, now,
				)
			}
		}
	}
}

func (s *Store) backfillEventCoords() {
	spots := []struct {
		like     string
		lat, lng float64
	}{
		{"%Cirata%", -6.7167, 107.3500},
		{"%Jatiluhur%", -6.5236, 107.3667},
		{"%Gajah Mungkur%", -7.7833, 110.9167},
		{"%Wonogiri%", -7.7833, 110.9167},
		{"%Saguling%", -6.9167, 107.3500},
		{"%Cileunca%", -7.1833, 107.5500},
		{"%Muara Angke%", -6.1089, 106.7789},
		{"%Jakarta%", -6.1089, 106.7789},
		{"%Rawa Pening%", -7.2833, 110.4333},
		{"%Kedung Ombo%", -7.2500, 110.8333},
		{"%Purwakarta%", -6.5569, 107.4431},
		{"%Bandung%", -6.9175, 107.6191},
		{"%Semarang%", -7.0051, 110.4381},
	}
	for _, sp := range spots {
		_, _ = s.DB.Exec(
			`UPDATE events SET latitude = ?, longitude = ?
			 WHERE (latitude IS NULL OR latitude = 0) AND location LIKE ?`,
			sp.lat, sp.lng, sp.like,
		)
	}
	// Remap kategori lama → kompetisi
	_, _ = s.DB.Exec(`UPDATE events SET category = 'kilogebrus' WHERE category IN ('lomba_berat')`)
	_, _ = s.DB.Exec(`UPDATE events SET category = 'galatama' WHERE category IN ('lomba_jumlah')`)
	_, _ = s.DB.Exec(`UPDATE events SET category = 'galapung' WHERE category IN ('santuy')`)
	_, _ = s.DB.Exec(`UPDATE events SET category = 'beregu' WHERE category IN ('team')`)
}

