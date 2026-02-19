package models

import (
	"time"

	"github.com/google/uuid"
)

// ReportTargetType defines what can be reported
type ReportTargetType string

const (
	ReportTargetEvent     ReportTargetType = "event"
	ReportTargetOrganizer ReportTargetType = "organizer"
)

// ReporterType defines who is making the report
type ReporterType string

const (
	ReporterGuest  ReporterType = "guest"
	ReporterUser   ReporterType = "user"
	ReporterSystem ReporterType = "system"
)

// ReasonCategory defines report reason categories
type ReasonCategory string

const (
	ReasonPoliticalContent  ReasonCategory = "political_content"
	ReasonHateSpeech        ReasonCategory = "hate_speech"
	ReasonMisleadingCharity ReasonCategory = "misleading_charity"
	ReasonSpam              ReasonCategory = "spam"
	ReasonInappropriate     ReasonCategory = "inappropriate_content"
	ReasonFakeEvent         ReasonCategory = "fake_event"
	ReasonOther             ReasonCategory = "other"
)

// ReportStatus defines report workflow states
type ReportStatus string

const (
	ReportStatusPending   ReportStatus = "pending"
	ReportStatusReviewing ReportStatus = "reviewing"
	ReportStatusResolved  ReportStatus = "resolved"
	ReportStatusDismissed ReportStatus = "dismissed"
)

// Report represents a report against an event or organizer
type Report struct {
	ID               uuid.UUID        `json:"id" db:"id"`
	TargetType       ReportTargetType `json:"target_type" db:"target_type"`
	TargetID         uuid.UUID        `json:"target_id" db:"target_id"`
	ReporterType     ReporterType     `json:"reporter_type" db:"reporter_type"`
	ReporterID       *uuid.UUID       `json:"reporter_id,omitempty" db:"reporter_id"`
	ReporterIP       *string          `json:"reporter_ip,omitempty" db:"reporter_ip"`
	ReasonCategory   ReasonCategory   `json:"reason_category" db:"reason_category"`
	Description      *string          `json:"description,omitempty" db:"description"`
	Status           ReportStatus     `json:"status" db:"status"`
	ResolutionAction *string          `json:"resolution_action,omitempty" db:"resolution_action"`
	ResolutionNotes  *string          `json:"resolution_notes,omitempty" db:"resolution_notes"`
	ResolvedBy       *uuid.UUID       `json:"resolved_by,omitempty" db:"resolved_by"`
	ResolvedAt       *time.Time       `json:"resolved_at,omitempty" db:"resolved_at"`
	CreatedAt        time.Time        `json:"created_at" db:"created_at"`
}

// CreateReportRequest for submitting a report
type CreateReportRequest struct {
	TargetType     ReportTargetType `json:"target_type" binding:"required,oneof=event organizer"`
	TargetID       uuid.UUID        `json:"target_id" binding:"required"`
	ReasonCategory ReasonCategory   `json:"reason_category" binding:"required"`
	Description    *string          `json:"description"`
}

// ResolveReportRequest for admin resolution
type ResolveReportRequest struct {
	Action string  `json:"action" binding:"required,oneof=approve reject dismiss warn"`
	Notes  *string `json:"notes"`
}
