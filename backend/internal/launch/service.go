package launch

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

// Config holds soft launch configuration
type Config struct {
	// Country restriction
	LaunchCountryCode string `json:"launch_country_code"`
	CountryRestricted bool   `json:"country_restricted"`

	// Organizer limits
	MaxOrganizers     int  `json:"max_organizers"`
	OrganizerLimited  bool `json:"organizer_limited"`
	CurrentOrganizers int  `json:"current_organizers"`

	// Invite-only mode
	InviteOnlyMode bool `json:"invite_only_mode"`

	// Timestamps
	UpdatedAt time.Time `json:"updated_at"`
}

// InvitationCode represents an invitation code for organizers
type InvitationCode struct {
	Code        string     `json:"code"`
	Email       string     `json:"email,omitempty"`
	CreatedBy   uuid.UUID  `json:"created_by"`
	CreatedAt   time.Time  `json:"created_at"`
	UsedAt      *time.Time `json:"used_at,omitempty"`
	UsedBy      *uuid.UUID `json:"used_by,omitempty"`
	IsUsed      bool       `json:"is_used"`
	ExpiresAt   time.Time  `json:"expires_at"`
}

// Service provides soft launch control functionality
type Service struct {
	redis  *redis.Client
	config *Config
}

const (
	configKey       = "launch:config"
	inviteKeyPrefix = "launch:invite:"
	inviteListKey   = "launch:invites"
)

// DefaultConfig returns default launch configuration
func DefaultConfig() *Config {
	return &Config{
		LaunchCountryCode: "SA", // Saudi Arabia as default
		CountryRestricted: true,
		MaxOrganizers:     100,
		OrganizerLimited:  true,
		CurrentOrganizers: 0,
		InviteOnlyMode:    false,
		UpdatedAt:         time.Now(),
	}
}

// NewService creates a new launch control service
func NewService(redisClient *redis.Client) *Service {
	s := &Service{
		redis:  redisClient,
		config: DefaultConfig(),
	}

	// Load config from Redis
	s.loadConfig(context.Background())

	return s
}

// loadConfig loads configuration from Redis
func (s *Service) loadConfig(ctx context.Context) error {
	data, err := s.redis.Get(ctx, configKey).Bytes()
	if err != nil {
		if err == redis.Nil {
			// Save default config
			return s.saveConfig(ctx)
		}
		return err
	}

	return json.Unmarshal(data, s.config)
}

// saveConfig saves configuration to Redis
func (s *Service) saveConfig(ctx context.Context) error {
	s.config.UpdatedAt = time.Now()
	data, err := json.Marshal(s.config)
	if err != nil {
		return err
	}

	return s.redis.Set(ctx, configKey, data, 0).Err()
}

// GetConfig returns current launch configuration
func (s *Service) GetConfig(ctx context.Context) *Config {
	s.loadConfig(ctx)
	return s.config
}

// UpdateConfig updates launch configuration
func (s *Service) UpdateConfig(ctx context.Context, updates map[string]interface{}) error {
	if v, ok := updates["launch_country_code"].(string); ok {
		s.config.LaunchCountryCode = v
	}
	if v, ok := updates["country_restricted"].(bool); ok {
		s.config.CountryRestricted = v
	}
	if v, ok := updates["max_organizers"].(int); ok {
		s.config.MaxOrganizers = v
	}
	if v, ok := updates["organizer_limited"].(bool); ok {
		s.config.OrganizerLimited = v
	}
	if v, ok := updates["invite_only_mode"].(bool); ok {
		s.config.InviteOnlyMode = v
	}

	return s.saveConfig(ctx)
}

// CanRegisterOrganizer checks if a new organizer can register
func (s *Service) CanRegisterOrganizer(ctx context.Context, country string, inviteCode string) error {
	config := s.GetConfig(ctx)

	// Check country restriction
	if config.CountryRestricted && country != config.LaunchCountryCode {
		return errors.New("organizer registration is restricted to " + config.LaunchCountryCode)
	}

	// Check organizer limit
	if config.OrganizerLimited && config.CurrentOrganizers >= config.MaxOrganizers {
		return errors.New("maximum number of organizers reached")
	}

	// Check invite-only mode
	if config.InviteOnlyMode {
		if inviteCode == "" {
			return errors.New("invitation code required")
		}

		valid, err := s.ValidateInviteCode(ctx, inviteCode)
		if err != nil || !valid {
			return errors.New("invalid or expired invitation code")
		}
	}

	return nil
}

