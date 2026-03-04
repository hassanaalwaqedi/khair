package models

import (
	"time"

	"github.com/google/uuid"
)

type AIDecision string

const (
	AIDecisionSafe           AIDecision = "safe"
	AIDecisionReviewRequired AIDecision = "review_required"
	AIDecisionHighRisk       AIDecision = "high_risk"
)

type ModerationScan struct {
	ID              uuid.UUID              `json:"id" db:"id"`
	EventID         uuid.UUID              `json:"event_id" db:"event_id"`
	ScannedText     string                 `json:"scanned_text" db:"scanned_text"`
	AIRiskScore     float64                `json:"ai_risk_score" db:"ai_risk_score"`
	AIDecision      AIDecision             `json:"ai_decision" db:"ai_decision"`
	DetectedFlags   map[string]interface{} `json:"detected_flags" db:"detected_flags"`
	ComplianceFlags *ComplianceFlags       `json:"compliance_flags" db:"compliance_flags"`
	ScannedAt       time.Time              `json:"scanned_at" db:"scanned_at"`
	Provider        string                 `json:"provider" db:"provider"`
	CreatedAt       time.Time              `json:"created_at" db:"created_at"`
}

type ComplianceFlags struct {
	MusicDetected                bool `json:"music_detected"`
	InappropriateContentDetected bool `json:"inappropriate_content_detected"`
	GenderMixingDetected         bool `json:"gender_mixing_detected"`
	ExternalLinkSuspicious       bool `json:"external_link_suspicious"`
	ExtremismRisk                bool `json:"extremism_risk"`
	SectarianLanguage            bool `json:"sectarian_language"`
}

func (cf *ComplianceFlags) HasHighRiskFlag() bool {
	return cf.ExtremismRisk || cf.InappropriateContentDetected
}

func (cf *ComplianceFlags) HasAnyFlag() bool {
	return cf.MusicDetected || cf.InappropriateContentDetected ||
		cf.GenderMixingDetected || cf.ExternalLinkSuspicious ||
		cf.ExtremismRisk || cf.SectarianLanguage
}

func (cf *ComplianceFlags) FlagCount() int {
	count := 0
	if cf.MusicDetected {
		count++
	}
	if cf.InappropriateContentDetected {
		count++
	}
	if cf.GenderMixingDetected {
		count++
	}
	if cf.ExternalLinkSuspicious {
		count++
	}
	if cf.ExtremismRisk {
		count++
	}
	if cf.SectarianLanguage {
		count++
	}
	return count
}

type OrganizerTrustScoreV2 struct {
	ID                  uuid.UUID `json:"id" db:"id"`
	UserID              uuid.UUID `json:"user_id" db:"user_id"`
	OrganizerID         uuid.UUID `json:"organizer_id" db:"organizer_id"`
	TrustScore          float64   `json:"trust_score" db:"trust_score"`
	ViolationsCount     int       `json:"violations_count" db:"violations_count"`
	ApprovedEventsCount int       `json:"approved_events_count" db:"approved_events_count"`
	RejectedEventsCount int       `json:"rejected_events_count" db:"rejected_events_count"`
	HighRiskCount       int       `json:"high_risk_count" db:"high_risk_count"`
	LastUpdated         time.Time `json:"last_updated" db:"last_updated"`
	CreatedAt           time.Time `json:"created_at" db:"created_at"`
}

type AbuseLog struct {
	ID         uuid.UUID              `json:"id" db:"id"`
	UserID     uuid.UUID              `json:"user_id" db:"user_id"`
	ActionType string                 `json:"action_type" db:"action_type"`
	RiskScore  float64                `json:"risk_score" db:"risk_score"`
	Details    map[string]interface{} `json:"details" db:"details"`
	IPAddress  *string                `json:"ip_address,omitempty" db:"ip_address"`
	CreatedAt  time.Time              `json:"created_at" db:"created_at"`
}

type ModerationQueueItem struct {
	EventID         uuid.UUID        `json:"event_id"`
	Title           string           `json:"title"`
	OrganizerID     uuid.UUID        `json:"organizer_id"`
	OrganizerName   string           `json:"organizer_name"`
	Status          string           `json:"status"`
	AIRiskScore     *float64         `json:"ai_risk_score"`
	AIDecision      *string          `json:"ai_decision"`
	TrustScore      *float64         `json:"trust_score"`
	ComplianceFlags *ComplianceFlags `json:"compliance_flags"`
	ViolationsCount *int             `json:"violations_count"`
	CreatedAt       time.Time        `json:"created_at"`
}

type OrganizerRiskRanking struct {
	UserID              uuid.UUID `json:"user_id"`
	OrganizerID         uuid.UUID `json:"organizer_id"`
	OrganizerName       string    `json:"organizer_name"`
	TrustScore          float64   `json:"trust_score"`
	ViolationsCount     int       `json:"violations_count"`
	RejectedEventsCount int       `json:"rejected_events_count"`
	HighRiskCount       int       `json:"high_risk_count"`
	TotalEvents         int       `json:"total_events"`
}

type AutoApprovalResult struct {
	Approved bool   `json:"approved"`
	Reason   string `json:"reason"`
}

type ScanRequest struct {
	EventID     uuid.UUID `json:"event_id"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Tags        string    `json:"tags"`
	MeetingLink string    `json:"meeting_link"`
	OrganizerID uuid.UUID `json:"organizer_id"`
	UserID      uuid.UUID `json:"user_id"`
}

type ScanResult struct {
	RiskScore       float64          `json:"risk_score"`
	Decision        AIDecision       `json:"decision"`
	DetectedFlags   map[string]bool  `json:"detected_flags"`
	ComplianceFlags *ComplianceFlags `json:"compliance_flags"`
	EventStatus     string           `json:"event_status"`
	AutoApproved    bool             `json:"auto_approved"`
}
