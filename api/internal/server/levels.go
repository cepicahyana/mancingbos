package server

// Level: setiap 50 poin = naik 1 level (maks 30).
// Tier: tiap 3 level (maks 10).

var tierNames = []string{
	"Pemula",
	"Pemburu",
	"Pawang",
	"Penakluk",
	"Jawara",
	"Pakar",
	"Juara",
	"Ksatria",
	"Legenda",
	"Raja",
}

func levelFromPoints(points int) int {
	if points < 0 {
		points = 0
	}
	lv := points/50 + 1
	if lv > 30 {
		return 30
	}
	if lv < 1 {
		return 1
	}
	return lv
}

func tierFromLevel(level int) (tier int, name string) {
	if level < 1 {
		level = 1
	}
	if level > 30 {
		level = 30
	}
	tier = (level-1)/3 + 1
	if tier > 10 {
		tier = 10
	}
	name = tierNames[tier-1]
	return tier, name
}

func enrichUserLevel(u *User) {
	u.Level = levelFromPoints(u.Points)
	u.Tier, u.TierName = tierFromLevel(u.Level)
	u.PointsToNext = 50 - (u.Points % 50)
	if u.Level >= 30 {
		u.PointsToNext = 0
	}
}

func (s *Server) addUserPoints(userID int64, delta int) error {
	if delta == 0 {
		return nil
	}
	_, err := s.store.DB.Exec(`UPDATE users SET points = points + ?, updated_at = ? WHERE id = ?`, delta, s.store.Now(), userID)
	return err
}
