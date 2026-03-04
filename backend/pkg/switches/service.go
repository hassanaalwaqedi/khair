package switches

import (
	"context"
	"database/sql"
	"errors"
	"sync"
	"time"

	"github.com/google/uuid"
)

// Switch represents an emergency system switch
type Switch struct {
	ID        uuid.UUID  `json:"id"`
	Name      string     `json:"name"`
	IsEnabled bool       `json:"is_enabled"`
	Reason    *string    `json:"reason,omitempty"`
	ChangedBy *uuid.UUID `json:"changed_by,omitempty"`
	ChangedAt time.Time  `json:"changed_at"`
	ExpiresAt *time.Time `json:"expires_at,omitempty"`
}

// Standard switch names
const (
	SwitchEventPublishing       = "event_publishing"
	SwitchOrganizerRegistration = "organizer_registration"
	SwitchGuestAccess           = "guest_access"
	SwitchReportingSystem       = "reporting_system"
	SwitchFullLockdown          = "full_lockdown"
)

// Service manages emergency switches
type Service struct {
	db       *sql.DB
	cache    map[string]*Switch
	mu       sync.RWMutex
	ttl      time.Duration
	lastLoad time.Time
}

// NewService creates a new switches service
func NewService(db *sql.DB) *Service {
	s := &Service{
		db:    db,
		cache: make(map[string]*Switch),
		ttl:   30 * time.Second,
	}

	// Preload switches
	s.loadAll(context.Background())

	return s
}

// IsEnabled checks if a switch is enabled
func (s *Service) IsEnabled(ctx context.Context, name string) bool {
	s.mu.RLock()

	// Check cache freshness
	if time.Since(s.lastLoad) < s.ttl {
		if sw, ok := s.cache[name]; ok {
			s.mu.RUnlock()

			// Check expiration
			if sw.ExpiresAt != nil && time.Now().After(*sw.ExpiresAt) {
				return true // Expired switches revert to enabled
			}

			return sw.IsEnabled
		}
	}
	s.mu.RUnlock()

	// Reload from DB
	s.loadAll(ctx)

	s.mu.RLock()
	defer s.mu.RUnlock()

	if sw, ok := s.cache[name]; ok {
		return sw.IsEnabled
	}

	return true // Default to enabled if not found
}

// IsLockdown checks if full lockdown is active
func (s *Service) IsLockdown(ctx context.Context) bool {
	return s.IsEnabled(ctx, SwitchFullLockdown)
}

// Set updates a switch state
func (s *Service) Set(ctx context.Context, name string, enabled bool, reason string, changedBy uuid.UUID, expiresIn *time.Duration) error {
	var expiresAt *time.Time
	if expiresIn != nil {
		t := time.Now().Add(*expiresIn)
		expiresAt = &t
	}

	query := `
		UPDATE system_switches 
		SET is_enabled = $1, reason = $2, changed_by = $3, changed_at = NOW(), expires_at = $4
		WHERE switch_name = $5
	`

	result, err := s.db.ExecContext(ctx, query, enabled, reason, changedBy, expiresAt, name)
	if err != nil {
		return err
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return errors.New("switch not found")
	}

	// Invalidate cache
	s.mu.Lock()
	s.lastLoad = time.Time{}
	s.mu.Unlock()

	return nil
}

// Enable enables a switch
func (s *Service) Enable(ctx context.Context, name string, reason string, changedBy uuid.UUID) error {
	return s.Set(ctx, name, true, reason, changedBy, nil)
}

// Disable disables a switch with optional auto-expire
func (s *Service) Disable(ctx context.Context, name string, reason string, changedBy uuid.UUID, expiresIn *time.Duration) error {
	return s.Set(ctx, name, false, reason, changedBy, expiresIn)
}

// GetAll returns all switches
func (s *Service) GetAll(ctx context.Context) ([]Switch, error) {
	s.loadAll(ctx)

	s.mu.RLock()
	defer s.mu.RUnlock()

	switches := make([]Switch, 0, len(s.cache))
	for _, sw := range s.cache {
		switches = append(switches, *sw)
	}

	return switches, nil
}

// Get returns a specific switch
func (s *Service) Get(ctx context.Context, name string) (*Switch, error) {
	s.mu.RLock()
	if sw, ok := s.cache[name]; ok {
		s.mu.RUnlock()
		return sw, nil
	}
	s.mu.RUnlock()

	s.loadAll(ctx)

	s.mu.RLock()
	defer s.mu.RUnlock()

	if sw, ok := s.cache[name]; ok {
		return sw, nil
	}

	return nil, errors.New("switch not found")
}

func (s *Service) loadAll(ctx context.Context) {
	query := `
		SELECT id, switch_name, is_enabled, reason, changed_by, changed_at, expires_at
		FROM system_switches
	`

	rows, err := s.db.QueryContext(ctx, query)
	if err != nil {
		return
	}
	defer rows.Close()

	newCache := make(map[string]*Switch)

	for rows.Next() {
		var sw Switch
		err := rows.Scan(&sw.ID, &sw.Name, &sw.IsEnabled, &sw.Reason, &sw.ChangedBy, &sw.ChangedAt, &sw.ExpiresAt)
		if err != nil {
			continue
		}
		newCache[sw.Name] = &sw
	}

	s.mu.Lock()
	s.cache = newCache
	s.lastLoad = time.Now()
	s.mu.Unlock()
}

// EmergencyLockdown activates full lockdown
func (s *Service) EmergencyLockdown(ctx context.Context, reason string, changedBy uuid.UUID) error {
	// Disable all public-facing features
	s.Disable(ctx, SwitchEventPublishing, "Emergency lockdown: "+reason, changedBy, nil)
	s.Disable(ctx, SwitchOrganizerRegistration, "Emergency lockdown: "+reason, changedBy, nil)
	s.Disable(ctx, SwitchReportingSystem, "Emergency lockdown: "+reason, changedBy, nil)

	// Enable lockdown flag
	return s.Enable(ctx, SwitchFullLockdown, reason, changedBy)
}

// LiftLockdown deactivates full lockdown
func (s *Service) LiftLockdown(ctx context.Context, reason string, changedBy uuid.UUID) error {
	// Re-enable features
	s.Enable(ctx, SwitchEventPublishing, "Lockdown lifted: "+reason, changedBy)
	s.Enable(ctx, SwitchOrganizerRegistration, "Lockdown lifted: "+reason, changedBy)
	s.Enable(ctx, SwitchReportingSystem, "Lockdown lifted: "+reason, changedBy)

	// Disable lockdown flag
	return s.Disable(ctx, SwitchFullLockdown, reason, changedBy, nil)
}
