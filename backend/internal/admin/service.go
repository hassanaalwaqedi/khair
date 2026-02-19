package admin

import (
	"database/sql"
	"errors"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
)

// Service handles admin business logic
type Service struct {
	db            *sql.DB
	organizerRepo OrganizerRepository
	eventRepo     EventRepository
}

// OrganizerRepository interface for organizer operations
type OrganizerRepository interface {
	GetByID(id uuid.UUID) (*models.Organizer, error)
	UpdateStatus(id uuid.UUID, status string, rejectionReason *string) error
	ListPending() ([]models.Organizer, error)
	ListAll() ([]models.Organizer, error)
}

// EventRepository interface for event operations
type EventRepository interface {
	GetByID(id uuid.UUID) (*models.EventWithOrganizer, error)
	UpdateStatus(id uuid.UUID, status string, rejectionReason *string) error
	ListPending() ([]models.EventWithOrganizer, error)
}

// NewService creates a new admin service
func NewService(db *sql.DB, organizerRepo OrganizerRepository, eventRepo EventRepository) *Service {
	return &Service{
		db:            db,
		organizerRepo: organizerRepo,
		eventRepo:     eventRepo,
	}
}

// StatusUpdateRequest represents a status update request
type StatusUpdateRequest struct {
	Status          string  `json:"status" binding:"required,oneof=approved rejected"`
	RejectionReason *string `json:"rejection_reason"`
}

// ListPendingOrganizers lists organizers pending approval
func (s *Service) ListPendingOrganizers() ([]models.Organizer, error) {
	return s.organizerRepo.ListPending()
}

// ListAllOrganizers lists all organizers
func (s *Service) ListAllOrganizers() ([]models.Organizer, error) {
	return s.organizerRepo.ListAll()
}

// GetOrganizer retrieves an organizer by ID
func (s *Service) GetOrganizer(id uuid.UUID) (*models.Organizer, error) {
	return s.organizerRepo.GetByID(id)
}

// UpdateOrganizerStatus updates the status of an organizer
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

// ListPendingEvents lists events pending approval
func (s *Service) ListPendingEvents() ([]models.EventWithOrganizer, error) {
	return s.eventRepo.ListPending()
}

// GetEvent retrieves an event by ID
func (s *Service) GetEvent(id uuid.UUID) (*models.EventWithOrganizer, error) {
	return s.eventRepo.GetByID(id)
}

// UpdateEventStatus updates the status of an event
func (s *Service) UpdateEventStatus(id uuid.UUID, req *StatusUpdateRequest) (*models.EventWithOrganizer, error) {
	event, err := s.eventRepo.GetByID(id)
	if err != nil {
		return nil, errors.New("event not found")
	}

	if req.Status == "rejected" && (req.RejectionReason == nil || *req.RejectionReason == "") {
		return nil, errors.New("rejection reason is required when rejecting")
	}

	if err := s.eventRepo.UpdateStatus(id, req.Status, req.RejectionReason); err != nil {
		return nil, errors.New("failed to update event status")
	}

	event.Status = req.Status
	event.RejectionReason = req.RejectionReason
	return event, nil
}
