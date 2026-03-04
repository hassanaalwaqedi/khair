package mapservice

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/google/uuid"
)

var (
	// ErrInvalidCoordinates is returned when lat/lng are malformed.
	ErrInvalidCoordinates = errors.New("invalid latitude/longitude values")
	// ErrBoundingBoxAbuse is returned when a viewport is too large.
	ErrBoundingBoxAbuse = errors.New("bounding box exceeds safe map query limits")
	// ErrAuthRequired is returned when personalized recommendation access is unauthenticated.
	ErrAuthRequired = errors.New("authentication required for personalized recommendations")
)

const (
	defaultRadiusKm = 10.0
	minRadiusKm     = 1.0
	maxRadiusKm     = 50.0
	defaultPage     = 1
	defaultPageSize = 60
	maxPageSize     = 200
	maxBBoxAreaDeg  = 16.0 // Approx safety guardrail for bbox abuse.
	maxBBoxSideDeg  = 6.0
)

// Service handles map-related business logic.
type Service struct {
	repo *Repository
}

// NewService creates a new map service.
func NewService(db *sql.DB) *Service {
	return &Service{
		repo: NewRepository(db),
	}
}

// FindNearby executes validated nearby search and returns paginated response.
func (s *Service) FindNearby(ctx context.Context, filter *NearbyFilter) (*NearbyResponse, error) {
	if err := validateCoordinates(filter.Latitude, filter.Longitude); err != nil {
		return nil, err
	}

	normalizeFilterDefaults(filter)

	if filter.Personalized && filter.UserID == nil {
		return nil, ErrAuthRequired
	}

	if !filter.UseViewport {
		filter.MinLat, filter.MinLng, filter.MaxLat, filter.MaxLng = radiusBounds(
			filter.Latitude,
			filter.Longitude,
			filter.RadiusKm,
		)
	} else if isAbusiveBounds(filter.MinLat, filter.MinLng, filter.MaxLat, filter.MaxLng) {
		return nil, ErrBoundingBoxAbuse
	}

	events, totalCount, err := s.repo.FindNearby(ctx, filter)
	if err != nil {
		return nil, err
	}

	return &NearbyResponse{
		Events:      events,
		Page:        filter.Page,
		PageSize:    filter.PageSize,
		TotalCount:  totalCount,
		HasNextPage: int64(filter.Page*filter.PageSize) < totalCount,
	}, nil
}

// ListContextualPlaces returns optional contextual Islamic layer records.
func (s *Service) ListContextualPlaces(ctx context.Context, query *ContextualQuery) ([]ContextualPlace, error) {
	if err := validateBounds(query.MinLat, query.MinLng, query.MaxLat, query.MaxLng); err != nil {
		return nil, err
	}
	if isAbusiveBounds(query.MinLat, query.MinLng, query.MaxLat, query.MaxLng) {
		return nil, ErrBoundingBoxAbuse
	}
	if query.PageSize <= 0 || query.PageSize > maxPageSize {
		query.PageSize = defaultPageSize
	}
	return s.repo.ListContextualPlaces(ctx, query)
}

// GetFilterOptions returns dynamic filter options for map UI.
func (s *Service) GetFilterOptions(ctx context.Context) (*FilterOptionsResponse, error) {
	return s.repo.GetFilterOptions(ctx)
}

// TrackGeoInteraction writes anonymized geo interaction metrics.
func (s *Service) TrackGeoInteraction(ctx context.Context, metric *GeoInteractionMetric) error {
	return s.repo.TrackGeoInteraction(ctx, metric)
}

