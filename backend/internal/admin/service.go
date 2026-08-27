package admin

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log"
	"strings"

	"github.com/google/uuid"

	eventpkg "github.com/khair/backend/internal/event"
	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/internal/notification"
	"github.com/khair/backend/internal/push"
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
	pushService         *push.Service
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
	ListPendingEventUpdates() ([]models.EventWithOrganizer, error)
	GetPendingEventUpdate(eventID uuid.UUID) (*models.EventUpdateRequest, error)
	ReviewEventUpdate(eventID uuid.UUID, status string, reason *string, reviewerID uuid.UUID) (*models.EventWithOrganizer, error)
}

type StatusUpdateRequest struct {
	Status          string  `json:"status" binding:"required,oneof=approved rejected needs_revision published cancelled"`
	RejectionReason *string `json:"rejection_reason"`
}

func NewService(db *sql.DB, organizerRepo OrganizerRepository, eventRepo EventRepository, rbacService *rbac.Service, notifService *notification.Service, pushSvc *push.Service, cacheService *cache.Service, sseHub *sse.Hub) *Service {
	return &Service{
		db:                  db,
		organizerRepo:       organizerRepo,
		eventRepo:           eventRepo,
		rbacService:         rbacService,
		notificationService: notifService,
		pushService:         pushSvc,
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

	// Keep the authorization role synchronized with the reviewed application.
	// Event handlers enforce both role and organizer status, so approval must
	// grant the organizer role and a later rejection must revoke it.
	switch req.Status {
	case "approved":
		if _, err := s.db.Exec(`UPDATE users SET role = 'organizer', updated_at = NOW() WHERE id = $1 AND role = 'user'`, org.UserID); err != nil {
			return nil, fmt.Errorf("grant organizer role: %w", err)
		}
		_, _ = s.db.Exec(`UPDATE organizer_applications SET status = 'approved', reviewed_at = NOW(), updated_at = NOW() WHERE user_id = $1`, org.UserID)
	case "rejected":
		if _, err := s.db.Exec(`UPDATE users SET role = 'user', updated_at = NOW() WHERE id = $1 AND role = 'organizer'`, org.UserID); err != nil {
			return nil, fmt.Errorf("revoke organizer role: %w", err)
		}
		_, _ = s.db.Exec(`UPDATE organizer_applications SET status = 'rejected', admin_user_message = $2, reviewed_at = NOW(), updated_at = NOW() WHERE user_id = $1`, org.UserID, req.RejectionReason)
	}

	org.Status = req.Status
	org.RejectionReason = req.RejectionReason

	// One persisted notification and one FCM push share the same ID.
	s.notifyOrganizerApplicationStatus(org, req.Status, req.RejectionReason)

	return org, nil
}

func (s *Service) ListPendingEvents() ([]models.EventWithOrganizer, error) {
	events, err := s.eventRepo.ListPending()
	if err != nil {
		return nil, err
	}
	updates, err := s.eventRepo.ListPendingEventUpdates()
	if err != nil {
		return nil, err
	}
	return append(events, updates...), nil
}

func (s *Service) GetEvent(id uuid.UUID) (*models.EventWithOrganizer, error) {
	return s.eventRepo.GetByID(id)
}

func (s *Service) UpdateEventStatus(id uuid.UUID, req *StatusUpdateRequest, reviewerID uuid.UUID) (*models.EventWithOrganizer, error) {
	// An approved/published event with a pending organizer snapshot is reviewed
	// through the same admin queue, while the original event status remains
	// untouched until approval.
	if _, err := s.eventRepo.GetPendingEventUpdate(id); err == nil {
		if req.Status == "published" {
			req.Status = "approved"
		}
		if req.Status != "approved" && req.Status != "rejected" && req.Status != "needs_revision" {
			return nil, errors.New("only approve, reject, or request changes is valid for an event update")
		}
		if req.Status == "rejected" && (req.RejectionReason == nil || strings.TrimSpace(*req.RejectionReason) == "") {
			return nil, errors.New("rejection reason is required when rejecting")
		}
		if req.Status == "needs_revision" && (req.RejectionReason == nil || strings.TrimSpace(*req.RejectionReason) == "") {
			return nil, errors.New("revision notes are required")
		}
		updated, err := s.eventRepo.ReviewEventUpdate(id, req.Status, req.RejectionReason, reviewerID)
		if err != nil {
			return nil, fmt.Errorf("review event update: %w", err)
		}
		if req.Status == "approved" {
			s.invalidateEventCaches(id)
		}
		var orgUserID uuid.UUID
		if err := s.db.QueryRow(`SELECT user_id FROM organizers WHERE id = $1`, updated.OrganizerID).Scan(&orgUserID); err == nil {
			s.notifyOrganizerEventStatus(orgUserID, updated, req.Status, req.RejectionReason)
		}
		return updated, nil
	}

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

		s.invalidateEventCaches(id)

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

	// Notify the organizer about the event status change.
	var orgUserID uuid.UUID
	if err := s.db.QueryRow(`SELECT user_id FROM organizers WHERE id = $1`, evt.OrganizerID).Scan(&orgUserID); err == nil {
		s.notifyOrganizerEventStatus(orgUserID, evt, req.Status, req.RejectionReason)
	}

	return evt, nil
}

func (s *Service) invalidateEventCaches(id uuid.UUID) {
	if s.cacheService == nil {
		return
	}
	ctx := context.Background()
	_ = s.cacheService.InvalidateEventList(ctx)
	_ = s.cacheService.InvalidateEventDetail(ctx, id.String())
	_ = s.cacheService.InvalidateGeoSearch(ctx)
}

func (s *Service) notifyOrganizerApplicationStatus(org *models.Organizer, status string, reason *string) {
	if s.notificationService == nil {
		return
	}
	reasonText := ""
	if reason != nil {
		reasonText = strings.TrimSpace(*reason)
	}
	typeName := "organizer_revision_requested"
	switch status {
	case "approved":
		typeName = "organizer_approved"
	case "rejected":
		typeName = "organizer_rejected"
	}
	data := map[string]string{
		"type":           typeName,
		"status":         status,
		"organizer_name": org.Name,
		"reason":         reasonText,
		"entity_type":    "organizer",
		"entity_id":      org.ID.String(),
	}
	copy, notificationID, created, err := s.notificationService.CreateLocalizedOnce(
		org.UserID,
		"organizer_application",
		data,
		"organizer_application:"+org.ID.String()+":"+status,
	)
	if err != nil {
		log.Printf("[ADMIN] organizer notification failed: %v", err)
		return
	}
	if s.pushService != nil && created {
		data["notification_id"] = notificationID.String()
		s.pushService.SendToUser(org.UserID, copy.Title, copy.Message, data)
	}
}

func (s *Service) notifyOrganizerEventStatus(userID uuid.UUID, event *models.EventWithOrganizer, status string, reason *string) {
	if s.notificationService == nil {
		return
	}
	reasonText := ""
	if reason != nil {
		reasonText = strings.TrimSpace(*reason)
	}
	typeName := "event_revision_requested"
	switch status {
	case "approved", "published":
		typeName = "event_approved"
	case "rejected":
		typeName = "event_rejected"
	}
	data := map[string]string{
		"type":        typeName,
		"status":      status,
		"event_title": event.Title,
		"reason":      reasonText,
		"entity_type": "event",
		"entity_id":   event.ID.String(),
		"event_id":    event.ID.String(),
	}
	copy, notificationID, created, err := s.notificationService.CreateLocalizedOnce(
		userID,
		"event_status",
		data,
		"event_status:"+event.ID.String()+":"+status,
	)
	if err != nil {
		log.Printf("[ADMIN] event notification failed: %v", err)
		return
	}
	if s.pushService != nil && created {
		data["notification_id"] = notificationID.String()
		s.pushService.SendToUser(userID, copy.Title, copy.Message, data)
	}
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
		_, _ = s.notificationService.CreateLocalized(userID, "account_status", map[string]string{
			"status": "suspended",
			"reason": reason,
		})
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
		_, _ = s.notificationService.CreateLocalized(userID, "account_status", map[string]string{
			"status": "restored",
		})
	}

	return nil
}

