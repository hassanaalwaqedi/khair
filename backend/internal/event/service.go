package event

import (
	"database/sql"
	"errors"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/eligibility"
	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/internal/notification"
	"github.com/khair/backend/internal/push"
)

type ModerationScanner interface {
	ScanAndModerate(req *models.ScanRequest) (*models.ScanResult, error)
}

type Service struct {
	repo          *Repository
	db            *sql.DB
	organizerRepo OrganizerRepository
	moderation    ModerationScanner
	notifications *notification.Service
	pushService   *push.Service
}

// OrganizerRepository interface for organizer operations
type OrganizerRepository interface {
	GetByID(id uuid.UUID) (*models.Organizer, error)
	GetByUserID(userID uuid.UUID) (*models.Organizer, error)
	Create(org *models.Organizer) error
}

func pointerString(value *string) string {
	if value == nil {
		return ""
	}
	return *value
}

func NewService(db *sql.DB, organizerRepo OrganizerRepository) *Service {
	return &Service{
		repo:          NewRepository(db),
		db:            db,
		organizerRepo: organizerRepo,
	}
}

func (s *Service) SetModeration(m ModerationScanner) {
	s.moderation = m
}

// SetNotificationDelivery wires event changes into the existing notification
// record and FCM services without creating a parallel notification system.
func (s *Service) SetNotificationDelivery(notifications *notification.Service, pushService *push.Service) {
	s.notifications = notifications
	s.pushService = pushService
}

func (s *Service) IsSaved(userID, eventID uuid.UUID) (bool, error) {
	return s.repo.IsSaved(userID, eventID)
}

func (s *Service) SaveEvent(userID, eventID uuid.UUID) error {
	event, err := s.repo.GetByID(eventID)
	if err != nil || event.Status != "approved" {
		return errors.New("event not found")
	}
	return s.repo.SaveForUser(userID, eventID)
}

func (s *Service) UnsaveEvent(userID, eventID uuid.UUID) error {
	return s.repo.UnsaveForUser(userID, eventID)
}

func (s *Service) GetSavedEvents(userID uuid.UUID) ([]SavedEventSummary, error) {
	return s.repo.GetSavedEvents(userID)
}

func (s *Service) RecordView(eventID uuid.UUID, sessionID string) error {
	return s.repo.RecordView(eventID, sessionID)
}

// CreateEventRequest represents a request to create an event
type CreateEventRequest struct {
	Title                        string              `json:"title" binding:"required"`
	Description                  *string             `json:"description"`
	Category                     string              `json:"category"`
	Tags                         []string            `json:"tags"`
	EventType                    string              `json:"event_type" binding:"required"`
	Language                     *string             `json:"language"`
	Country                      *string             `json:"country"`
	City                         *string             `json:"city"`
	Address                      *string             `json:"address"`
	Latitude                     *float64            `json:"latitude"`
	Longitude                    *float64            `json:"longitude"`
	StartDate                    string              `json:"start_date" binding:"required"`
	EndDate                      *string             `json:"end_date"`
	ImageURL                     *string             `json:"image_url"`
	IsOnline                     bool                `json:"is_online"`
	OnlineLink                   *string             `json:"online_link"`
	OnlinePlatform               *string             `json:"online_platform"`
	JoinInstructions             *string             `json:"join_instructions"`
	JoinLinkVisibleBeforeMinutes *int                `json:"join_link_visible_before_minutes"`
	Pricing                      *models.PricingInfo `json:"pricing"`
	VenueName                    *string             `json:"venue_name"`
	Capacity                     *int                `json:"capacity"`
	GenderRestriction            *string             `json:"gender_restriction"`
	AttendancePolicy             *string             `json:"attendance_policy"`
	AgeMin                       *int                `json:"age_min"`
	RegistrationDeadline         *string             `json:"registration_deadline"`
	RegistrationMode             string              `json:"registration_mode"`
	Timezone                     string              `json:"timezone"`
	Guidelines                   *string             `json:"guidelines"`
}

