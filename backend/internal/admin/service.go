package admin

import (
	"database/sql"
	"errors"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/internal/rbac"
)

type Service struct {
	db            *sql.DB
	organizerRepo OrganizerRepository
	eventRepo     EventRepository
	rbacService   *rbac.Service
}

type OrganizerRepository interface {
	GetByID(id uuid.UUID) (*models.Organizer, error)
	UpdateStatus(id uuid.UUID, status string, rejectionReason *string) error
	ListPending() ([]models.Organizer, error)
	ListAll() ([]models.Organizer, error)
}

type EventRepository interface {
	GetByID(id uuid.UUID) (*models.EventWithOrganizer, error)
	UpdateStatus(id uuid.UUID, status string, rejectionReason *string) error
	UpdateStatusWithReviewer(id uuid.UUID, status string, rejectionReason *string, reviewedBy uuid.UUID) error
	ListPending() ([]models.EventWithOrganizer, error)
}

type StatusUpdateRequest struct {
	Status          string  `json:"status" binding:"required,oneof=approved rejected needs_revision published"`
	RejectionReason *string `json:"rejection_reason"`
}

func NewService(db *sql.DB, organizerRepo OrganizerRepository, eventRepo EventRepository, rbacService *rbac.Service) *Service {
	return &Service{
		db:            db,
		organizerRepo: organizerRepo,
		eventRepo:     eventRepo,
		rbacService:   rbacService,
	}
}

func (s *Service) ListPendingOrganizers() ([]models.Organizer, error) {
	return s.organizerRepo.ListPending()
}

func (s *Service) ListAllOrganizers() ([]models.Organizer, error) {
	return s.organizerRepo.ListAll()
}

func (s *Service) GetOrganizer(id uuid.UUID) (*models.Organizer, error) {
	return s.organizerRepo.GetByID(id)
}

func (s *Service) UpdateOrganizerStatus(id uuid.UUID, req *StatusUpdateRequest) (*models.Organizer, error) {
	org, err := s.organizerRepo.GetByID(id)
	if err != nil {
		return nil, errors.New("organizer not found")
	}

	if req.Status == "rejected" && (req.RejectionReason == nil || *req.RejectionReason == "") {
		return nil, errors.New("rejection reason is required when rejecting")
	}

	if err := s.organizerRepo.UpdateStatus(id, req.Status, req.RejectionReason); err != nil {
		return nil, errors.New("failed to update organizer status")
	}

	org.Status = req.Status
	org.RejectionReason = req.RejectionReason
	return org, nil
}

func (s *Service) ListPendingEvents() ([]models.EventWithOrganizer, error) {
	return s.eventRepo.ListPending()
}

func (s *Service) GetEvent(id uuid.UUID) (*models.EventWithOrganizer, error) {
	return s.eventRepo.GetByID(id)
}

func (s *Service) UpdateEventStatus(id uuid.UUID, req *StatusUpdateRequest, reviewerID uuid.UUID) (*models.EventWithOrganizer, error) {
	event, err := s.eventRepo.GetByID(id)
	if err != nil {
		return nil, errors.New("event not found")
	}

	if req.Status == "rejected" && (req.RejectionReason == nil || *req.RejectionReason == "") {
		return nil, errors.New("rejection reason is required when rejecting")
	}

	if req.Status == "needs_revision" && (req.RejectionReason == nil || *req.RejectionReason == "") {
		return nil, errors.New("revision notes are required")
	}

	if err := s.eventRepo.UpdateStatusWithReviewer(id, req.Status, req.RejectionReason, reviewerID); err != nil {
		return nil, errors.New("failed to update event status")
	}

	event.Status = req.Status
	event.RejectionReason = req.RejectionReason
	return event, nil
}

// SuspendUser suspends a user account and revokes all their refresh tokens
func (s *Service) SuspendUser(userID uuid.UUID, reason string, adminID uuid.UUID) error {
	_, err := s.db.Exec(`
		UPDATE users SET status = 'suspended', suspended_at = NOW(),
		suspended_reason = $1, suspended_by = $2, updated_at = NOW()
		WHERE id = $3
	`, reason, adminID, userID)
	if err != nil {
		return errors.New("failed to suspend user")
	}

	// Revoke all refresh tokens
	_, _ = s.db.Exec(`UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = $1 AND revoked_at IS NULL`, userID)

	return nil
}

// UnsuspendUser removes a user's suspension
func (s *Service) UnsuspendUser(userID uuid.UUID) error {
	_, err := s.db.Exec(`
		UPDATE users SET status = 'active', suspended_at = NULL,
		suspended_reason = NULL, suspended_by = NULL, updated_at = NOW()
		WHERE id = $1
	`, userID)
	if err != nil {
		return errors.New("failed to unsuspend user")
	}
	return nil
}