// ── Admin Notifications ──

// SendNotificationRequest is the request body for admin send notification
type SendNotificationRequest struct {
	Title   string  `json:"title" binding:"required"`
	Message string  `json:"message" binding:"required"`
	Target  string  `json:"target" binding:"required,oneof=all individual"`
	UserID  *string `json:"user_id"` // required when target=individual
}

// SendNotification sends a notification to all users or a specific user
func (s *Service) SendNotification(req *SendNotificationRequest) (int64, error) {
	if s.notificationService == nil {
		return 0, errors.New("notification service not available")
	}

	if req.Target == "all" {
		count, err := s.notificationService.CreateForAll(req.Title, req.Message)
		if err != nil {
			return 0, fmt.Errorf("send notification to all: %w", err)
		}

		// Send FCM push to all users in background
		if s.pushService != nil {
			go s.sendPushToAll(req.Title, req.Message)
		}

		log.Printf("[ADMIN] Sent notification to %d users: %s", count, req.Title)
		return count, nil
	}

	// Individual
	if req.UserID == nil || *req.UserID == "" {
		return 0, errors.New("user_id is required for individual notifications")
	}

	userID, err := uuid.Parse(*req.UserID)
	if err != nil {
		return 0, errors.New("invalid user_id")
	}

	if err := s.notificationService.Create(userID, req.Title, req.Message); err != nil {
		return 0, fmt.Errorf("send notification to user: %w", err)
	}

	// Send FCM push
	if s.pushService != nil {
		go s.pushService.SendToUser(userID, req.Title, req.Message, nil)
	}

	log.Printf("[ADMIN] Sent notification to user %s: %s", userID, req.Title)
	return 1, nil
}