// DraftEventRequest is a relaxed version of CreateEventRequest used for
// auto-saving partially-filled forms. Only Title is required.
type DraftEventRequest struct {
	Title                        string              `json:"title" binding:"required"`
	Description                  *string             `json:"description"`
	Category                     string              `json:"category"`
	Tags                         []string            `json:"tags"`
	EventType                    string              `json:"event_type"`
	Language                     *string             `json:"language"`
	Country                      *string             `json:"country"`
	City                         *string             `json:"city"`
	Address                      *string             `json:"address"`
	Latitude                     *float64            `json:"latitude"`
	Longitude                    *float64            `json:"longitude"`
	StartDate                    string              `json:"start_date"`
	EndDate                      *string             `json:"end_date"`
	ImageURL                     *string             `json:"image_url"`
	IsOnline                     bool                `json:"is_online"`
	OnlineLink                   *string             `json:"online_link"`
	OnlinePlatform               *string             `json:"online_platform"`
	JoinInstructions             *string             `json:"join_instructions"`
	JoinLinkVisibleBeforeMinutes *int                `json:"join_link_visible_before_minutes"`
	Pricing                      *models.PricingInfo `json:"pricing"`
	VenueName                    *string             `json:"venue_name"`
	Capacity                     *int                `json:"capacity"`
	GenderRestriction            *string             `json:"gender_restriction"`
	AttendancePolicy             *string             `json:"attendance_policy"`
	AgeMin                       *int                `json:"age_min"`
	RegistrationDeadline         *string             `json:"registration_deadline"`
	RegistrationMode             string              `json:"registration_mode"`
	Timezone                     string              `json:"timezone"`
	Guidelines                   *string             `json:"guidelines"`
}

// toCreateRequest converts a DraftEventRequest into a CreateEventRequest,
// filling in safe defaults for any missing required fields.
func (d *DraftEventRequest) toCreateRequest() CreateEventRequest {
	eventType := d.EventType
	if eventType == "" {
		eventType = "offline"
	}
	startDate := d.StartDate
	if startDate == "" {
		startDate = time.Now().Add(7 * 24 * time.Hour).Format(time.RFC3339)
	}
	return CreateEventRequest{
		Title:                        d.Title,
		Description:                  d.Description,
		Category:                     d.Category,
		Tags:                         d.Tags,
		EventType:                    eventType,
		Language:                     d.Language,
		Country:                      d.Country,
		City:                         d.City,
		Address:                      d.Address,
		Latitude:                     d.Latitude,
		Longitude:                    d.Longitude,
		StartDate:                    startDate,
		EndDate:                      d.EndDate,
		ImageURL:                     d.ImageURL,
		IsOnline:                     d.IsOnline,
		OnlineLink:                   d.OnlineLink,
		OnlinePlatform:               d.OnlinePlatform,
		JoinInstructions:             d.JoinInstructions,
		JoinLinkVisibleBeforeMinutes: d.JoinLinkVisibleBeforeMinutes,
		Pricing:                      d.Pricing,
		VenueName:                    d.VenueName,
		Capacity:                     d.Capacity,
		GenderRestriction:            d.GenderRestriction,
		AttendancePolicy:             d.AttendancePolicy,
		AgeMin:                       d.AgeMin,
		RegistrationDeadline:         d.RegistrationDeadline,
		RegistrationMode:             d.RegistrationMode,
		Timezone:                     d.Timezone,
		Guidelines:                   d.Guidelines,
	}
}

// UpdateEventRequest represents a request to update an event
type UpdateEventRequest struct {
	Title                         *string             `json:"title"`
	Description                   *string             `json:"description"`
	Category                      *string             `json:"category"`
	Tags                          *[]string           `json:"tags"`
	EventType                     *string             `json:"event_type"`
	Language                      *string             `json:"language"`
	Country                       *string             `json:"country"`
	City                          *string             `json:"city"`
	Address                       *string             `json:"address"`
	Latitude                      *float64            `json:"latitude"`
	Longitude                     *float64            `json:"longitude"`
	StartDate                     *string             `json:"start_date"`
	EndDate                       *string             `json:"end_date"`
	ImageURL                      *string             `json:"image_url"`
	IsOnline                      *bool               `json:"is_online"`
	OnlineLink                    *string             `json:"online_link"`
	OnlinePlatform                *string             `json:"online_platform"`
	JoinInstructions              *string             `json:"join_instructions"`
	JoinLinkVisibleBeforeMinutes  *int                `json:"join_link_visible_before_minutes"`
	Pricing                       *models.PricingInfo `json:"pricing"`
	VenueName                     *string             `json:"venue_name"`
	Capacity                      *int                `json:"capacity"`
	GenderRestriction             *string             `json:"gender_restriction"`
	AttendancePolicy              *string             `json:"attendance_policy"`
	ConfirmAttendancePolicyChange bool                `json:"confirm_attendance_policy_change"`
	AgeMin                        *int                `json:"age_min"`
	RegistrationDeadline          *string             `json:"registration_deadline"`
	RegistrationMode              *string             `json:"registration_mode"`
	Timezone                      *string             `json:"timezone"`
	Guidelines                    *string             `json:"guidelines"`
}

