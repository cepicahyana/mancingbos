package server

type User struct {
	ID           int64  `json:"id"`
	Name         string `json:"name"`
	Email        string `json:"email"`
	Role         string `json:"role"`
	Points       int    `json:"points"`
	Level        int    `json:"level"`
	Tier         int    `json:"tier"`
	TierName     string `json:"tier_name"`
	PointsToNext int    `json:"points_to_next"`
	CreatedAt    string `json:"created_at"`
	UpdatedAt    string `json:"updated_at"`
}

type Event struct {
	ID                 int64   `json:"id"`
	OwnerID            int64   `json:"owner_id"`
	OwnerName          string  `json:"owner_name"`
	Title              string  `json:"title"`
	Description        string  `json:"description"`
	Date               string  `json:"date"`
	Location           string  `json:"location"`
	RentalEnabled      bool    `json:"rental_enabled"`
	StallID            *int64  `json:"stall_id"`
	StallName          string  `json:"stall_name"`
	MaxParticipants    int     `json:"max_participants"`
	Category           string  `json:"category"`
	RegistrationFee    int     `json:"registration_fee"`
	ParticipantsCount  int     `json:"participants_count"`
	BookingsCount      int     `json:"bookings_count"`
	RentalLocked       bool     `json:"rental_locked"`
	Latitude           *float64 `json:"latitude"`
	Longitude          *float64 `json:"longitude"`
	CreatedAt          string   `json:"created_at"`
	UpdatedAt          string   `json:"updated_at"`
}

type Stall struct {
	ID             int64  `json:"id"`
	OwnerID        int64  `json:"owner_id"`
	Name           string `json:"name"`
	Description    string `json:"description"`
	Location       string `json:"location"`
	DailyRentPrice int    `json:"daily_rent_price"`
	Capacity       int    `json:"capacity"`
	HarianEnabled  bool   `json:"harian_enabled"`
	Scheme         string `json:"scheme"`
	Active         bool   `json:"active"`
	CreatedAt      string `json:"created_at"`
	UpdatedAt      string `json:"updated_at"`
	// availability extras (optional on list)
	BookedSlots     int  `json:"booked_slots,omitempty"`
	RemainingSlots  int  `json:"remaining_slots,omitempty"`
	Available       bool `json:"available,omitempty"`
	BlockedByEvent  bool `json:"blocked_by_event,omitempty"`
	NotOpenOnDate   bool `json:"not_open_on_date,omitempty"`
}

type StallDayAvailability struct {
	Date           string `json:"date"`
	Capacity       int    `json:"capacity"`
	BookedSlots    int    `json:"booked_slots"`
	RemainingSlots int    `json:"remaining_slots"`
	Available      bool   `json:"available"`
	BlockedByEvent bool   `json:"blocked_by_event"`
	NotOpenOnDate  bool   `json:"not_open_on_date"`
}

type EventRegistration struct {
	ID              int64  `json:"id"`
	EventID         int64  `json:"event_id"`
	EventTitle      string `json:"event_title"`
	UserID          int64  `json:"user_id"`
	UserName        string `json:"user_name"`
	Status          string `json:"status"`
	Amount          int    `json:"amount"`
	PaymentProvider string `json:"payment_provider"`
	ExternalID      string `json:"external_id"`
	CreatedAt       string `json:"created_at"`
	UpdatedAt       string `json:"updated_at"`
}

type Booking struct {
	ID             int64  `json:"id"`
	EventID        *int64 `json:"event_id"`
	EventTitle     string `json:"event_title"`
	UserID         int64  `json:"user_id"`
	UserName       string `json:"user_name"`
	StallID        *int64 `json:"stall_id"`
	StallName      string `json:"stall_name"`
	StallLocation  string `json:"stall_location,omitempty"`
	DailyRentPrice int    `json:"daily_rent_price,omitempty"`
	RentalDate     string `json:"rental_date,omitempty"`
	Status         string `json:"status"`
	CreatedAt      string `json:"created_at"`
	UpdatedAt      string `json:"updated_at"`
}

type Weight struct {
	ID        int64   `json:"id"`
	EventID   int64   `json:"event_id"`
	UserID    int64   `json:"user_id"`
	UserName  string  `json:"user_name"`
	Weight    float64 `json:"weight"`
	CreatedAt string  `json:"created_at"`
}

type Post struct {
	ID            int64    `json:"id"`
	UserID        int64    `json:"user_id"`
	UserName      string   `json:"user_name"`
	Caption       string   `json:"caption"`
	Location      string   `json:"location"`
	Latitude      *float64 `json:"latitude"`
	Longitude     *float64 `json:"longitude"`
	ImageURL      string   `json:"image_url"`
	ImageURLs     []string `json:"image_urls"`
	CommentsCount int      `json:"comments_count"`
	LikesCount    int      `json:"likes_count"`
	LikedByMe     bool     `json:"liked_by_me"`
	CreatedAt     string   `json:"created_at"`
	UpdatedAt     string   `json:"updated_at"`
}

type PublicProfile struct {
	ID             int64  `json:"id"`
	Name           string `json:"name"`
	Role           string `json:"role"`
	Points         int    `json:"points"`
	Level          int    `json:"level"`
	Tier           int    `json:"tier"`
	TierName       string `json:"tier_name"`
	PointsToNext   int    `json:"points_to_next"`
	PostsCount     int    `json:"posts_count"`
	FollowersCount int    `json:"followers_count"`
	FollowingCount int    `json:"following_count"`
	FollowedByMe   bool   `json:"followed_by_me"`
	IsMe           bool   `json:"is_me"`
}

type Comment struct {
	ID          int64  `json:"id"`
	PostID      int64  `json:"post_id"`
	UserID      int64  `json:"user_id"`
	UserName    string `json:"user_name"`
	ParentID    *int64 `json:"parent_id"`
	ReplyToName string `json:"reply_to_name"`
	Body        string `json:"body"`
	LikesCount  int    `json:"likes_count"`
	LikedByMe   bool   `json:"liked_by_me"`
	CreatedAt   string `json:"created_at"`
}
