package event

import (
	"database/sql"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
)

type ModerationScanner interface {
	ScanAndModerate(req *models.ScanRequest) (*models.ScanResult, error)
}

type Service struct {
	repo          *Repository
	organizerRepo OrganizerRepository
	moderation    ModerationScanner
}

// OrganizerRepository interface for organizer operations
type OrganizerRepository interface {
	GetByID(id uuid.UUID) (*models.Organizer, error)
	GetByUserID(userID uuid.UUID) (*models.Organizer, error)
}

func NewService(db *sql.DB, organizerRepo OrganizerRepository) *Service {
	return &Service{
		repo:          NewRepository(db),
		organizerRepo: organizerRepo,
	}
}

func (s *Service) SetModeration(m ModerationScanner) {
	s.moderation = m
}

// CreateEventRequest represents a request to create an event
type CreateEventRequest struct {
	Title       string   `json:"title" binding:"required"`
	Description *string  `json:"description"`
	EventType   string   `json:"event_type" binding:"required"`
	Language    *string  `json:"language"`
	Country     *string  `json:"country"`
	City        *string  `json:"city"`
	Address     *string  `json:"address"`
	Latitude    *float64 `json:"latitude"`
	Longitude   *float64 `json:"longitude"`
	StartDate   string   `json:"start_date" binding:"required"`
	EndDate     *string  `json:"end_date"`
	ImageURL    *string  `json:"image_url"`
}

// UpdateEventRequest represents a request to update an event
type UpdateEventRequest struct {
	Title       *string  `json:"title"`
	Description *string  `json:"description"`
	EventType   *string  `json:"event_type"`
	Language    *string  `json:"language"`
	Country     *string  `json:"country"`
	City        *string  `json:"city"`
	Address     *string  `json:"address"`
	Latitude    *float64 `json:"latitude"`
	Longitude   *float64 `json:"longitude"`
	StartDate   *string  `json:"start_date"`
	EndDate     *string  `json:"end_date"`
	ImageURL    *string  `json:"image_url"`
}

