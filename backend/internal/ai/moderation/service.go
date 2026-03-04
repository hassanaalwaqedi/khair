package moderation

import (
	"database/sql"
	"encoding/json"
	"time"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/ai/abuse"
	"github.com/khair/backend/internal/ai/autoapproval"
	"github.com/khair/backend/internal/ai/security"
	aitrust "github.com/khair/backend/internal/ai/trust"
	"github.com/khair/backend/internal/models"
)

type EventRepo interface {
	UpdateStatus(id uuid.UUID, status string, rejectionReason *string) error
}

type OrganizerRepo interface {
	GetByID(id uuid.UUID) (*models.Organizer, error)
	GetByUserID(userID uuid.UUID) (*models.Organizer, error)
}

type ModerationService struct {
	scanner       *Scanner
	repo          *Repository
	trustService  *aitrust.Service
	autoApproval  *autoapproval.Service
	abuseService  *abuse.Service
	eventRepo     EventRepo
	organizerRepo OrganizerRepo
	encryptionKey []byte
}

func NewModerationService(
	db *sql.DB,
	provider AIProvider,
	eventRepo EventRepo,
	organizerRepo OrganizerRepo,
	encryptionKey string,
) *ModerationService {
	key := deriveKey(encryptionKey)
	autoApprovalSvc := autoapproval.NewService(db, organizerRepo)
	return &ModerationService{
		scanner:       NewScanner(provider),
		repo:          NewRepository(db),
		trustService:  aitrust.NewService(db),
		autoApproval:  autoApprovalSvc,
		abuseService:  abuse.NewService(db),
		eventRepo:     eventRepo,
		organizerRepo: organizerRepo,
		encryptionKey: key,
	}
}

func (s *ModerationService) ScanAndModerate(req *models.ScanRequest) (*models.ScanResult, error) {
	if err := s.abuseService.CheckRateLimit(req.UserID); err != nil {
		return nil, err
	}

	if err := s.abuseService.ValidateDescription(req.Description); err != nil {
		return nil, err
	}

	req.Title = security.SanitizeInput(req.Title)
	req.Description = security.SanitizeInput(req.Description)
	req.Tags = security.SanitizeInput(req.Tags)

	if req.MeetingLink != "" {
		if !security.ValidateURL(req.MeetingLink) {
			req.MeetingLink = ""
		}
	}

	scanResult, err := s.scanner.ScanEvent(req)
	if err != nil {
		return nil, err
	}

	flagsMap := make(map[string]interface{})
	for k, v := range scanResult.DetectedFlags {
		flagsMap[k] = v
	}

	scan := &models.ModerationScan{
		EventID:         req.EventID,
		ScannedText:     req.Title + " " + req.Description,
		AIRiskScore:     scanResult.RiskScore,
		AIDecision:      scanResult.Decision,
		DetectedFlags:   flagsMap,
		ComplianceFlags: scanResult.ComplianceFlags,
		Provider:        "local",
	}
	if err := s.repo.Create(scan); err != nil {
		return nil, err
	}

	if err := s.repo.UpdateEventAIData(req.EventID, scanResult.RiskScore, string(scanResult.Decision), scanResult.ComplianceFlags); err != nil {
		return nil, err
	}

	organizer, _ := s.organizerRepo.GetByID(req.OrganizerID)
	if organizer != nil {
		if _, err := s.trustService.GetOrCreateTrustScore(organizer.UserID, organizer.ID); err == nil {
			if scanResult.Decision == models.AIDecisionHighRisk {
				s.trustService.OnHighRiskDetection(req.OrganizerID)

				s.abuseService.LogAbuse(req.UserID, "high_risk_event", scanResult.RiskScore,
					map[string]interface{}{"event_id": req.EventID.String()}, nil)
			}
		}
	}

	if scanResult.Decision == models.AIDecisionHighRisk || (scanResult.ComplianceFlags != nil && scanResult.ComplianceFlags.HasHighRiskFlag()) {
		scanResult.EventStatus = "under_review"
		s.eventRepo.UpdateStatus(req.EventID, "under_review", nil)
		return scanResult, nil
	}

	shouldAutoReview, _ := s.trustService.ShouldAutoReview(req.OrganizerID)
	if shouldAutoReview {
		scanResult.EventStatus = "under_review"
		s.eventRepo.UpdateStatus(req.EventID, "under_review", nil)
		return scanResult, nil
	}

	approvalResult, err := s.autoApproval.Evaluate(req.OrganizerID, scanResult)
	if err == nil && approvalResult.Approved {
		scanResult.AutoApproved = true
		scanResult.EventStatus = "approved"
		s.eventRepo.UpdateStatus(req.EventID, "approved", nil)
		return scanResult, nil
	}

	scanResult.EventStatus = "pending"
	return scanResult, nil
}

func (s *ModerationService) OnEventStatusChange(eventID, organizerID uuid.UUID, newStatus string) error {
	switch newStatus {
	case "approved":
		return s.trustService.OnEventApproved(organizerID)
	case "rejected":
		return s.trustService.OnEventRejected(organizerID)
	}
	return nil
}

func (s *ModerationService) EncryptMeetingLink(link string) (string, error) {
	return security.EncryptMeetingLink(link, s.encryptionKey)
}

func (s *ModerationService) DecryptMeetingLink(encrypted string) (string, error) {
	return security.DecryptMeetingLink(encrypted, s.encryptionKey)
}

func (s *ModerationService) GetModerationQueue(limit, offset int) ([]models.ModerationQueueItem, int64, error) {
	return s.repo.GetModerationQueue(limit, offset)
}

func (s *ModerationService) GetHighRiskEvents(limit, offset int) ([]models.ModerationQueueItem, int64, error) {
	return s.repo.GetHighRiskEvents(limit, offset)
}

func (s *ModerationService) GetOrganizerRiskRanking(limit, offset int) ([]models.OrganizerRiskRanking, int64, error) {
	return s.repo.GetOrganizerRiskRanking(limit, offset)
}

func (s *ModerationService) GetEventScans(eventID uuid.UUID) ([]models.ModerationScan, error) {
	return s.repo.GetByEventID(eventID)
}

func (s *ModerationService) ShouldSuspendUser(userID uuid.UUID) (bool, error) {
	return s.abuseService.ShouldSuspend(userID)
}

func (s *ModerationService) GetAbuseCount(userID uuid.UUID, window time.Duration) (int, error) {
	return s.abuseService.GetAbuseCount(userID, window)
}

func deriveKey(input string) []byte {
	key := make([]byte, 32)
	copy(key, []byte(input))
	return key
}

var _ = json.Marshal