// IncrementOrganizerCount increments the current organizer count
func (s *Service) IncrementOrganizerCount(ctx context.Context) error {
	s.config.CurrentOrganizers++
	return s.saveConfig(ctx)
}

// DecrementOrganizerCount decrements the current organizer count
func (s *Service) DecrementOrganizerCount(ctx context.Context) error {
	if s.config.CurrentOrganizers > 0 {
		s.config.CurrentOrganizers--
	}
	return s.saveConfig(ctx)
}

// GenerateInviteCode creates a new invitation code
func (s *Service) GenerateInviteCode(ctx context.Context, email string, createdBy uuid.UUID, validDays int) (*InvitationCode, error) {
	// Generate random code
	bytes := make([]byte, 8)
	if _, err := rand.Read(bytes); err != nil {
		return nil, err
	}
	code := hex.EncodeToString(bytes)

	invite := &InvitationCode{
		Code:      code,
		Email:     email,
		CreatedBy: createdBy,
		CreatedAt: time.Now(),
		IsUsed:    false,
		ExpiresAt: time.Now().AddDate(0, 0, validDays),
	}

	// Store in Redis
	data, err := json.Marshal(invite)
	if err != nil {
		return nil, err
	}

	key := inviteKeyPrefix + code
	if err := s.redis.Set(ctx, key, data, time.Duration(validDays)*24*time.Hour).Err(); err != nil {
		return nil, err
	}

	// Add to list
	s.redis.SAdd(ctx, inviteListKey, code)

	return invite, nil
}

// ValidateInviteCode checks if an invitation code is valid
func (s *Service) ValidateInviteCode(ctx context.Context, code string) (bool, error) {
	key := inviteKeyPrefix + code
	data, err := s.redis.Get(ctx, key).Bytes()
	if err != nil {
		if err == redis.Nil {
			return false, nil
		}
		return false, err
	}

	var invite InvitationCode
	if err := json.Unmarshal(data, &invite); err != nil {
		return false, err
	}

	// Check if used
	if invite.IsUsed {
		return false, nil
	}

	// Check expiration
	if time.Now().After(invite.ExpiresAt) {
		return false, nil
	}

	return true, nil
}

// UseInviteCode marks an invitation code as used
func (s *Service) UseInviteCode(ctx context.Context, code string, usedBy uuid.UUID) error {
	key := inviteKeyPrefix + code
	data, err := s.redis.Get(ctx, key).Bytes()
	if err != nil {
		return err
	}

	var invite InvitationCode
	if err := json.Unmarshal(data, &invite); err != nil {
		return err
	}

	now := time.Now()
	invite.IsUsed = true
	invite.UsedAt = &now
	invite.UsedBy = &usedBy

	updatedData, err := json.Marshal(invite)
	if err != nil {
		return err
	}

	return s.redis.Set(ctx, key, updatedData, 0).Err()
}

// ListInviteCodes returns all invitation codes
func (s *Service) ListInviteCodes(ctx context.Context) ([]InvitationCode, error) {
	codes, err := s.redis.SMembers(ctx, inviteListKey).Result()
	if err != nil {
		return nil, err
	}

	invites := make([]InvitationCode, 0, len(codes))
	for _, code := range codes {
		key := inviteKeyPrefix + code
		data, err := s.redis.Get(ctx, key).Bytes()
		if err != nil {
			continue
		}

		var invite InvitationCode
		if err := json.Unmarshal(data, &invite); err != nil {
			continue
		}

		invites = append(invites, invite)
	}

	return invites, nil
}

// RevokeInviteCode revokes an invitation code
func (s *Service) RevokeInviteCode(ctx context.Context, code string) error {
	key := inviteKeyPrefix + code
	s.redis.Del(ctx, key)
	s.redis.SRem(ctx, inviteListKey, code)
	return nil
}
