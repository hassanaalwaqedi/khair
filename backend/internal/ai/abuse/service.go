package abuse

import (
	"database/sql"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
)

const (
	MaxEventsPerDay      = 10
	MaxDescriptionLength = 10000
	HighRiskThreshold    = 70.0
	SuspensionThreshold  = 5
	SuspensionWindow     = 24 * time.Hour
)

type Service struct {
	repo *Repository
}

func NewService(db *sql.DB) *Service {
	return &Service{
		repo: NewRepository(db),
	}
}

func (s *Service) CheckRateLimit(userID uuid.UUID) error {
	count, err := s.repo.CountEventsByUserToday(userID)
	if err != nil {
		return err
	}
	if count >= MaxEventsPerDay {
		return errors.New("daily event creation limit reached")
	}
	return nil
}

func (s *Service) ValidateDescription(description string) error {
	if len(description) > MaxDescriptionLength {
		return errors.New("description exceeds maximum length")
	}
	return nil
}

func (s *Service) LogAbuse(userID uuid.UUID, actionType string, riskScore float64, details map[string]interface{}, ip *string) error {
	log := &models.AbuseLog{
		UserID:     userID,
		ActionType: actionType,
		RiskScore:  riskScore,
		Details:    details,
		IPAddress:  ip,
	}
	return s.repo.Create(log)
}

func (s *Service) ShouldSuspend(userID uuid.UUID) (bool, error) {
	since := time.Now().Add(-SuspensionWindow)
	count, err := s.repo.CountHighRiskByUserSince(userID, since, HighRiskThreshold)
	if err != nil {
		return false, err
	}
	return count >= SuspensionThreshold, nil
}

func (s *Service) GetAbuseCount(userID uuid.UUID, window time.Duration) (int, error) {
	since := time.Now().Add(-window)
	return s.repo.CountByUserSince(userID, since)
}