// BuildGeoRequestLog prepares a stable geo request log payload.
func (s *Service) BuildGeoRequestLog(endpoint string, ipAddress string, filter *NearbyFilter, userID *uuid.UUID, flagged bool, reason string) *GeoRequestLog {
	raw := fmt.Sprintf(
		"%s|%.6f|%.6f|%.2f|%v|%v|%s|%s|%d|%d|%t",
		endpoint,
		filter.Latitude,
		filter.Longitude,
		filter.RadiusKm,
		filter.Categories,
		filter.Gender,
		timeValue(filter.DateFrom),
		timeValue(filter.DateTo),
		filter.Page,
		filter.PageSize,
		filter.UseViewport,
	)
	hash := sha256.Sum256([]byte(raw))

	return &GeoRequestLog{
		UserID:    userID,
		IPAddress: ipAddress,
		Endpoint:  endpoint,
		QueryHash: hex.EncodeToString(hash[:]),
		Latitude:  filter.Latitude,
		Longitude: filter.Longitude,
		RadiusKm:  filter.RadiusKm,
		BBox:      map[string]float64{"min_lat": filter.MinLat, "min_lng": filter.MinLng, "max_lat": filter.MaxLat, "max_lng": filter.MaxLng},
		Filters: map[string]interface{}{
			"categories":  filter.Categories,
			"gender":      filter.Gender,
			"age":         filter.Age,
			"date_from":   timeValue(filter.DateFrom),
			"date_to":     timeValue(filter.DateTo),
			"free_only":   filter.FreeOnly,
			"almost_full": filter.AlmostFull,
			"sort_by":     filter.SortBy,
			"page":        filter.Page,
			"page_size":   filter.PageSize,
		},
		IsFlagged:   flagged,
		FlagReason:  reason,
		RequestedAt: time.Now(),
	}
}

// LogGeoRequest writes a request telemetry event and suppresses failures.
func (s *Service) LogGeoRequest(ctx context.Context, payload *GeoRequestLog) {
	_ = s.repo.LogGeoRequest(ctx, payload)
}

func normalizeFilterDefaults(filter *NearbyFilter) {
	if filter.RadiusKm <= 0 {
		filter.RadiusKm = defaultRadiusKm
	}
	if filter.RadiusKm < minRadiusKm {
		filter.RadiusKm = minRadiusKm
	}
	if filter.RadiusKm > maxRadiusKm {
		filter.RadiusKm = maxRadiusKm
	}
	if filter.Page <= 0 {
		filter.Page = defaultPage
	}
	if filter.PageSize <= 0 {
		filter.PageSize = defaultPageSize
	}
	if filter.PageSize > maxPageSize {
		filter.PageSize = maxPageSize
	}
	if filter.SortBy == "" {
		filter.SortBy = "relevance"
	}
	filter.SortBy = strings.ToLower(filter.SortBy)
	if filter.SortBy != "distance" && filter.SortBy != "relevance" {
		filter.SortBy = "relevance"
	}
	if filter.Categories == nil {
		filter.Categories = []string{}
	}
}

func validateCoordinates(lat, lng float64) error {
	if lat < -90 || lat > 90 || lng < -180 || lng > 180 {
		return ErrInvalidCoordinates
	}
	return nil
}

func validateBounds(minLat, minLng, maxLat, maxLng float64) error {
	if err := validateCoordinates(minLat, minLng); err != nil {
		return err
	}
	if err := validateCoordinates(maxLat, maxLng); err != nil {
		return err
	}
	if minLat >= maxLat || minLng >= maxLng {
		return ErrInvalidCoordinates
	}
	return nil
}

func isAbusiveBounds(minLat, minLng, maxLat, maxLng float64) bool {
	width := maxLng - minLng
	height := maxLat - minLat
	area := width * height
	return width > maxBBoxSideDeg || height > maxBBoxSideDeg || area > maxBBoxAreaDeg
}

func radiusBounds(lat, lng, radiusKm float64) (minLat, minLng, maxLat, maxLng float64) {
	latDelta := radiusKm / 111.0
	cosLat := math.Cos(lat * math.Pi / 180.0)
	if cosLat < 0.2 {
		cosLat = 0.2
	}
	lngDelta := radiusKm / (111.320 * cosLat)
	return lat - latDelta, lng - lngDelta, lat + latDelta, lng + lngDelta
}

func timeValue(t *time.Time) string {
	if t == nil {
		return ""
	}
	return t.UTC().Format(time.RFC3339)
}
