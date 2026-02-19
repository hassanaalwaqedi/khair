package featureflags

import (
	"context"
	"encoding/json"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"
)

// Flag represents a feature flag
type Flag struct {
	Name        string    `json:"name"`
	Enabled     bool      `json:"enabled"`
	Description string    `json:"description"`
	UpdatedAt   time.Time `json:"updated_at"`
	UpdatedBy   string    `json:"updated_by,omitempty"`
}

// Service provides feature flag functionality
type Service struct {
	redis     *redis.Client
	cache     map[string]*Flag
	cacheMu   sync.RWMutex
	cacheTime time.Time
	cacheTTL  time.Duration
	prefix    string
}

// DefaultFlags defines the default feature flags
var DefaultFlags = map[string]Flag{
	"organizer_registration": {
		Name:        "organizer_registration",
		Enabled:     true,
		Description: "Allow new organizer registrations",
	},
	"event_publishing": {
		Name:        "event_publishing",
		Enabled:     true,
		Description: "Allow organizers to publish events",
	},
	"reporting_system": {
		Name:        "reporting_system",
		Enabled:     true,
		Description: "Allow users to submit reports",
	},
	"guest_event_view": {
		Name:        "guest_event_view",
		Enabled:     true,
		Description: "Allow guests to view events without auth",
	},
	"map_feature": {
		Name:        "map_feature",
		Enabled:     true,
		Description: "Enable map view for events",
	},
}

// NewService creates a new feature flag service
func NewService(redisClient *redis.Client) *Service {
	s := &Service{
		redis:    redisClient,
		cache:    make(map[string]*Flag),
		cacheTTL: 30 * time.Second,
		prefix:   "ff:",
	}

	// Initialize default flags if not present
	s.initializeDefaults(context.Background())

	return s
}

// initializeDefaults sets default flags if they don't exist
func (s *Service) initializeDefaults(ctx context.Context) {
	for name, flag := range DefaultFlags {
		key := s.prefix + name
		exists, _ := s.redis.Exists(ctx, key).Result()
		if exists == 0 {
			flag.UpdatedAt = time.Now()
			data, _ := json.Marshal(flag)
			s.redis.Set(ctx, key, data, 0)
		}
	}
}

// IsEnabled checks if a feature flag is enabled
func (s *Service) IsEnabled(ctx context.Context, flagName string) bool {
	// Check local cache first
	s.cacheMu.RLock()
	if flag, ok := s.cache[flagName]; ok && time.Since(s.cacheTime) < s.cacheTTL {
		s.cacheMu.RUnlock()
		return flag.Enabled
	}
	s.cacheMu.RUnlock()

	// Fetch from Redis
	flag, err := s.Get(ctx, flagName)
	if err != nil {
		// Return default if available
		if df, ok := DefaultFlags[flagName]; ok {
			return df.Enabled
		}
		return false
	}

	return flag.Enabled
}

// Get retrieves a feature flag
func (s *Service) Get(ctx context.Context, flagName string) (*Flag, error) {
	key := s.prefix + flagName

	data, err := s.redis.Get(ctx, key).Bytes()
	if err != nil {
		return nil, err
	}

	var flag Flag
	if err := json.Unmarshal(data, &flag); err != nil {
		return nil, err
	}

	// Update cache
	s.cacheMu.Lock()
	s.cache[flagName] = &flag
	s.cacheTime = time.Now()
	s.cacheMu.Unlock()

	return &flag, nil
}

// Set updates a feature flag
func (s *Service) Set(ctx context.Context, flagName string, enabled bool, updatedBy string) error {
	key := s.prefix + flagName

	flag := Flag{
		Name:      flagName,
		Enabled:   enabled,
		UpdatedAt: time.Now(),
		UpdatedBy: updatedBy,
	}

	// Get existing description
	existing, err := s.Get(ctx, flagName)
	if err == nil {
		flag.Description = existing.Description
	} else if df, ok := DefaultFlags[flagName]; ok {
		flag.Description = df.Description
	}

	data, err := json.Marshal(flag)
	if err != nil {
		return err
	}

	// Update Redis
	if err := s.redis.Set(ctx, key, data, 0).Err(); err != nil {
		return err
	}

	// Invalidate cache
	s.cacheMu.Lock()
	s.cache[flagName] = &flag
	s.cacheTime = time.Now()
	s.cacheMu.Unlock()

	return nil
}

// GetAll retrieves all feature flags
func (s *Service) GetAll(ctx context.Context) ([]Flag, error) {
	pattern := s.prefix + "*"
	keys, err := s.redis.Keys(ctx, pattern).Result()
	if err != nil {
		return nil, err
	}

	flags := make([]Flag, 0, len(keys))
	for _, key := range keys {
		data, err := s.redis.Get(ctx, key).Bytes()
		if err != nil {
			continue
		}

		var flag Flag
		if err := json.Unmarshal(data, &flag); err != nil {
			continue
		}

		flags = append(flags, flag)
	}

	return flags, nil
}

// FeatureFlagMiddleware creates middleware that checks a feature flag
func (s *Service) FeatureFlagMiddleware(flagName string) func(next func()) func() {
	return func(next func()) func() {
		return func() {
			if s.IsEnabled(context.Background(), flagName) {
				next()
			}
		}
	}
}

// RequireFlag returns a Gin middleware that blocks if flag is disabled
func (s *Service) RequireFlag(flagName string) func(c interface{}) {
	return func(c interface{}) {
		// This would be implemented with gin.Context
		// Placeholder for the pattern
	}
}
