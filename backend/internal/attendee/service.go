package attendee

import (
	"database/sql"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
)

// Service handles attendee business logic
type Service struct {
	repo *Repository
}

// NewService creates a new attendee service
func NewService(db *sql.DB) *Service {
	return &Service{repo: NewRepository(db)}
}

// ListByEvent returns paginated attendees for an event
func (s *Service) ListByEvent(eventID uuid.UUID, search, status *string, page, pageSize int) ([]models.AttendeeInfo, int64, error) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}
	return s.repo.ListByEvent(eventID, search, status, page, pageSize)
}

// MarkAttendance toggles attendance for a registration
func (s *Service) MarkAttendance(regID uuid.UUID, attended bool) error {
	return s.repo.MarkAttendance(regID, attended)
}

// RemoveAttendee cancels a registration
func (s *Service) RemoveAttendee(regID uuid.UUID) error {
	return s.repo.RemoveAttendee(regID)
}

// ExportCSV generates CSV data for all attendees
func (s *Service) ExportCSV(eventID uuid.UUID) ([]byte, error) {
	return s.repo.ExportCSV(eventID)
}

// VerifyEventOwnership checks that the event belongs to the org
func (s *Service) VerifyEventOwnership(eventID, orgID uuid.UUID) error {
	evOrgID, err := s.repo.GetEventOrgID(eventID)
	if err != nil {
		return err
	}
	if evOrgID != orgID {
		return sql.ErrNoRows
	}
	return nil
}
