package trust

import (
	"database/sql"
	"math"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
)

type Service struct {
	repo *Repository
}

func NewService(db *sql.DB) *Service {
	return &Service{
		repo: NewRepository(db),
	}
}

func (s *Service) GetOrCreateTrustScore(userID, organizerID uuid.UUID) (*models.OrganizerTrustScoreV2, error) {
	return s.repo.GetOrCreate(userID, organizerID)
}

func (s *Service) GetByOrganizerID(organizerID uuid.UUID) (*models.OrganizerTrustScoreV2, error) {
	return s.repo.GetByOrganizerID(organizerID)
}

func (s *Service) OnEventApproved(organizerID uuid.UUID) error {
	ts, err := s.repo.GetByOrganizerID(organizerID)
	if err != nil {
		return err
	}
	ts.ApprovedEventsCount++
	ts.TrustScore = math.Min(100, ts.TrustScore+5)
	return s.repo.Update(ts)
}

func (s *Service) OnEventRejected(organizerID uuid.UUID) error {
	ts, err := s.repo.GetByOrganizerID(organizerID)
	if err != nil {
		return err
	}
	ts.RejectedEventsCount++
	ts.ViolationsCount++
	ts.TrustScore = math.Max(0, ts.TrustScore-10)
	return s.repo.Update(ts)
}

func (s *Service) OnHighRiskDetection(organizerID uuid.UUID) error {
	ts, err := s.repo.GetByOrganizerID(organizerID)
	if err != nil {
		return err
	}
	ts.HighRiskCount++
	ts.TrustScore = math.Max(0, ts.TrustScore-5)
	return s.repo.Update(ts)
}

func (s *Service) ShouldAutoReview(organizerID uuid.UUID) (bool, error) {
	ts, err := s.repo.GetByOrganizerID(organizerID)
	if err != nil {
		if err == sql.ErrNoRows {
			return false, nil
		}
		return false, err
	}
	return ts.TrustScore < 40, nil
}

func (s *Service) GetEventCount(organizerID uuid.UUID) (int, error) {
	return s.repo.GetEventCountByOrganizer(organizerID)
}
