package reservation

import (
	"database/sql"
	"errors"

	"github.com/google/uuid"
	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/pkg/config"
)

const defaultHoldMinutes = 10

// Service handles event seat reservation business logic
type Service struct {
	repo *Repository
	cfg  *config.Config
}

// NewService creates a new reservation service
func NewService(db *sql.DB, cfg *config.Config) *Service {
	return &Service{
		repo: NewRepository(db),
		cfg:  cfg,
	}
}

// ReserveSeat reserves a seat for a user at an event
func (s *Service) ReserveSeat(userID, eventID uuid.UUID) (*models.EventRegistration, error) {
	return s.repo.ReserveSeat(userID, eventID, defaultHoldMinutes)
}

// CancelReservation cancels a user's reservation
func (s *Service) CancelReservation(userID, eventID uuid.UUID) error {
	return s.repo.CancelReservation(userID, eventID)
}

// GetMyReservations gets all reservations for the current user
func (s *Service) GetMyReservations(userID uuid.UUID) ([]EventReservationWithDetails, error) {
	return s.repo.GetUserReservations(userID)
}

// GetEventAvailability checks seat availability for a public event
func (s *Service) GetEventAvailability(eventID uuid.UUID) (*EventAvailability, error) {
	return s.repo.GetEventAvailability(eventID)
}

// CheckUserRegistration checks if a user is registered for an event
func (s *Service) CheckUserRegistration(userID, eventID uuid.UUID) (string, error) {
	var status string
	err := s.repo.db.QueryRow(`
		SELECT status FROM event_registrations WHERE user_id = $1 AND event_id = $2`,
		userID, eventID,
	).Scan(&status)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", nil
		}
		return "", err
	}
	return status, nil
}
