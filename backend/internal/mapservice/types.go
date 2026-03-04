package mapservice

import (
	"time"

	"github.com/google/uuid"
)

// NearbyFilter represents all map query inputs.
type NearbyFilter struct {
	Latitude  float64
	Longitude float64
	RadiusKm  float64

	UseViewport bool
	MinLat      float64
	MinLng      float64
	MaxLat      float64
	MaxLng      float64

	Categories []string
	Gender     string
	Age        int
	DateFrom   *time.Time
	DateTo     *time.Time
	FreeOnly   bool
	AlmostFull bool

	SortBy       string
	Page         int
	PageSize     int
	Personalized bool
	UserID       *uuid.UUID
}

// NearbyEvent is the projected map payload.
type NearbyEvent struct {
	ID                  uuid.UUID  `json:"id"`
	OrganizationID      uuid.UUID  `json:"organization_id"`
	Title               string     `json:"title"`
	Organization        string     `json:"organization"`
	Category            string     `json:"category"`
	Latitude            float64    `json:"latitude"`
	Longitude           float64    `json:"longitude"`
	StartsAt            time.Time  `json:"starts_at"`
	EndsAt              *time.Time `json:"ends_at,omitempty"`
	Capacity            *int       `json:"capacity,omitempty"`
	ReservedCount       int        `json:"reserved_count"`
	RemainingSeats      *int       `json:"remaining_seats,omitempty"`
	GenderRestriction   *string    `json:"gender_restriction,omitempty"`
	MinAge              *int       `json:"min_age,omitempty"`
	MaxAge              *int       `json:"max_age,omitempty"`
	DistanceKm          float64    `json:"distance_km"`
	TrustLevel          string     `json:"trust_level"`
	IsTrending          bool       `json:"is_trending"`
	RecommendationScore float64    `json:"recommendation_score"`
	Recommended         bool       `json:"recommended"`
	EndingSoon          bool       `json:"ending_soon"`
}

// NearbyResponse holds paginated nearby results.
type NearbyResponse struct {
	Events      []NearbyEvent `json:"events"`
	Page        int           `json:"page"`
	PageSize    int           `json:"page_size"`
	TotalCount  int64         `json:"total_count"`
	HasNextPage bool          `json:"has_next_page"`
}

// ContextualQuery controls optional Islamic contextual layers.
type ContextualQuery struct {
	MinLat float64
	MinLng float64
	MaxLat float64
	MaxLng float64

	PlaceTypes []string
	PageSize   int
}

// ContextualPlace represents an optional contextual pin.
type ContextualPlace struct {
	ID        uuid.UUID `json:"id"`
	Name      string    `json:"name"`
	PlaceType string    `json:"place_type"`
	Address   *string   `json:"address,omitempty"`
	City      *string   `json:"city,omitempty"`
	Country   *string   `json:"country,omitempty"`
	Latitude  float64   `json:"latitude"`
	Longitude float64   `json:"longitude"`
	Verified  bool      `json:"verified"`
}

// FilterOptionsResponse provides dynamic filter metadata.
type FilterOptionsResponse struct {
	Categories         []string `json:"categories"`
	GenderRestrictions []string `json:"gender_restrictions"`
	RadiusOptionsKm    []int    `json:"radius_options_km"`
}

// GeoRequestLog stores geo request telemetry and abuse signals.
type GeoRequestLog struct {
	UserID      *uuid.UUID
	IPAddress   string
	Endpoint    string
	QueryHash   string
	Latitude    float64
	Longitude   float64
	RadiusKm    float64
	BBox        map[string]float64
	Filters     map[string]interface{}
	IsFlagged   bool
	FlagReason  string
	RequestedAt time.Time
}

// GeoInteractionMetric stores anonymized interaction analytics.
type GeoInteractionMetric struct {
	EventType   string                 `json:"event_type"`
	SessionHash string                 `json:"session_hash"`
	UserID      *uuid.UUID             `json:"-"`
	Latitude    *float64               `json:"latitude,omitempty"`
	Longitude   *float64               `json:"longitude,omitempty"`
	DistanceKm  *float64               `json:"distance_km,omitempty"`
	Metadata    map[string]interface{} `json:"metadata,omitempty"`
}
