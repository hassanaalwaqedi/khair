package score

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"

	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/internal/trust/audit"
)

// Service provides trust scoring functionality
type Service struct {
	db    *sqlx.DB
	audit *audit.Service
}

// NewService creates a new trust scoring service
func NewService(db *sqlx.DB, auditService *audit.Service) *Service {
	return &Service{
		db:    db,
		audit: auditService,
	}
}

// GetOrCreateTrustScore retrieves or creates a trust score for an organizer
func (s *Service) GetOrCreateTrustScore(ctx context.Context, organizerID uuid.UUID) (*models.OrganizerTrustScore, error) {
	// Try to get existing
	score, err := s.GetTrustScore(ctx, organizerID)
	if err == nil {
		return score, nil
	}

	// Create new
	query := `
		INSERT INTO organizer_trust_scores (organizer_id, trust_score)
		VALUES ($1, 100)
		ON CONFLICT (organizer_id) DO NOTHING
		RETURNING id, organizer_id, trust_score, approved_events_count, rejected_events_count,
			reports_received_count, event_cancellations_count, warnings_count,
			last_calculated_at, created_at, updated_at`

	var newScore models.OrganizerTrustScore
	err = s.db.GetContext(ctx, &newScore, query, organizerID)
	if err != nil {
		// Retry get in case of race condition
		return s.GetTrustScore(ctx, organizerID)
	}

	return &newScore, nil
}

// GetTrustScore retrieves trust score for an organizer
func (s *Service) GetTrustScore(ctx context.Context, organizerID uuid.UUID) (*models.OrganizerTrustScore, error) {
	query := `
		SELECT id, organizer_id, trust_score, approved_events_count, rejected_events_count,
			reports_received_count, event_cancellations_count, warnings_count,
			last_calculated_at, created_at, updated_at
		FROM organizer_trust_scores
		WHERE organizer_id = $1`

	var score models.OrganizerTrustScore
	err := s.db.GetContext(ctx, &score, query, organizerID)
	if err != nil {
		return nil, err
	}
	return &score, nil
}

// RecalculateScore recalculates trust score based on current metrics
func (s *Service) RecalculateScore(ctx context.Context, organizerID uuid.UUID) (*models.OrganizerTrustScore, error) {
	score, err := s.GetOrCreateTrustScore(ctx, organizerID)
	if err != nil {
		return nil, err
	}

	// Calculate new score
	newScore := score.CalculateTrustScore()
	score.TrustScore = newScore
	score.LastCalculatedAt = time.Now()

	// Update in database
	query := `
		UPDATE organizer_trust_scores
		SET trust_score = $1, last_calculated_at = $2
		WHERE organizer_id = $3`

	_, err = s.db.ExecContext(ctx, query, newScore, score.LastCalculatedAt, organizerID)
	if err != nil {
		return nil, err
	}

	return score, nil
}

// IncrementApprovedEvents increments approved events count
func (s *Service) IncrementApprovedEvents(ctx context.Context, organizerID uuid.UUID) error {
	_, err := s.GetOrCreateTrustScore(ctx, organizerID)
	if err != nil {
		return err
	}

	query := `UPDATE organizer_trust_scores SET approved_events_count = approved_events_count + 1 WHERE organizer_id = $1`
	_, err = s.db.ExecContext(ctx, query, organizerID)
	if err != nil {
		return err
	}

	_, err = s.RecalculateScore(ctx, organizerID)
	return err
}

// IncrementRejectedEvents increments rejected events count
func (s *Service) IncrementRejectedEvents(ctx context.Context, organizerID uuid.UUID) error {
	_, err := s.GetOrCreateTrustScore(ctx, organizerID)
	if err != nil {
		return err
	}

	query := `UPDATE organizer_trust_scores SET rejected_events_count = rejected_events_count + 1 WHERE organizer_id = $1`
	_, err = s.db.ExecContext(ctx, query, organizerID)
	if err != nil {
		return err
	}

	_, err = s.RecalculateScore(ctx, organizerID)
	return err
}

// IncrementReportsReceived increments reports received count
func (s *Service) IncrementReportsReceived(ctx context.Context, organizerID uuid.UUID) error {
	_, err := s.GetOrCreateTrustScore(ctx, organizerID)
	if err != nil {
		return err
	}

	query := `UPDATE organizer_trust_scores SET reports_received_count = reports_received_count + 1 WHERE organizer_id = $1`
	_, err = s.db.ExecContext(ctx, query, organizerID)
	if err != nil {
		return err
	}

	_, err = s.RecalculateScore(ctx, organizerID)
	return err
}

