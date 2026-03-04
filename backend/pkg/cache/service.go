package cache

import (
	"context"
	"encoding/json"
	"time"

	"github.com/redis/go-redis/v9"

	"github.com/khair/backend/pkg/observability"
)

// Service provides caching functionality
type Service struct {
	redis   *redis.Client
	prefix  string
	metrics *observability.Metrics
}

// Config holds cache configuration
type Config struct {
	EventListTTL   time.Duration
	EventDetailTTL time.Duration
	GeoSearchTTL   time.Duration
	OrganizerTTL   time.Duration
	DefaultTTL     time.Duration
}

// DefaultConfig returns default cache configuration
func DefaultConfig() *Config {
	return &Config{
		EventListTTL:   60 * time.Second,
		EventDetailTTL: 300 * time.Second,
		GeoSearchTTL:   120 * time.Second,
		OrganizerTTL:   600 * time.Second,
		DefaultTTL:     300 * time.Second,
	}
}

// NewService creates a new cache service
func NewService(redisClient *redis.Client) *Service {
	return &Service{
		redis:   redisClient,
		prefix:  "cache:",
		metrics: observability.GetMetrics(),
	}
}

// Get retrieves a value from cache
func (s *Service) Get(ctx context.Context, key string, dest interface{}) error {
	fullKey := s.prefix + key

	data, err := s.redis.Get(ctx, fullKey).Bytes()
	if err != nil {
		if err == redis.Nil {
			s.metrics.RecordCacheMiss()
			return err
		}
		return err
	}

	s.metrics.RecordCacheHit()
	return json.Unmarshal(data, dest)
}

// Set stores a value in cache
func (s *Service) Set(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
	fullKey := s.prefix + key

	data, err := json.Marshal(value)
	if err != nil {
		return err
	}

	return s.redis.Set(ctx, fullKey, data, ttl).Err()
}

// Delete removes a value from cache
func (s *Service) Delete(ctx context.Context, key string) error {
	fullKey := s.prefix + key
	return s.redis.Del(ctx, fullKey).Err()
}

// DeletePattern removes all keys matching a pattern
func (s *Service) DeletePattern(ctx context.Context, pattern string) error {
	fullPattern := s.prefix + pattern
	keys, err := s.redis.Keys(ctx, fullPattern).Result()
	if err != nil {
		return err
	}

	if len(keys) > 0 {
		return s.redis.Del(ctx, keys...).Err()
	}

	return nil
}

// GetOrSet retrieves from cache or sets from loader function
func (s *Service) GetOrSet(ctx context.Context, key string, dest interface{}, ttl time.Duration, loader func() (interface{}, error)) error {
	// Try cache first
	err := s.Get(ctx, key, dest)
	if err == nil {
		return nil
	}

	// Load from source
	value, err := loader()
	if err != nil {
		return err
	}

	// Store in cache
	if err := s.Set(ctx, key, value, ttl); err != nil {
		// Log but don't fail
		observability.Default().Warn("Failed to cache value", map[string]interface{}{
			"key":   key,
			"error": err.Error(),
		})
	}

	// Copy to destination
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}

	return json.Unmarshal(data, dest)
}

// Event cache keys
const (
	EventListPrefix   = "events:list:"
	EventDetailPrefix = "events:detail:"
	GeoSearchPrefix   = "events:geo:"
	OrganizerPrefix   = "organizer:"
)

// EventListKey generates cache key for event list
func EventListKey(country, city, eventType string, page int) string {
	return EventListPrefix + country + ":" + city + ":" + eventType + ":" + string(rune(page+'0'))
}

// EventDetailKey generates cache key for event detail
func EventDetailKey(eventID string) string {
	return EventDetailPrefix + eventID
}

// GeoSearchKey generates cache key for geo search
func GeoSearchKey(lat, lng float64, radiusKm int) string {
	return GeoSearchPrefix + formatCoord(lat) + ":" + formatCoord(lng) + ":" + string(rune(radiusKm+'0'))
}

// OrganizerKey generates cache key for organizer
func OrganizerKey(organizerID string) string {
	return OrganizerPrefix + organizerID
}

// InvalidateEventList invalidates all event list caches
func (s *Service) InvalidateEventList(ctx context.Context) error {
	return s.DeletePattern(ctx, EventListPrefix+"*")
}

// InvalidateEventDetail invalidates a specific event cache
func (s *Service) InvalidateEventDetail(ctx context.Context, eventID string) error {
	return s.Delete(ctx, EventDetailKey(eventID))
}

// InvalidateGeoSearch invalidates all geo search caches
func (s *Service) InvalidateGeoSearch(ctx context.Context) error {
	return s.DeletePattern(ctx, GeoSearchPrefix+"*")
}

// InvalidateOrganizer invalidates organizer cache
func (s *Service) InvalidateOrganizer(ctx context.Context, organizerID string) error {
	return s.Delete(ctx, OrganizerKey(organizerID))
}

// InvalidateAll clears all caches
func (s *Service) InvalidateAll(ctx context.Context) error {
	return s.DeletePattern(ctx, "*")
}

func formatCoord(v float64) string {
	// Round to 2 decimal places for cache key
	return string(rune(int(v*100)/100 + '0'))
}

// WarmUp pre-warms common cache keys
func (s *Service) WarmUp(ctx context.Context, loader func(key string) (interface{}, error)) error {
	// This would pre-load common queries
	// Implementation depends on specific data access patterns
	return nil
}
