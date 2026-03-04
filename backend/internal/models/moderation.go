package models

import (
	"time"

	"github.com/google/uuid"
)

// ModerationStatus defines event moderation states
type ModerationStatus string

const (
	ModerationPending  ModerationStatus = "pending"
	ModerationApproved ModerationStatus = "approved"
	ModerationFlagged  ModerationStatus = "flagged"
	ModerationRejected ModerationStatus = "rejected"
)

// FlagType defines types of moderation flags
type FlagType string

const (
	FlagBannedKeyword FlagType = "banned_keyword"
	FlagPatternMatch  FlagType = "pattern_match"
	FlagAIFlagged     FlagType = "ai_flagged"
	FlagManualReview  FlagType = "manual_review"
)

// Severity levels for moderation
type Severity string

const (
	SeverityLow      Severity = "low"
	SeverityMedium   Severity = "medium"
	SeverityHigh     Severity = "high"
	SeverityCritical Severity = "critical"
)

// ModerationFlag represents a content flag
type ModerationFlag struct {
	ID             uuid.UUID  `json:"id" db:"id"`
	EventID        uuid.UUID  `json:"event_id" db:"event_id"`
	FlagType       FlagType   `json:"flag_type" db:"flag_type"`
	FlagReason     string     `json:"flag_reason" db:"flag_reason"`
	MatchedContent *string    `json:"matched_content,omitempty" db:"matched_content"`
	Severity       Severity   `json:"severity" db:"severity"`
	IsResolved     bool       `json:"is_resolved" db:"is_resolved"`
	ResolvedBy     *uuid.UUID `json:"resolved_by,omitempty" db:"resolved_by"`
	ResolvedAt     *time.Time `json:"resolved_at,omitempty" db:"resolved_at"`
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
}

// BannedKeyword for content moderation
type BannedKeyword struct {
	ID        uuid.UUID  `json:"id" db:"id"`
	Keyword   string     `json:"keyword" db:"keyword"`
	Category  string     `json:"category" db:"category"`
	Severity  Severity   `json:"severity" db:"severity"`
	IsRegex   bool       `json:"is_regex" db:"is_regex"`
	IsActive  bool       `json:"is_active" db:"is_active"`
	CreatedBy *uuid.UUID `json:"created_by,omitempty" db:"created_by"`
	CreatedAt time.Time  `json:"created_at" db:"created_at"`
}

// ModerationResult from content check
type ModerationResult struct {
	Passed   bool             `json:"passed"`
	Flags    []ModerationFlag `json:"flags,omitempty"`
	Severity Severity         `json:"severity"`
	Reason   string           `json:"reason,omitempty"`
}

// ContentToModerate represents content to be checked
type ContentToModerate struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	EventType   string `json:"event_type"`
}