// IncrementWarnings increments warnings count
func (s *Service) IncrementWarnings(ctx context.Context, organizerID uuid.UUID) error {
	_, err := s.GetOrCreateTrustScore(ctx, organizerID)
	if err != nil {
		return err
	}

	query := `UPDATE organizer_trust_scores SET warnings_count = warnings_count + 1 WHERE organizer_id = $1`
	_, err = s.db.ExecContext(ctx, query, organizerID)
	if err != nil {
		return err
	}

	_, err = s.RecalculateScore(ctx, organizerID)
	return err
}

// IncrementCancellations increments event cancellations count
func (s *Service) IncrementCancellations(ctx context.Context, organizerID uuid.UUID) error {
	_, err := s.GetOrCreateTrustScore(ctx, organizerID)
	if err != nil {
		return err
	}

	query := `UPDATE organizer_trust_scores SET event_cancellations_count = event_cancellations_count + 1 WHERE organizer_id = $1`
	_, err = s.db.ExecContext(ctx, query, organizerID)
	if err != nil {
		return err
	}

	_, err = s.RecalculateScore(ctx, organizerID)
	return err
}

// GetOrganizerState retrieves the trust state for an organizer
func (s *Service) GetOrganizerState(ctx context.Context, organizerID uuid.UUID) (models.TrustState, error) {
	var state models.TrustState
	err := s.db.GetContext(ctx, &state,
		`SELECT trust_state FROM organizers WHERE id = $1`, organizerID)
	return state, err
}

// UpdateOrganizerState changes the trust state with audit logging
func (s *Service) UpdateOrganizerState(ctx context.Context, organizerID uuid.UUID, newState models.TrustState, reason string, adminID uuid.UUID) error {
	// Get current state
	oldState, err := s.GetOrganizerState(ctx, organizerID)
	if err != nil {
		return err
	}

	// Update state
	query := `UPDATE organizers SET trust_state = $1 WHERE id = $2`
	_, err = s.db.ExecContext(ctx, query, newState, organizerID)
	if err != nil {
		return err
	}

	// Determine action type
	var action models.AuditAction
	switch newState {
	case models.TrustStateWarning:
		action = models.AuditActionOrganizerWarned
	case models.TrustStateSuspended:
		action = models.AuditActionOrganizerSuspended
	case models.TrustStateBanned:
		action = models.AuditActionOrganizerBanned
	case models.TrustStateActive:
		action = models.AuditActionOrganizerReinstated
	default:
		action = models.AuditActionOrganizerStateChange
	}

	// If it's a warning, increment warnings count
	if newState == models.TrustStateWarning {
		s.IncrementWarnings(ctx, organizerID)
	}

	// Audit log the change
	return s.audit.LogAdminAction(ctx, adminID, action,
		"organizer", organizerID, reason,
		map[string]string{"trust_state": string(oldState)},
		map[string]string{"trust_state": string(newState)},
		"", "")
}

// WarnOrganizer issues a warning to an organizer
func (s *Service) WarnOrganizer(ctx context.Context, organizerID uuid.UUID, reason string, adminID uuid.UUID) error {
	return s.UpdateOrganizerState(ctx, organizerID, models.TrustStateWarning, reason, adminID)
}

// SuspendOrganizer suspends an organizer
func (s *Service) SuspendOrganizer(ctx context.Context, organizerID uuid.UUID, reason string, adminID uuid.UUID) error {
	return s.UpdateOrganizerState(ctx, organizerID, models.TrustStateSuspended, reason, adminID)
}

// BanOrganizer bans an organizer
func (s *Service) BanOrganizer(ctx context.Context, organizerID uuid.UUID, reason string, adminID uuid.UUID) error {
	return s.UpdateOrganizerState(ctx, organizerID, models.TrustStateBanned, reason, adminID)
}

// ReinstateOrganizer reinstates an organizer to active status
func (s *Service) ReinstateOrganizer(ctx context.Context, organizerID uuid.UUID, reason string, adminID uuid.UUID) error {
	return s.UpdateOrganizerState(ctx, organizerID, models.TrustStateActive, reason, adminID)
}

// GetTrustHistory retrieves state change history for an organizer
func (s *Service) GetTrustHistory(ctx context.Context, organizerID uuid.UUID) ([]models.AuditLog, error) {
	return s.audit.GetByTarget(ctx, "organizer", organizerID)
}
