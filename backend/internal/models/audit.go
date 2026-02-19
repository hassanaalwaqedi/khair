package models

import (
	"time"

	"github.com/google/uuid"
)

// ActorType defines who performed the action
type ActorType string

const (
	ActorAdmin  ActorType = "admin"
	ActorSystem ActorType = "system"
)

// AuditAction defines auditable actions
type AuditAction string

const (
	// Organizer actions
	AuditActionOrganizerApproved    AuditAction = "organizer_approved"
	AuditActionOrganizerRejected    AuditAction = "organizer_rejected"
	AuditActionOrganizerWarned      AuditAction = "organizer_warned"
	AuditActionOrganizerSuspended   AuditAction = "organizer_suspended"
	AuditActionOrganizerBanned      AuditAction = "organizer_banned"
	AuditActionOrganizerReinstated  AuditAction = "organizer_reinstated"
	AuditActionOrganizerStateChange AuditAction = "organizer_state_change"

	// Event actions
	AuditActionEventApproved AuditAction = "event_approved"
	AuditActionEventRejected AuditAction = "event_rejected"
	AuditActionEventFlagged  AuditAction = "event_flagged"
	AuditActionEventRemoved  AuditAction = "event_removed"

	// Report actions
	AuditActionReportResolved  AuditAction = "report_resolved"
	AuditActionReportDismissed AuditAction = "report_dismissed"

	// Moderation actions
	AuditActionKeywordAdded   AuditAction = "keyword_added"
	AuditActionKeywordRemoved AuditAction = "keyword_removed"
)

// AuditLog represents an immutable audit log entry
type AuditLog struct {
	ID         uuid.UUID   `json:"id" db:"id"`
	ActorType  ActorType   `json:"actor_type" db:"actor_type"`
	ActorID    *uuid.UUID  `json:"actor_id,omitempty" db:"actor_id"`
	Action     AuditAction `json:"action" db:"action"`
	TargetType string      `json:"target_type" db:"target_type"`
	TargetID   uuid.UUID   `json:"target_id" db:"target_id"`
	OldValue   *string     `json:"old_value,omitempty" db:"old_value"`
	NewValue   *string     `json:"new_value,omitempty" db:"new_value"`
	Reason     *string     `json:"reason,omitempty" db:"reason"`
	IPAddress  *string     `json:"ip_address,omitempty" db:"ip_address"`
	UserAgent  *string     `json:"user_agent,omitempty" db:"user_agent"`
	CreatedAt  time.Time   `json:"created_at" db:"created_at"`
}

// AuditLogQuery for filtering audit logs
type AuditLogQuery struct {
	ActorType  *ActorType   `form:"actor_type"`
	ActorID    *uuid.UUID   `form:"actor_id"`
	Action     *AuditAction `form:"action"`
	TargetType *string      `form:"target_type"`
	TargetID   *uuid.UUID   `form:"target_id"`
	StartDate  *time.Time   `form:"start_date"`
	EndDate    *time.Time   `form:"end_date"`
	Limit      int          `form:"limit"`
	Offset     int          `form:"offset"`
}
