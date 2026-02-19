package moderation

import (
	"context"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"

	"github.com/khair/backend/internal/models"
)

// Service provides content moderation functionality
type Service struct {
	db       *sqlx.DB
	keywords []models.BannedKeyword
	patterns []*regexp.Regexp
}

// NewService creates a new moderation service
func NewService(db *sqlx.DB) *Service {
	s := &Service{db: db}
	s.loadKeywords(context.Background())
	return s
}

// loadKeywords loads banned keywords from database
func (s *Service) loadKeywords(ctx context.Context) error {
	query := `SELECT id, keyword, category, severity, is_regex, is_active 
		FROM banned_keywords WHERE is_active = true`

	err := s.db.SelectContext(ctx, &s.keywords, query)
	if err != nil {
		return err
	}

	// Compile regex patterns
	s.patterns = make([]*regexp.Regexp, 0)
	for _, kw := range s.keywords {
		if kw.IsRegex {
			if pattern, err := regexp.Compile("(?i)" + kw.Keyword); err == nil {
				s.patterns = append(s.patterns, pattern)
			}
		}
	}

	return nil
}

// RefreshKeywords reloads keywords from database
func (s *Service) RefreshKeywords(ctx context.Context) error {
	return s.loadKeywords(ctx)
}

// ModerateContent checks content against moderation rules
func (s *Service) ModerateContent(ctx context.Context, content models.ContentToModerate) (*models.ModerationResult, error) {
	result := &models.ModerationResult{
		Passed:   true,
		Flags:    []models.ModerationFlag{},
		Severity: models.SeverityLow,
	}

	// Combine all text for checking
	fullText := strings.ToLower(content.Title + " " + content.Description)

	// Check against banned keywords
	for _, kw := range s.keywords {
		if !kw.IsActive {
			continue
		}

		var matched bool
		var matchedContent string

		if kw.IsRegex {
			if pattern, err := regexp.Compile("(?i)" + kw.Keyword); err == nil {
				if match := pattern.FindString(fullText); match != "" {
					matched = true
					matchedContent = match
				}
			}
		} else {
			if strings.Contains(fullText, strings.ToLower(kw.Keyword)) {
				matched = true
				matchedContent = kw.Keyword
			}
		}

		if matched {
			flag := models.ModerationFlag{
				ID:             uuid.New(),
				FlagType:       models.FlagBannedKeyword,
				FlagReason:     "Matched banned keyword: " + kw.Keyword,
				MatchedContent: &matchedContent,
				Severity:       kw.Severity,
				IsResolved:     false,
				CreatedAt:      time.Now(),
			}
			result.Flags = append(result.Flags, flag)
			result.Passed = false

			// Track highest severity
			if severityLevel(kw.Severity) > severityLevel(result.Severity) {
				result.Severity = kw.Severity
			}
		}
	}

	if !result.Passed {
		result.Reason = "Content contains prohibited keywords or patterns"
	}

	return result, nil
}

// ModerateEvent checks an event and stores flags if found
func (s *Service) ModerateEvent(ctx context.Context, eventID uuid.UUID, content models.ContentToModerate) (*models.ModerationResult, error) {
	result, err := s.ModerateContent(ctx, content)
	if err != nil {
		return nil, err
	}

	// Store flags in database
	for i := range result.Flags {
		result.Flags[i].EventID = eventID
		_, err := s.db.ExecContext(ctx, `
			INSERT INTO moderation_flags (event_id, flag_type, flag_reason, matched_content, severity)
			VALUES ($1, $2, $3, $4, $5)`,
			eventID, result.Flags[i].FlagType, result.Flags[i].FlagReason,
			result.Flags[i].MatchedContent, result.Flags[i].Severity)
		if err != nil {
			return nil, err
		}
	}

	// Update event moderation status
	status := models.ModerationApproved
	if !result.Passed {
		status = models.ModerationFlagged
	}

	_, err = s.db.ExecContext(ctx, `
		UPDATE events SET moderation_status = $1, moderation_reason = $2 WHERE id = $3`,
		status, result.Reason, eventID)
	if err != nil {
		return nil, err
	}

	return result, nil
}

// GetEventFlags retrieves moderation flags for an event
func (s *Service) GetEventFlags(ctx context.Context, eventID uuid.UUID) ([]models.ModerationFlag, error) {
	query := `
		SELECT id, event_id, flag_type, flag_reason, matched_content, severity,
			is_resolved, resolved_by, resolved_at, created_at
		FROM moderation_flags
		WHERE event_id = $1
		ORDER BY created_at DESC`

	var flags []models.ModerationFlag
	err := s.db.SelectContext(ctx, &flags, query, eventID)
	return flags, err
}

// ResolveFlag marks a flag as resolved
func (s *Service) ResolveFlag(ctx context.Context, flagID uuid.UUID, resolvedBy uuid.UUID) error {
	query := `
		UPDATE moderation_flags 
		SET is_resolved = true, resolved_by = $1, resolved_at = NOW()
		WHERE id = $2`

	_, err := s.db.ExecContext(ctx, query, resolvedBy, flagID)
	return err
}

// AddKeyword adds a new banned keyword
func (s *Service) AddKeyword(ctx context.Context, keyword models.BannedKeyword) error {
	query := `
		INSERT INTO banned_keywords (keyword, category, severity, is_regex, is_active, created_by)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, created_at`

	err := s.db.QueryRowContext(ctx, query,
		keyword.Keyword, keyword.Category, keyword.Severity,
		keyword.IsRegex, keyword.IsActive, keyword.CreatedBy,
	).Scan(&keyword.ID, &keyword.CreatedAt)

	if err == nil {
		s.loadKeywords(ctx) // Refresh cache
	}

	return err
}

// RemoveKeyword deactivates a banned keyword
func (s *Service) RemoveKeyword(ctx context.Context, keywordID uuid.UUID) error {
	query := `UPDATE banned_keywords SET is_active = false WHERE id = $1`
	_, err := s.db.ExecContext(ctx, query, keywordID)

	if err == nil {
		s.loadKeywords(ctx) // Refresh cache
	}

	return err
}

// GetKeywords retrieves all banned keywords
func (s *Service) GetKeywords(ctx context.Context, activeOnly bool) ([]models.BannedKeyword, error) {
	query := `SELECT id, keyword, category, severity, is_regex, is_active, created_by, created_at
		FROM banned_keywords`
	if activeOnly {
		query += ` WHERE is_active = true`
	}
	query += ` ORDER BY category, keyword`

	var keywords []models.BannedKeyword
	err := s.db.SelectContext(ctx, &keywords, query)
	return keywords, err
}

// severityLevel returns numeric level for severity comparison
func severityLevel(s models.Severity) int {
	switch s {
	case models.SeverityLow:
		return 1
	case models.SeverityMedium:
		return 2
	case models.SeverityHigh:
		return 3
	case models.SeverityCritical:
		return 4
	default:
		return 0
	}
}

// ModerationHook interface for future AI integration
type ModerationHook interface {
	// CheckContent allows external moderation systems to review content
	CheckContent(ctx context.Context, content models.ContentToModerate) (*models.ModerationResult, error)
}

// RegisterHook registers an external moderation hook (for AI integration)
func (s *Service) RegisterHook(hook ModerationHook) {
	// TODO: Implement hook registration for AI moderation
	// This is a placeholder for future AI integration
}