// normalizeEventMode keeps the legacy event_type column and the is_online
// capability flag aligned.  The editor exposes exactly two formats, online
// and in-person (stored as offline).  Older API clients can still submit a
// non-mode event_type such as "workshop"; in that case we preserve the label
// and use the explicit boolean rather than changing unrelated legacy data.
func normalizeEventMode(eventType string, isOnline bool) (string, bool) {
	switch strings.ToLower(strings.TrimSpace(eventType)) {
	case "online":
		return "online", true
	case "offline", "in_person", "in-person", "inperson":
		return "offline", false
	default:
		return eventType, isOnline
	}
}

// Create creates a new event
func (s *Service) Create(userID uuid.UUID, req *CreateEventRequest) (*models.Event, error) {
	// Creating an event is an organizer privilege. Do not create or approve an
	// organizer implicitly here: that would let any authenticated user bypass
	// the organizer review workflow simply by calling this endpoint.
	organizer, err := s.organizerRepo.GetByUserID(userID)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, errors.New("an approved organizer profile is required to create events")
		}
		return nil, fmt.Errorf("get organizer profile: %w", err)
	}

	// Check if organizer is approved
	if organizer.Status != "approved" {
		return nil, errors.New("your organization is not yet approved")
	}
	if title := strings.TrimSpace(req.Title); len([]rune(title)) < 3 || len([]rune(title)) > 120 {
		return nil, errors.New("title must be between 3 and 120 characters")
	}
	if req.Description == nil || len([]rune(strings.TrimSpace(*req.Description))) < 50 {
		return nil, errors.New("description must be at least 50 characters")
	}
	req.EventType, req.IsOnline = normalizeEventMode(req.EventType, req.IsOnline)
	if req.Category == "" {
		req.Category = req.EventType
	}
	if req.RegistrationMode == "" {
		req.RegistrationMode = "instant"
	}
	if req.Timezone == "" {
		req.Timezone = "UTC"
	}
	if req.RegistrationMode != "instant" && req.RegistrationMode != "approval_required" {
		return nil, errors.New("invalid registration mode")
	}
	policyInput := ""
	if req.AttendancePolicy != nil {
		policyInput = *req.AttendancePolicy
	} else if req.GenderRestriction != nil {
		policyInput = *req.GenderRestriction
	}
	attendancePolicy, policyErr := eligibility.NormalizePolicy(policyInput)
	if policyErr != nil {
		return nil, policyErr
	}
	if req.Capacity != nil && *req.Capacity < 1 {
		return nil, errors.New("capacity must be at least 1")
	}

	// Validate pricing
	if req.Pricing == nil {
		// Default to free
		req.Pricing = &models.PricingInfo{Type: "free"}
	}
	if req.Pricing.Type != "free" && req.Pricing.Type != "paid" {
		return nil, errors.New("invalid pricing type")
	}
	if req.Pricing.Type == "paid" {
		if req.IsOnline {
			return nil, errors.New("paid online events aren't supported yet")
		}
		if req.Pricing.AmountCents == nil || *req.Pricing.AmountCents <= 0 {
			return nil, errors.New("paid events must have a valid price > 0")
		}
		if req.Pricing.Currency == nil || *req.Pricing.Currency == "" {
			return nil, errors.New("paid events must specify a currency")
		}
		if req.Pricing.PaymentMethod == nil || *req.Pricing.PaymentMethod != "pay_at_venue" {
			return nil, errors.New("paid events must use 'pay_at_venue' payment method")
		}
	}

	// Parse and validate dates
	startDate, err := time.Parse(time.RFC3339, req.StartDate)
	if err != nil {
		return nil, errors.New("invalid start date format, use RFC3339")
	}

	// Event must be in the future
	if startDate.Before(time.Now()) {
		return nil, errors.New("event start date must be in the future")
	}

	var endDate *time.Time
	if req.EndDate != nil {
		ed, err := time.Parse(time.RFC3339, *req.EndDate)
		if err != nil {
			return nil, errors.New("invalid end date format, use RFC3339")
		}
		// End date must be after start date
		if !ed.After(startDate) {
			return nil, errors.New("event end date must be after start date")
		}
		endDate = &ed
	}
	var registrationDeadline *time.Time
	if req.RegistrationDeadline != nil && strings.TrimSpace(*req.RegistrationDeadline) != "" {
		deadline, err := time.Parse(time.RFC3339, *req.RegistrationDeadline)
		if err != nil || !deadline.Before(startDate) {
			return nil, errors.New("registration deadline must be before the event start")
		}
		registrationDeadline = &deadline
	}

	// Duplicate detection: same organizer + similar title + same date
	if dup, _ := s.repo.FindDuplicate(organizer.ID, req.Title, startDate); dup != nil {
		return nil, fmt.Errorf("a similar event '%s' already exists on the same date (ID: %s). Please edit the existing event or change the date", dup.Title, dup.ID)
	}

	joinLinkMinutes := 15
	if req.JoinLinkVisibleBeforeMinutes != nil {
		joinLinkMinutes = *req.JoinLinkVisibleBeforeMinutes
	}
	legacyGenderRestriction := eligibility.LegacyGenderRestriction(attendancePolicy)

	event := &models.Event{
		ID:                           uuid.New(),
		OrganizerID:                  organizer.ID,
		Title:                        req.Title,
		Description:                  req.Description,
		EventType:                    req.EventType,
		Language:                     req.Language,
		Country:                      req.Country,
		City:                         req.City,
		Address:                      req.Address,
		Latitude:                     req.Latitude,
		Longitude:                    req.Longitude,
		StartDate:                    startDate,
		EndDate:                      endDate,
		ImageURL:                     req.ImageURL,
		IsOnline:                     req.IsOnline,
		OnlineLink:                   req.OnlineLink,
		JoinInstructions:             req.JoinInstructions,
		JoinLinkVisibleBeforeMinutes: joinLinkMinutes,
		Pricing:                      req.Pricing,
		Capacity:                     req.Capacity,
		GenderRestriction:            &legacyGenderRestriction,
		AttendancePolicy:             attendancePolicy,
		AgeMin:                       req.AgeMin,
		Status:                       "pending",
		CreatedAt:                    time.Now(),
		UpdatedAt:                    time.Now(),
	}

	if err := s.repo.Create(event); err != nil {
		return nil, fmt.Errorf("create event: %w", err)
	}
	if err := s.repo.SaveEditorMetadata(event.ID, req.Category, req.Tags, req.VenueName, req.OnlinePlatform, registrationDeadline, req.RegistrationMode, req.Timezone, req.Guidelines); err != nil {
		return nil, fmt.Errorf("save event editor data: %w", err)
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
	isPublished := true
	filter.IsPublished = &isPublished
	// Default to future events only if no explicit start date filter is provided
	if filter.StartDate == nil {
		now := time.Now()
		filter.StartDate = &now
	}
	return s.repo.List(filter)
}

