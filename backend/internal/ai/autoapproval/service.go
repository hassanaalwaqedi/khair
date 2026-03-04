package autoapproval

import (
	"database/sql"

	"github.com/google/uuid"

	aitrust "github.com/khair/backend/internal/ai/trust"
	"github.com/khair/backend/internal/models"
)

type OrganizerLookup interface {
	GetByID(id uuid.UUID) (*models.Organizer, error)
}

type Service struct {
	trustService  *aitrust.Service
	organizerRepo OrganizerLookup
}

func NewService(db *sql.DB, organizerRepo OrganizerLookup) *Service {
	return &Service{
		trustService:  aitrust.NewService(db),
		organizerRepo: organizerRepo,
	}
}

func (s *Service) Evaluate(organizerID uuid.UUID, scanResult *models.ScanResult) (*models.AutoApprovalResult, error) {
	organizer, err := s.organizerRepo.GetByID(organizerID)
	if err != nil {
		return &models.AutoApprovalResult{Approved: false, Reason: "organizer not found"}, nil
	}

	if organizer.Status != "approved" {
		return &models.AutoApprovalResult{Approved: false, Reason: "organizer not verified"}, nil
	}

	trustScore, err := s.trustService.GetByOrganizerID(organizerID)
	if err != nil {
		if err == sql.ErrNoRows {
			return &models.AutoApprovalResult{Approved: false, Reason: "no trust history"}, nil
		}
		return nil, err
	}

	if trustScore.TrustScore <= 75 {
		return &models.AutoApprovalResult{Approved: false, Reason: "trust score too low"}, nil
	}

	if scanResult.RiskScore >= 25 {
		return &models.AutoApprovalResult{Approved: false, Reason: "ai risk score too high"}, nil
	}

	if scanResult.ComplianceFlags != nil && scanResult.ComplianceFlags.HasAnyFlag() {
		return &models.AutoApprovalResult{Approved: false, Reason: "compliance flags triggered"}, nil
	}

	eventCount, err := s.trustService.GetEventCount(organizerID)
	if err != nil {
		return nil, err
	}
	if eventCount == 0 {
		return &models.AutoApprovalResult{Approved: false, Reason: "first event requires manual review"}, nil
	}

	return &models.AutoApprovalResult{Approved: true, Reason: "all conditions met"}, nil
}