// Create creates a new event
func (s *Service) Create(userID uuid.UUID, req *CreateEventRequest) (*models.Event, error) {
	// Get organizer profile
	organizer, err := s.organizerRepo.GetByUserID(userID)
	if err != nil {
		return nil, errors.New("organizer profile not found")
	}

	// Check if organizer is approved
	if organizer.Status != "approved" {
		return nil, errors.New("your organization is not yet approved")
	}

	// Parse dates
	startDate, err := time.Parse(time.RFC3339, req.StartDate)
	if err != nil {
		return nil, errors.New("invalid start date format, use RFC3339")
	}

	var endDate *time.Time
	if req.EndDate != nil {
		ed, err := time.Parse(time.RFC3339, *req.EndDate)
		if err != nil {
			return nil, errors.New("invalid end date format, use RFC3339")
		}
		endDate = &ed
	}

	event := &models.Event{
		ID:          uuid.New(),
		OrganizerID: organizer.ID,
		Title:       req.Title,
		Description: req.Description,
		EventType:   req.EventType,
		Language:    req.Language,
		Country:     req.Country,
		City:        req.City,
		Address:     req.Address,
		Latitude:    req.Latitude,
		Longitude:   req.Longitude,
		StartDate:   startDate,
		EndDate:     endDate,
		ImageURL:    req.ImageURL,
		Status:      "draft",
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	if err := s.repo.Create(event); err != nil {
		return nil, errors.New("failed to create event")
	}

	if s.moderation != nil {
		desc := ""
		if req.Description != nil {
			desc = *req.Description
		}
		scanReq := &models.ScanRequest{
			EventID:     event.ID,
			Title:       event.Title,
			Description: desc,
			OrganizerID: organizer.ID,
			UserID:      userID,
		}
		if result, err := s.moderation.ScanAndModerate(scanReq); err == nil {
			event.Status = result.EventStatus
		}
	}

	return event, nil
}

// GetByID retrieves an event by ID
func (s *Service) GetByID(id uuid.UUID) (*models.EventWithOrganizer, error) {
	return s.repo.GetByID(id)
}

// List retrieves events with filters
func (s *Service) List(filter *EventFilter) ([]models.EventWithOrganizer, int64, error) {
	return s.repo.List(filter)
}

// ListPublic retrieves approved events for public viewing
func (s *Service) ListPublic(filter *EventFilter) ([]models.EventWithOrganizer, int64, error) {
	status := "approved"
	filter.Status = &status
	return s.repo.List(filter)
}

// Update updates an event
func (s *Service) Update(userID uuid.UUID, eventID uuid.UUID, req *UpdateEventRequest) (*models.Event, error) {
	// Get organizer profile
	organizer, err := s.organizerRepo.GetByUserID(userID)
	if err != nil {
		return nil, errors.New("organizer profile not found")
	}

	// Get existing event
	existingEvent, err := s.repo.GetByID(eventID)
	if err != nil {
		return nil, errors.New("event not found")
	}

	// Check ownership
	if existingEvent.OrganizerID != organizer.ID {
		return nil, errors.New("you don't have permission to update this event")
	}

	// Update fields
	event := &existingEvent.Event
	if req.Title != nil {
		event.Title = *req.Title
	}
	if req.Description != nil {
		event.Description = req.Description
	}
	if req.EventType != nil {
		event.EventType = *req.EventType
	}
	if req.Language != nil {
		event.Language = req.Language
	}
	if req.Country != nil {
		event.Country = req.Country
	}
	if req.City != nil {
		event.City = req.City
	}
	if req.Address != nil {
		event.Address = req.Address
	}
	if req.Latitude != nil {
		event.Latitude = req.Latitude
	}
	if req.Longitude != nil {
		event.Longitude = req.Longitude
	}
	if req.StartDate != nil {
		startDate, err := time.Parse(time.RFC3339, *req.StartDate)
		if err != nil {
			return nil, errors.New("invalid start date format")
		}
		event.StartDate = startDate
	}
	if req.EndDate != nil {
		endDate, err := time.Parse(time.RFC3339, *req.EndDate)
		if err != nil {
			return nil, errors.New("invalid end date format")
		}
		event.EndDate = &endDate
	}
	if req.ImageURL != nil {
		event.ImageURL = req.ImageURL
	}

	if err := s.repo.Update(event); err != nil {
		return nil, errors.New("failed to update event")
	}

	if s.moderation != nil {
		desc := ""
		if event.Description != nil {
			desc = *event.Description
		}
		scanReq := &models.ScanRequest{
			EventID:     event.ID,
			Title:       event.Title,
			Description: desc,
			OrganizerID: existingEvent.OrganizerID,
			UserID:      userID,
		}
		if result, err := s.moderation.ScanAndModerate(scanReq); err == nil {
			event.Status = result.EventStatus
		}
	}

	return event, nil
}

// Delete deletes an event
func (s *Service) Delete(userID uuid.UUID, eventID uuid.UUID) error {
	// Get organizer profile
	organizer, err := s.organizerRepo.GetByUserID(userID)
	if err != nil {
		return errors.New("organizer profile not found")
	}

	// Get existing event
	existingEvent, err := s.repo.GetByID(eventID)
	if err != nil {
		return errors.New("event not found")
	}

	// Check ownership
	if existingEvent.OrganizerID != organizer.ID {
		return errors.New("you don't have permission to delete this event")
	}

	return s.repo.Delete(eventID)
}

// SubmitForReview changes event status to pending
func (s *Service) SubmitForReview(userID uuid.UUID, eventID uuid.UUID) (*models.Event, error) {
	// Get organizer profile
	organizer, err := s.organizerRepo.GetByUserID(userID)
	if err != nil {
		return nil, errors.New("organizer profile not found")
	}

	// Get existing event
	existingEvent, err := s.repo.GetByID(eventID)
	if err != nil {
		return nil, errors.New("event not found")
	}

	// Check ownership
	if existingEvent.OrganizerID != organizer.ID {
		return nil, errors.New("you don't have permission to submit this event")
	}

	// Update status
	if err := s.repo.UpdateStatus(eventID, "pending", nil); err != nil {
		return nil, errors.New("failed to submit event for review")
	}

	existingEvent.Status = "pending"
	return &existingEvent.Event, nil
}

// GetMyEvents retrieves events for the current organizer
func (s *Service) GetMyEvents(userID uuid.UUID) ([]models.Event, error) {
	organizer, err := s.organizerRepo.GetByUserID(userID)
	if err != nil {
		return nil, errors.New("organizer profile not found")
	}

	return s.repo.ListByOrganizerID(organizer.ID)
}