// sendPushToAll sends FCM push notifications to all users with device tokens
func (s *Service) sendPushToAll(title, message string) {
	rows, err := s.db.Query(`SELECT DISTINCT user_id FROM device_tokens`)
	if err != nil {
		log.Printf("[ADMIN] Error getting device token users: %v", err)
		return
	}
	defer rows.Close()

	for rows.Next() {
		var uid uuid.UUID
		if err := rows.Scan(&uid); err != nil {
			continue
		}
		s.pushService.SendToUser(uid, title, message, nil)
	}
}

// AdminUserBasic is a simplified user struct for search results
type AdminUserBasic struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
}

// SearchUsers searches for users by name or email
func (s *Service) SearchUsers(query string) ([]AdminUserBasic, error) {
	query = strings.TrimSpace(query)
	if len(query) < 2 {
		return []AdminUserBasic{}, nil
	}

	rows, err := s.db.Query(
		`SELECT id, COALESCE(display_name, email), email FROM users
		 WHERE (LOWER(COALESCE(display_name, '')) LIKE $1 OR LOWER(email) LIKE $1)
		 AND status != 'suspended'
		 ORDER BY display_name ASC LIMIT 20`,
		"%"+strings.ToLower(query)+"%",
	)
	if err != nil {
		return nil, fmt.Errorf("search users: %w", err)
	}
	defer rows.Close()

	var users []AdminUserBasic
	for rows.Next() {
		var u AdminUserBasic
		if err := rows.Scan(&u.ID, &u.Name, &u.Email); err != nil {
			continue
		}
		users = append(users, u)
	}
	if users == nil {
		users = []AdminUserBasic{}
	}
	return users, nil
}

// AdminUserDetail is a full user record for admin viewing
type AdminUserDetail struct {
	ID                 string  `json:"id"`
	Email              string  `json:"email"`
	DisplayName        *string `json:"display_name"`
	Role               string  `json:"role"`
	Status             string  `json:"status"`
	IsVerified         bool    `json:"is_verified"`
	VerificationStatus *string `json:"verification_status"`
	Gender             *string `json:"gender"`
	Age                *int    `json:"age"`
	Bio                *string `json:"bio"`
	Location           *string `json:"location"`
	City               *string `json:"city"`
	Country            *string `json:"country"`
	AvatarURL          *string `json:"avatar_url"`
	CreatedAt          string  `json:"created_at"`
	// Verification request info (if any)
	VerificationRequestID   *string `json:"verification_request_id,omitempty"`
	VerificationDocURL      *string `json:"verification_document_url,omitempty"`
	VerificationPhotoURL    *string `json:"verification_photo_url,omitempty"`
	VerificationDocType     *string `json:"verification_document_type,omitempty"`
	VerificationNotes       *string `json:"verification_notes,omitempty"`
	VerificationReviewNotes *string `json:"verification_review_notes,omitempty"`
	VerificationSubmittedAt *string `json:"verification_submitted_at,omitempty"`
}

// GetUserDetail returns full user details including profile and verification info
func (s *Service) GetUserDetail(userID uuid.UUID) (*AdminUserDetail, error) {
	var u AdminUserDetail
	err := s.db.QueryRow(`
		SELECT u.id, u.email, u.display_name, u.role, u.status, u.is_verified,
		       u.verification_status, u.gender, u.age,
		       p.bio, p.location, p.city, p.country, p.avatar_url,
		       u.created_at
		FROM users u
		LEFT JOIN profiles p ON p.user_id = u.id
		WHERE u.id = $1
	`, userID).Scan(
		&u.ID, &u.Email, &u.DisplayName, &u.Role, &u.Status, &u.IsVerified,
		&u.VerificationStatus, &u.Gender, &u.Age,
		&u.Bio, &u.Location, &u.City, &u.Country, &u.AvatarURL,
		&u.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("get user detail: %w", err)
	}

	// Get latest verification request if any
	var vrID, docURL, photoURL, docType, notes, reviewNotes, submittedAt sql.NullString
	err = s.db.QueryRow(`
		SELECT id, document_path, profile_image_path, document_type, notes, review_notes, created_at
		FROM verification_requests
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT 1
	`, userID).Scan(&vrID, &docURL, &photoURL, &docType, &notes, &reviewNotes, &submittedAt)
	if err == nil {
		if vrID.Valid {
			u.VerificationRequestID = &vrID.String
		}
		if docURL.Valid {
			u.VerificationDocURL = &docURL.String
		}
		if photoURL.Valid {
			u.VerificationPhotoURL = &photoURL.String
		}
		if docType.Valid {
			u.VerificationDocType = &docType.String
		}
		if notes.Valid {
			u.VerificationNotes = &notes.String
		}
		if reviewNotes.Valid {
			u.VerificationReviewNotes = &reviewNotes.String
		}
		if submittedAt.Valid {
			u.VerificationSubmittedAt = &submittedAt.String
		}
	}

	return &u, nil
}
