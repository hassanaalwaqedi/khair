package models

import (
	"time"

	"github.com/google/uuid"
)

// TrustState defines organizer trust levels
type TrustState string

const (
	TrustStateActive    TrustState = "active"
	TrustStateWarning   TrustState = "warning"
	TrustStateSuspended TrustState = "suspended"
	TrustStateBanned    TrustState = "banned"
)

// OrganizerTrustScore holds trust metrics for an organizer
type OrganizerTrustScore struct {
	ID                      uuid.UUID  `json:"id" db:"id"`
	OrganizerID             uuid.UUID  `json:"organizer_id" db:"organizer_id"`
	TrustScore              int        `json:"trust_score" db:"trust_score"`
	ApprovedEventsCount     int        `json:"approved_events_count" db:"approved_events_count"`
	RejectedEventsCount     int        `json:"rejected_events_count" db:"rejected_events_count"`
	ReportsReceivedCount    int        `json:"reports_received_count" db:"reports_received_count"`
	EventCancellationsCount int        `json:"event_cancellations_count" db:"event_cancellations_count"`
	WarningsCount           int        `json:"warnings_count" db:"warnings_count"`
	LastCalculatedAt        time.Time  `json:"last_calculated_at" db:"last_calculated_at"`
	CreatedAt               time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt               time.Time  `json:"updated_at" db:"updated_at"`
}

// TrustStateChangeRequest for admin state transitions
type TrustStateChangeRequest struct {
	NewState TrustState `json:"new_state" binding:"required,oneof=active warning suspended banned"`
	Reason   string     `json:"reason" binding:"required"`
}

// CalculateTrustScore computes trust score based on metrics
func (ts *OrganizerTrustScore) CalculateTrustScore() int {
	// Start with base score of 100
	score := 100

	// Positive factors
	score += ts.ApprovedEventsCount * 2 // +2 per approved event

	// Negative factors
	score -= ts.RejectedEventsCount * 10       // -10 per rejected event
	score -= ts.ReportsReceivedCount * 5       // -5 per report
	score -= ts.EventCancellationsCount * 3    // -3 per cancellation
	score -= ts.WarningsCount * 15             // -15 per warning

	// Clamp between 0 and 100
	if score < 0 {
		score = 0
	}
	if score > 100 {
		score = 100
	}

	return score
}

// SuggestedState returns suggested trust state based on score
func (ts *OrganizerTrustScore) SuggestedState() TrustState {
	switch {
	case ts.TrustScore >= 70:
		return TrustStateActive
	case ts.TrustScore >= 40:
		return TrustStateWarning
	case ts.TrustScore >= 20:
		return TrustStateSuspended
	default:
		return TrustStateBanned
	}
}