// Update updates an event
func (s *Service) Update(userID uuid.UUID, eventID uuid.UUID, req *UpdateEventRequest) (*models.Event, error) {
	// Get organizer profile
	organizer, err := s.organizerRepo.GetByUserID(userID)
	if err != nil {
		return nil, fmt.Errorf("get organizer profile: %w", err)
	}
	if organizer.Status != "approved" {
		return nil, errors.New("your organization is not yet approved")
	}

	// Get existing event
	existingEvent, err := s.repo.GetByID(eventID)
	if err != nil {
		return nil, fmt.Errorf("get event: %w", err)
	}

	// Check ownership
	if existingEvent.OrganizerID != organizer.ID {
		return nil, errors.New("you don't have permission to update this event")
	}

	previousStartDate := existingEvent.StartDate
	previousPolicy, policyErr := eligibility.NormalizePolicy(existingEvent.AttendancePolicy)
	if policyErr != nil {
		previousPolicy, _ = eligibility.NormalizePolicy(pointerString(existingEvent.GenderRestriction))
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
		event.EventType, event.IsOnline = normalizeEventMode(*req.EventType, event.IsOnline)
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
		if startDate.Before(time.Now()) {
			return nil, errors.New("event start date must be in the future")
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
	if req.IsOnline != nil && req.EventType == nil {
		event.IsOnline = *req.IsOnline
		// A partial update that changes only the format must still update
		// the legacy type consumed by discovery filters.
		if event.IsOnline {
			event.EventType = "online"
		} else {
			event.EventType = "offline"
		}
	}
	if req.OnlineLink != nil {
		event.OnlineLink = req.OnlineLink
	}
	if req.JoinInstructions != nil {
		event.JoinInstructions = req.JoinInstructions
	}
	if req.JoinLinkVisibleBeforeMinutes != nil {
		event.JoinLinkVisibleBeforeMinutes = *req.JoinLinkVisibleBeforeMinutes
	}
	if req.Pricing != nil {
		if req.Pricing.Type != "free" && req.Pricing.Type != "paid" {
			return nil, errors.New("invalid pricing type")
		}
		if req.Pricing.Type == "paid" {
			isOnline := event.IsOnline
			if req.IsOnline != nil {
				isOnline = *req.IsOnline
			}
			if isOnline {
				return nil, errors.New("paid online events aren't supported yet")
			}
			if req.Pricing.AmountCents == nil || *req.Pricing.AmountCents <= 0 {
				return nil, errors.New("paid events must have a valid price > 0")
			}
			if req.Pricing.Currency == nil || *req.Pricing.Currency == "" {
				return nil, errors.New("paid events must specify a currency")
			}
			if req.Pricing.PaymentMethod == nil || *req.Pricing.PaymentMethod != "pay_at_venue" {
				return nil, errors.New("paid events must use 'pay_at_venue' payment method")
			}
		}
		event.Pricing = req.Pricing
	}
	if req.AttendancePolicy != nil || req.GenderRestriction != nil {
		policyInput := pointerString(req.AttendancePolicy)
		if policyInput == "" {
			policyInput = pointerString(req.GenderRestriction)
		}
		policy, normalizeErr := eligibility.NormalizePolicy(policyInput)
		if normalizeErr != nil {
			return nil, normalizeErr
		}
		if policy != previousPolicy {
			hasRegistrations, countErr := s.repo.HasFutureRegistrations(eventID)
			if countErr != nil {
				return nil, fmt.Errorf("check existing registrations: %w", countErr)
			}
			if hasRegistrations && !req.ConfirmAttendancePolicyChange {
				return nil, &eligibility.Error{
					Code:       "ATTENDANCE_POLICY_CHANGE_CONFIRMATION_REQUIRED",
					HTTPStatus: 409,
					Message:    "Confirm the attendance policy change because existing registrations may be affected.",
					Policy:     policy,
				}
			}
		}
		event.AttendancePolicy = policy
		legacy := eligibility.LegacyGenderRestriction(policy)
		event.GenderRestriction = &legacy
	}
	if req.Title != nil {
		title := strings.TrimSpace(*req.Title)
		if len([]rune(title)) < 3 || len([]rune(title)) > 120 {
			return nil, errors.New("title must be between 3 and 120 characters")
		}
	}
	if req.Description != nil && event.Status != "draft" && len([]rune(strings.TrimSpace(*req.Description))) < 50 {
		return nil, errors.New("description must be at least 50 characters")
	}

	if err := s.repo.Update(event); err != nil {
		return nil, fmt.Errorf("update event: %w", err)
	}
	if event.AttendancePolicy != previousPolicy && req.ConfirmAttendancePolicyChange {
		if err := s.repo.FlagIneligibleRegistrations(event.ID, event.AttendancePolicy); err != nil {
			return nil, fmt.Errorf("flag affected registrations: %w", err)
		}
	}
	var registrationDeadline *time.Time
	if req.RegistrationDeadline != nil && strings.TrimSpace(*req.RegistrationDeadline) != "" {
		deadline, parseErr := time.Parse(time.RFC3339, *req.RegistrationDeadline)
		if parseErr != nil || !deadline.Before(event.StartDate) {
			return nil, errors.New("registration deadline must be before the event start")
		}
		registrationDeadline = &deadline
	}
	if err := s.repo.UpdateEditorMetadata(event.ID, req.Category, req.Tags, req.VenueName, req.OnlinePlatform, registrationDeadline, req.RegistrationMode, req.Timezone, req.Guidelines); err != nil {
		return nil, fmt.Errorf("save event editor data: %w", err)
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

	if !event.StartDate.Equal(previousStartDate) {
		go s.notifyAttendeesOfScheduleChange(event.ID, event.Title, event.StartDate, event.Timezone)
	}

	return event, nil
}

// notifyAttendeesOfScheduleChange creates one localized, de-duplicated record
// per confirmed attendee, then sends the matching system notification.
func (s *Service) notifyAttendeesOfScheduleChange(eventID uuid.UUID, title string, startDate time.Time, timezone string) {
	if s.notifications == nil {
		return
	}
	rows, err := s.db.Query(`
		SELECT DISTINCT user_id
		FROM event_registrations
		WHERE event_id = $1 AND status IN ('confirmed', 'reserved')
	`, eventID)
	if err != nil {
		log.Printf("[EVENT] schedule-change recipients lookup failed: %v", err)
		return
	}
	defer rows.Close()

	dedupeKey := "event_updated:" + eventID.String() + ":" + startDate.UTC().Format(time.RFC3339Nano)
	for rows.Next() {
		var userID uuid.UUID
		if err := rows.Scan(&userID); err != nil {
			continue
		}
		data := map[string]string{
			"type":        "event_updated",
			"entity_type": "event",
			"entity_id":   eventID.String(),
			"event_id":    eventID.String(),
			"event_title": title,
			"start_at":    startDate.UTC().Format(time.RFC3339),
			"timezone":    timezone,
		}
		copy, notificationID, created, err := s.notifications.CreateLocalizedOnce(userID, "event_updated", data, dedupeKey)
		if err != nil {
			log.Printf("[EVENT] schedule-change notification failed: %v", err)
			continue
		}
		if s.pushService != nil && created {
			data["notification_id"] = notificationID.String()
			s.pushService.SendToUser(userID, copy.Title, copy.Message, data)
		}
	}
}

// Delete deletes an event
func (s *Service) Delete(userID uuid.UUID, eventID uuid.UUID) error {
	// Get organizer profile
	organizer, err := s.organizerRepo.GetByUserID(userID)
	if err != nil {
		return fmt.Errorf("get organizer profile: %w", err)
	}

	// Get existing event
	existingEvent, err := s.repo.GetByID(eventID)
	if err != nil {
		return fmt.Errorf("get event for delete: %w", err)
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
		return nil, fmt.Errorf("get organizer profile: %w", err)
	}

	// Get existing event
	existingEvent, err := s.repo.GetByID(eventID)
	if err != nil {
		return nil, fmt.Errorf("get event for review: %w", err)
	}

	// Check ownership
	if existingEvent.OrganizerID != organizer.ID {
		return nil, errors.New("you don't have permission to submit this event")
	}
	if err := validateCompleteEvent(&existingEvent.Event); err != nil {
		return nil, err
	}

	// Enforce state machine transitions
	if err := ValidateTransition(existingEvent.Status, "pending"); err != nil {
		return nil, fmt.Errorf("invalid status change: %w", err)
	}

	// Update status
	if err := s.repo.UpdateStatus(eventID, "pending", nil); err != nil {
		return nil, fmt.Errorf("submit event for review: %w", err)
	}

	existingEvent.Status = "pending"
	return &existingEvent.Event, nil
}

func validateCompleteEvent(event *models.Event) error {
	if len([]rune(strings.TrimSpace(event.Title))) < 3 {
		return errors.New("title is required")
	}
	if event.Description == nil || len([]rune(strings.TrimSpace(*event.Description))) < 50 {
		return errors.New("description must be at least 50 characters")
	}
	if event.ImageURL == nil || strings.TrimSpace(*event.ImageURL) == "" {
		return errors.New("cover image is required")
	}
	if event.StartDate.Before(time.Now()) {
		return errors.New("event start date must be in the future")
	}
	if event.IsOnline {
		if event.OnlineLink == nil || strings.TrimSpace(*event.OnlineLink) == "" {
			return errors.New("online meeting link is required")
		}
		return nil
	}
	if event.City == nil || strings.TrimSpace(*event.City) == "" ||
		event.Address == nil || strings.TrimSpace(*event.Address) == "" ||
		event.Latitude == nil || event.Longitude == nil {
		return errors.New("location is required")
	}
	return nil
}

// GetMyEvents retrieves events for the current organizer
func (s *Service) GetMyEvents(userID uuid.UUID) ([]models.Event, error) {
	organizer, err := s.organizerRepo.GetByUserID(userID)
	if err != nil {
		return nil, fmt.Errorf("get organizer profile: %w", err)
	}

	return s.repo.ListByOrganizerID(organizer.ID)
}

// CreateDraft saves an event as a draft (not submitted for approval)
func (s *Service) CreateDraft(userID uuid.UUID, req *CreateEventRequest) (*models.Event, error) {
	// Drafts are also organizer-owned content. Keeping the same check prevents
	// drafts from becoming a loophole around organizer approval.
	organizer, err := s.organizerRepo.GetByUserID(userID)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, errors.New("an approved organizer profile is required to save event drafts")
		}
		return nil, fmt.Errorf("get organizer profile: %w", err)
	}
	if organizer.Status != "approved" {
		return nil, errors.New("your organizer application is not approved")
	}

	// Parse dates (lenient for drafts)
	var startDate time.Time
	var endDate *time.Time

	if req.StartDate != "" {
		sd, err := time.Parse(time.RFC3339, req.StartDate)
		if err == nil {
			startDate = sd
		}
	}

	if req.EndDate != nil {
		ed, err := time.Parse(time.RFC3339, *req.EndDate)
		if err == nil {
			endDate = &ed
		}
	}
	if req.Category == "" {
		req.Category = req.EventType
	}
	if req.RegistrationMode == "" {
		req.RegistrationMode = "instant"
	}
	if req.Timezone == "" {
		req.Timezone = "UTC"
	}
	req.EventType, req.IsOnline = normalizeEventMode(req.EventType, req.IsOnline)

	policyInput := ""
	if req.AttendancePolicy != nil {
		policyInput = *req.AttendancePolicy
	} else if req.GenderRestriction != nil {
		policyInput = *req.GenderRestriction
	}
	attendancePolicy, policyErr := eligibility.NormalizePolicy(policyInput)
	if policyErr != nil {
		return nil, policyErr
	}
	legacyGenderRestriction := eligibility.LegacyGenderRestriction(attendancePolicy)

	event := &models.Event{
		ID:               uuid.New(),
		OrganizerID:      organizer.ID,
		Title:            req.Title,
		Description:      req.Description,
		EventType:        req.EventType,
		Language:         req.Language,
		Country:          req.Country,
		City:             req.City,
		Address:          req.Address,
		Latitude:         req.Latitude,
		Longitude:        req.Longitude,
		StartDate:        startDate,
		EndDate:          endDate,
		ImageURL:         req.ImageURL,
		IsOnline:         req.IsOnline,
		OnlineLink:       req.OnlineLink,
		JoinInstructions: req.JoinInstructions,
		JoinLinkVisibleBeforeMinutes: func() int {
			if req.JoinLinkVisibleBeforeMinutes != nil {
				return *req.JoinLinkVisibleBeforeMinutes
			}
			return 15
		}(),
		Pricing:           req.Pricing,
		Capacity:          req.Capacity,
		GenderRestriction: &legacyGenderRestriction,
		AttendancePolicy:  attendancePolicy,
		AgeMin:            req.AgeMin,
		Status:            "draft",
		CreatedAt:         time.Now(),
		UpdatedAt:         time.Now(),
	}

	if err := s.repo.Create(event); err != nil {
		return nil, fmt.Errorf("save draft event: %w", err)
	}
	var registrationDeadline *time.Time
	if req.RegistrationDeadline != nil && strings.TrimSpace(*req.RegistrationDeadline) != "" {
		if deadline, parseErr := time.Parse(time.RFC3339, *req.RegistrationDeadline); parseErr == nil {
			registrationDeadline = &deadline
		}
	}
	if err := s.repo.SaveEditorMetadata(event.ID, req.Category, req.Tags, req.VenueName, req.OnlinePlatform, registrationDeadline, req.RegistrationMode, req.Timezone, req.Guidelines); err != nil {
		return nil, fmt.Errorf("save draft editor data: %w", err)
	}

	return event, nil
}
