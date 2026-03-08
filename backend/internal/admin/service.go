package admin

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log"

	"github.com/google/uuid"

	eventpkg "github.com/khair/backend/internal/event"
	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/internal/notification"
	"github.com/khair/backend/internal/rbac"
	"github.com/khair/backend/internal/sse"
	"github.com/khair/backend/pkg/cache"
)

type Service struct {
	db                  *sql.DB
	organizerRepo       OrganizerRepository
	eventRepo           EventRepository
	rbacService         *rbac.Service
	notificationService *notification.Service
	cacheService        *cache.Service
	sseHub              *sse.Hub
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

func NewService(db *sql.DB, organizerRepo OrganizerRepository, eventRepo EventRepository, rbacService *rbac.Service, notifService *notification.Service, cacheService *cache.Service, sseHub *sse.Hub) *Service {
	return &Service{
		db:                  db,
		organizerRepo:       organizerRepo,
		eventRepo:           eventRepo,
		rbacService:         rbacService,
		notificationService: notifService,
		cacheService:        cacheService,
		sseHub:              sseHub,
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
		return nil, fmt.Errorf("get organizer: %w", err)
	}

	if req.Status == "rejected" && (req.RejectionReason == nil || *req.RejectionReason == "") {
		return nil, errors.New("rejection reason is required when rejecting")
	}

	if err := s.organizerRepo.UpdateStatus(id, req.Status, req.RejectionReason); err != nil {
		return nil, fmt.Errorf("update organizer status: %w", err)
	}

	org.Status = req.Status
	org.RejectionReason = req.RejectionReason

	// Send notification to the organizer's user
	if s.notificationService != nil {
		switch req.Status {
		case "approved":
			_ = s.notificationService.Create(
				org.UserID,
				"Application Approved",
				fmt.Sprintf("Your organizer application for \"%s\" has been approved. You can now create and manage events.", org.Name),
			)
		case "rejected":
			reason := "No reason provided"
			if req.RejectionReason != nil && *req.RejectionReason != "" {
				reason = *req.RejectionReason
			}
			_ = s.notificationService.Create(
				org.UserID,
				"Application Update",
				fmt.Sprintf("Your organizer application for \"%s\" requires attention: %s", org.Name, reason),
			)
		}
	}

	return org, nil
}

func (s *Service) ListPendingEvents() ([]models.EventWithOrganizer, error) {
	return s.eventRepo.ListPending()
}

func (s *Service) GetEvent(id uuid.UUID) (*models.EventWithOrganizer, error) {
	return s.eventRepo.GetByID(id)
}

func (s *Service) UpdateEventStatus(id uuid.UUID, req *StatusUpdateRequest, reviewerID uuid.UUID) (*models.EventWithOrganizer, error) {
	evt, err := s.eventRepo.GetByID(id)
	if err != nil {
		return nil, fmt.Errorf("get event: %w", err)
	}

	// Enforce state machine transitions
	if err := eventpkg.ValidateTransition(evt.Status, req.Status); err != nil {
		return nil, fmt.Errorf("invalid status change: %w", err)
	}

	if req.Status == "rejected" && (req.RejectionReason == nil || *req.RejectionReason == "") {
		return nil, errors.New("rejection reason is required when rejecting")
	}

	if req.Status == "needs_revision" && (req.RejectionReason == nil || *req.RejectionReason == "") {
		return nil, errors.New("revision notes are required")
	}

	if err := s.eventRepo.UpdateStatusWithReviewer(id, req.Status, req.RejectionReason, reviewerID); err != nil {
		return nil, fmt.Errorf("update event status: %w", err)
	}

	log.Printf("[AUDIT] Event %s status changed %s → %s by %s", id, evt.Status, req.Status, reviewerID)

	evt.Status = req.Status
	evt.RejectionReason = req.RejectionReason

	// On approval: invalidate caches and broadcast SSE event
	if req.Status == "approved" || req.Status == "published" {
		evt.IsPublished = true

		// Invalidate Redis caches so the public API returns fresh data
		if s.cacheService != nil {
			ctx := context.Background()
			_ = s.cacheService.InvalidateEventList(ctx)
			_ = s.cacheService.InvalidateEventDetail(ctx, id.String())
			_ = s.cacheService.InvalidateGeoSearch(ctx)
		}

		// Broadcast real-time SSE event
		if s.sseHub != nil {
			s.sseHub.Broadcast("eventApproved", map[string]interface{}{
				"event_id":       id.String(),
				"title":          evt.Title,
				"organizer_name": evt.OrganizerName,
				"status":         req.Status,
			})
		}
	}

	// Notify the organizer about the event status change
	if s.notificationService != nil {
		// Look up organizer's user_id
		var orgUserID uuid.UUID
		err := s.db.QueryRow(`SELECT user_id FROM organizers WHERE id = $1`, evt.OrganizerID).Scan(&orgUserID)
		if err == nil {
			switch req.Status {
			case "approved", "published":
				_ = s.notificationService.Create(
					orgUserID,
					"Event Approved",
					fmt.Sprintf("Your event \"%s\" has been approved and is now visible to users.", evt.Title),
				)
			case "rejected":
				reason := "No reason provided"
				if req.RejectionReason != nil && *req.RejectionReason != "" {
					reason = *req.RejectionReason
				}
				_ = s.notificationService.Create(
					orgUserID,
					"Event Update",
					fmt.Sprintf("Your event \"%s\" requires attention: %s", evt.Title, reason),
				)
			case "needs_revision":
				notes := ""
				if req.RejectionReason != nil {
					notes = *req.RejectionReason
				}
				_ = s.notificationService.Create(
					orgUserID,
					"Event Revision Requested",
					fmt.Sprintf("Your event \"%s\" needs revisions: %s", evt.Title, notes),
				)
			}
		}
	}

	return evt, nil
}

// SuspendUser suspends a user account and revokes all their refresh tokens
func (s *Service) SuspendUser(userID uuid.UUID, reason string, adminID uuid.UUID) error {
	_, err := s.db.Exec(`
		UPDATE users SET status = 'suspended', suspended_at = NOW(),
		suspended_reason = $1, suspended_by = $2, updated_at = NOW()
		WHERE id = $3
	`, reason, adminID, userID)
	if err != nil {
		return fmt.Errorf("suspend user: %w", err)
	}

	// Revoke all refresh tokens
	_, _ = s.db.Exec(`UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = $1 AND revoked_at IS NULL`, userID)

	// Notify user about suspension
	if s.notificationService != nil {
		_ = s.notificationService.Create(
			userID,
			"Account Suspended",
			fmt.Sprintf("Your account has been suspended. Reason: %s", reason),
		)
	}

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
		return fmt.Errorf("unsuspend user: %w", err)
	}

	// Notify user about unsuspension
	if s.notificationService != nil {
		_ = s.notificationService.Create(
			userID,
			"Account Restored",
			"Your account suspension has been lifted. You can now access all features.",
		)
	}

	return nil
}
