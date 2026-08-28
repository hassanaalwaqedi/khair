package event

import (
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/internal/eligibility"
	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/pkg/config"
	"github.com/khair/backend/pkg/middleware"
	"github.com/khair/backend/pkg/response"
)

// Handler handles event HTTP requests
type Handler struct {
	service  *Service
	mapAlias MapAliasHandler
	cfg      *config.Config
}

// MapAliasHandler delegates special map aliases under /events/:id.
type MapAliasHandler interface {
	FindNearby(c *gin.Context)
	GetFilterOptions(c *gin.Context)
}

// NewHandler creates a new event handler.
func NewHandler(service *Service, mapAlias MapAliasHandler, cfg *config.Config) *Handler {
	return &Handler{
		service:  service,
		mapAlias: mapAlias,
		cfg:      cfg,
	}
}

// RegisterRoutes registers event routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	// Public routes
	events := r.Group("/events")
	{
		events.GET("", h.ListPublic)
		events.GET("/:id", h.GetByID)
		events.POST("/:id/view", h.RecordView)
	}

	// Protected routes — auth-aware event details (shows join status + online link)
	authEvents := r.Group("/events")
	authEvents.Use(authMiddleware)
	{
		authEvents.GET("/:id/details", h.GetByIDAuth)
		authEvents.GET("/:id/meeting-access", h.GetMeetingAccess)
		authEvents.GET("/:id/saved", h.GetSavedStatus)
		authEvents.POST("/:id/save", h.SaveEvent)
		authEvents.DELETE("/:id/save", h.UnsaveEvent)
	}
	me := r.Group("/me")
	me.Use(authMiddleware)
	me.GET("/saved-events", h.GetSavedEvents)

	// Protected routes for organizers
	protected := r.Group("/events")
	protected.Use(authMiddleware)
	protected.Use(middleware.OrganizerOnly())
	{
		protected.POST("", h.Create)
		protected.POST("/draft", h.CreateDraft)
		protected.PUT("/:id", h.Update)
		protected.DELETE("/:id", h.Delete)
		protected.POST("/:id/submit", h.SubmitForReview)
	}

	// My events route
	my := r.Group("/my")
	my.Use(authMiddleware)
	my.Use(middleware.OrganizerOnly())
	{
		my.GET("/events", h.GetMyEvents)
	}
}

type recordViewRequest struct {
	SessionID string `json:"session_id" binding:"required,max=128"`
}

// RecordView stores a genuine event-detail view. The client-generated session
// id avoids needing browser cookies and is used only for aggregate analytics.
func (h *Handler) RecordView(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}
	var req recordViewRequest
	if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.SessionID) == "" {
		response.BadRequest(c, "A valid session ID is required")
		return
	}
	if err := h.service.RecordView(id, strings.TrimSpace(req.SessionID)); err != nil {
		if strings.Contains(err.Error(), "not found") {
			response.NotFound(c, "Event not found")
			return
		}
		response.InternalServerError(c, "Failed to record event view")
		return
	}
	c.Status(http.StatusNoContent)
}

// GetSavedStatus returns the authenticated user's saved state for an event.
func (h *Handler) GetSavedStatus(c *gin.Context) {
	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}
	saved, err := h.service.IsSaved(c.MustGet("user_id").(uuid.UUID), eventID)
	if err != nil {
		response.InternalServerError(c, "Could not check saved event")
		return
	}
	response.Success(c, gin.H{"saved": saved})
}

// SaveEvent persists an event in the current user's saved list.
func (h *Handler) SaveEvent(c *gin.Context) {
	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}
	if err := h.service.SaveEvent(c.MustGet("user_id").(uuid.UUID), eventID); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	response.Success(c, gin.H{"saved": true})
}

// UnsaveEvent removes an event from the current user's saved list.
func (h *Handler) UnsaveEvent(c *gin.Context) {
	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}
	if err := h.service.UnsaveEvent(c.MustGet("user_id").(uuid.UUID), eventID); err != nil {
		response.InternalServerError(c, "Could not remove saved event")
		return
	}
	response.Success(c, gin.H{"saved": false})
}

// GetSavedEvents lists real saved events for the authenticated member.
func (h *Handler) GetSavedEvents(c *gin.Context) {
	items, err := h.service.GetSavedEvents(c.MustGet("user_id").(uuid.UUID))
	if err != nil {
		response.InternalServerError(c, "Could not load saved events")
		return
	}
	response.Success(c, items)
}

// ListPublic lists approved events
func (h *Handler) ListPublic(c *gin.Context) {
	filter, err := h.buildFilter(c)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	events, total, err := h.service.ListPublic(filter)
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}

	// Strip online_link from public list responses for security
	for i := range events {
		events[i].OnlineLink = nil
	}

	response.Paginated(c, events, filter.Page, filter.PageSize, total)
}

// GetByID gets an event by ID (public — no online link exposed)
func (h *Handler) GetByID(c *gin.Context) {
	idParam := c.Param("id")
	if h.mapAlias != nil {
		switch idParam {
		case "nearby":
			h.mapAlias.FindNearby(c)
			return
		case "filter-options":
			h.mapAlias.GetFilterOptions(c)
			return
		}
	}

	id, err := uuid.Parse(idParam)
	if err != nil {
		response.Error(c, http.StatusBadRequest, "Invalid event ID")
		return
	}

	event, err := h.service.GetByID(id)
	if err != nil {
		response.NotFound(c, "Event not found")
		return
	}

	// Only show approved events publicly
	if event.Status != "approved" {
		response.NotFound(c, "Event not found")
		return
	}

	// Strip online_link from public response for security
	event.OnlineLink = nil

	response.Success(c, event)
}

// EventDetailResponse extends EventWithOrganizer with user-specific fields
type EventDetailResponse struct {
	ID                           uuid.UUID           `json:"id"`
	OrganizerID                  uuid.UUID           `json:"organizer_id"`
	Title                        string              `json:"title"`
	Description                  *string             `json:"description,omitempty"`
	EventType                    string              `json:"event_type"`
	Category                     string              `json:"category"`
	Tags                         []string            `json:"tags,omitempty"`
	Language                     *string             `json:"language,omitempty"`
	Country                      *string             `json:"country,omitempty"`
	City                         *string             `json:"city,omitempty"`
	Address                      *string             `json:"address,omitempty"`
	Latitude                     *float64            `json:"latitude,omitempty"`
	Longitude                    *float64            `json:"longitude,omitempty"`
	StartDate                    time.Time           `json:"start_date"`
	EndDate                      *time.Time          `json:"end_date,omitempty"`
	ImageURL                     *string             `json:"image_url,omitempty"`
	Capacity                     *int                `json:"capacity,omitempty"`
	ReservedCount                int                 `json:"reserved_count"`
	GenderRestriction            *string             `json:"gender_restriction,omitempty"`
	AttendancePolicy             string              `json:"attendance_policy"`
	AgeMin                       *int                `json:"age_min,omitempty"`
	AgeMax                       *int                `json:"age_max,omitempty"`
	Pricing                      *models.PricingInfo `json:"pricing,omitempty"`
	Status                       string              `json:"status"`
	IsPublished                  bool                `json:"is_published"`
	IsOnline                     bool                `json:"is_online"`
	OnlineLink                   *string             `json:"online_link,omitempty"`
	JoinInstructions             *string             `json:"join_instructions,omitempty"`
	JoinLinkVisibleBeforeMinutes int                 `json:"join_link_visible_before_minutes"`
	VenueName                    *string             `json:"venue_name,omitempty"`
	OnlinePlatform               *string             `json:"online_platform,omitempty"`
	RegistrationDeadline         *time.Time          `json:"registration_deadline,omitempty"`
	RegistrationMode             string              `json:"registration_mode"`
	Timezone                     string              `json:"timezone"`
	RejectionReason              *string             `json:"rejection_reason,omitempty"`
	ApprovedAt                   *time.Time          `json:"approved_at,omitempty"`
	CreatedAt                    time.Time           `json:"created_at"`
	UpdatedAt                    time.Time           `json:"updated_at"`
	OrganizerName                string              `json:"organizer_name"`
	// User-specific fields
	IsUserJoined   bool `json:"is_user_joined"`
	IsLinkUnlocked bool `json:"is_link_unlocked"`
}

// GetByIDAuth gets event details for authenticated users — includes join status and conditional online link
func (h *Handler) GetByIDAuth(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.Error(c, http.StatusBadRequest, "Invalid event ID")
		return
	}

	event, err := h.service.GetByID(id)
	if err != nil {
		response.NotFound(c, "Event not found")
		return
	}

	if event.Status != "approved" {
		isAdmin := false
		if rolesVal, exists := c.Get("roles"); exists {
			if roles, ok := rolesVal.([]string); ok {
				for _, r := range roles {
					if r == "admin" || r == "super_admin" {
						isAdmin = true
						break
					}
				}
			}
		} else if roleVal, exists := c.Get("role"); exists {
			if role, ok := roleVal.(string); ok && (role == "admin" || role == "super_admin") {
				isAdmin = true
			}
		}

		if !isAdmin {
			response.NotFound(c, "Event not found")
			return
		}
	}

	userID := c.MustGet("user_id").(uuid.UUID)

	// Check user registration
	regStatus, _ := h.service.repo.CheckUserRegistration(userID, id)
	isJoined := regStatus == "confirmed"

	// Determine if link should be visible
	isLinkUnlocked := false
	var onlineLink *string
	if event.IsOnline && isJoined && event.OnlineLink != nil {
		unlockTime := event.StartDate.Add(-time.Duration(event.JoinLinkVisibleBeforeMinutes) * time.Minute)
		if time.Now().After(unlockTime) {
			isLinkUnlocked = true
			onlineLink = event.OnlineLink
		}
	}

	resp := EventDetailResponse{
		ID:                           event.ID,
		OrganizerID:                  event.OrganizerID,
		Title:                        event.Title,
		Description:                  event.Description,
		EventType:                    event.EventType,
		Category:                     event.Category,
		Tags:                         event.Tags,
		Language:                     event.Language,
		Country:                      event.Country,
		City:                         event.City,
		Address:                      event.Address,
		Latitude:                     event.Latitude,
		Longitude:                    event.Longitude,
		StartDate:                    event.StartDate,
		EndDate:                      event.EndDate,
		ImageURL:                     event.ImageURL,
		Capacity:                     event.Capacity,
		ReservedCount:                event.ReservedCount,
		GenderRestriction:            event.GenderRestriction,
		AttendancePolicy:             event.AttendancePolicy,
		AgeMin:                       event.AgeMin,
		AgeMax:                       event.AgeMax,
		Pricing:                      event.Pricing,
		Status:                       event.Status,
		IsPublished:                  event.IsPublished,
		IsOnline:                     event.IsOnline,
		OnlineLink:                   onlineLink,
		JoinInstructions:             event.JoinInstructions,
		JoinLinkVisibleBeforeMinutes: event.JoinLinkVisibleBeforeMinutes,
		VenueName:                    event.VenueName,
		OnlinePlatform:               event.OnlinePlatform,
		RegistrationDeadline:         event.RegistrationDeadline,
		RegistrationMode:             event.RegistrationMode,
		Timezone:                     event.Timezone,
		RejectionReason:              event.RejectionReason,
		ApprovedAt:                   event.ApprovedAt,
		CreatedAt:                    event.CreatedAt,
		UpdatedAt:                    event.UpdatedAt,
		OrganizerName:                event.OrganizerName,
		IsUserJoined:                 isJoined,
		IsLinkUnlocked:               isLinkUnlocked,
	}

	response.Success(c, resp)
}

// MeetingAccessResponse represents the secure meeting link payload
type MeetingAccessResponse struct {
	Available bool   `json:"available"`
	Provider  string `json:"provider,omitempty"`
	URL       string `json:"url,omitempty"`
}

// GetMeetingAccess returns the meeting URL for an online event if the user is authorized.
func (h *Handler) GetMeetingAccess(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.Error(c, http.StatusBadRequest, "Invalid event ID")
		return
	}

	event, err := h.service.GetByID(id)
	if err != nil {
		response.NotFound(c, "Event not found")
		return
	}

	if !event.IsOnline {
		response.BadRequest(c, "Not an online event")
		return
	}

	userID := c.MustGet("user_id").(uuid.UUID)

	isAuthorized := false

	// Organizer check
	if event.OrganizerID == userID {
		isAuthorized = true
	} else if org, err := h.service.organizerRepo.GetByID(event.OrganizerID); err == nil && org.UserID == userID {
		isAuthorized = true
	}

	// Attendee check (if not already authorized)
	if !isAuthorized {
		regStatus, _ := h.service.repo.CheckUserRegistration(userID, id)
		if regStatus == "confirmed" {
			isAuthorized = true
		}
	}

	// Admin check (if we had an easy admin role check on the context, we would do it here.
	// For now, rely on organizer/attendee logic).

	if !isAuthorized {
		response.Error(c, http.StatusForbidden, "Not authorized to access meeting link")
		return
	}

	if event.OnlineLink == nil || *event.OnlineLink == "" {
		response.Success(c, MeetingAccessResponse{
			Available: false,
		})
		return
	}

	provider := "unknown"
	if event.OnlinePlatform != nil {
		provider = *event.OnlinePlatform
	}

	response.Success(c, MeetingAccessResponse{
		Available: true,
		Provider:  provider,
		URL:       *event.OnlineLink,
	})
}

// Create creates a new event
func (h *Handler) Create(c *gin.Context) {
	var req CreateEventRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	userID := c.MustGet("user_id").(uuid.UUID)

	event, err := h.service.Create(userID, &req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Created(c, event)
}

// CreateDraft creates an authenticated organizer-owned draft. It uses a
// relaxed request struct so that partially-filled forms can be auto-saved
// without validation failures.
func (h *Handler) CreateDraft(c *gin.Context) {
	var draft DraftEventRequest
	if err := c.ShouldBindJSON(&draft); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	// Convert the relaxed draft request into a CreateEventRequest with safe
	// defaults so the downstream service logic works unchanged.
	req := draft.toCreateRequest()

	userID := c.MustGet("user_id").(uuid.UUID)
	event, err := h.service.CreateDraft(userID, &req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Created(c, event)
}

// Update updates an event
func (h *Handler) Update(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	var req UpdateEventRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	userID := c.MustGet("user_id").(uuid.UUID)

	event, err := h.service.Update(userID, id, &req)
	if err != nil {
		var eligibilityErr *eligibility.Error
		if errors.As(err, &eligibilityErr) {
			response.ErrorWithCode(c, eligibilityErr.HTTPStatus, eligibilityErr.Code, eligibilityErr.Message)
			return
		}
		response.BadRequest(c, err.Error())
		return
	}

	response.Success(c, event)
}

// Delete deletes an event
func (h *Handler) Delete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	userID := c.MustGet("user_id").(uuid.UUID)

	if err := h.service.Delete(userID, id); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, "Event deleted successfully", nil)
}

// SubmitForReview submits an event for admin review
func (h *Handler) SubmitForReview(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	userID := c.MustGet("user_id").(uuid.UUID)

	event, err := h.service.SubmitForReview(userID, id)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, "Event submitted for review", event)
}

// GetMyEvents gets events for the current organizer
func (h *Handler) GetMyEvents(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	events, err := h.service.GetMyEvents(userID)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Success(c, events)
}

// buildFilter creates an EventFilter from query parameters
func (h *Handler) buildFilter(c *gin.Context) (*EventFilter, error) {
	filter := &EventFilter{
		Page:     1,
		PageSize: 20,
	}

	if page := c.Query("page"); page != "" {
		if p, err := strconv.Atoi(page); err == nil && p > 0 {
			filter.Page = p
		}
	}

	if pageSize := c.Query("page_size"); pageSize != "" {
		if ps, err := strconv.Atoi(pageSize); err == nil && ps > 0 && ps <= 100 {
			filter.PageSize = ps
		}
	}

	if country := c.Query("country"); country != "" {
		filter.Country = &country
	}

	if city := c.Query("city"); city != "" {
		filter.City = &city
	}

	if eventType := c.Query("event_type"); eventType != "" {
		filter.EventType = &eventType
	}

	if category := c.Query("category"); category != "" {
		filter.Category = &category
	}

	if language := c.Query("language"); language != "" {
		filter.Language = &language
	}

	if online := c.Query("is_online"); online != "" {
		if value, err := strconv.ParseBool(online); err == nil {
			filter.IsOnline = &value
		} else {
			return nil, fmt.Errorf("invalid is_online filter")
		}
	}

	if c.Query("free") == "true" {
		filter.FreeOnly = true
	}

	timezone := c.Query("timezone")
	if date := c.Query("date"); date != "" {
		if err := applyDatePreset(filter, date, timezone, time.Now()); err != nil {
			return nil, err
		}
	}

	if c.Query("date") == "" {
		if startDate := c.Query("start_date"); startDate != "" {
			t, err := parseQueryTime(startDate, timezone)
			if err != nil {
				return nil, err
			}
			filter.StartDate = &t
		}

		if endDate := c.Query("end_date"); endDate != "" {
			t, err := parseQueryTime(endDate, timezone)
			if err != nil {
				return nil, err
			}
			filter.EndDate = &t
		}
	}

	if pricingType := c.Query("pricing_type"); pricingType != "" {
		if pricingType != "free" && pricingType != "paid" {
			return nil, fmt.Errorf("invalid pricing_type filter")
		}
		filter.PricingType = &pricingType
	}

	if lat, lng := c.Query("lat"), c.Query("lng"); lat != "" || lng != "" {
		parsedLat, errLat := strconv.ParseFloat(lat, 64)
		parsedLng, errLng := strconv.ParseFloat(lng, 64)
		if errLat != nil || errLng != nil || parsedLat < -90 || parsedLat > 90 || parsedLng < -180 || parsedLng > 180 {
			return nil, fmt.Errorf("invalid location filter")
		}
		filter.Latitude = &parsedLat
		filter.Longitude = &parsedLng
		radius := 10.0
		if rawRadius := c.Query("radius"); rawRadius != "" {
			parsedRadius, err := strconv.ParseFloat(rawRadius, 64)
			if err != nil || parsedRadius <= 0 || parsedRadius > 200 {
				return nil, fmt.Errorf("invalid radius filter")
			}
			radius = parsedRadius
		}
		filter.RadiusKm = &radius
	} else if c.Query("radius") != "" {
		return nil, fmt.Errorf("lat and lng are required for radius filtering")
	}

	if search := c.Query("search"); search != "" {
		filter.Search = &search
	}

	if c.Query("trending") == "true" {
		filter.Trending = true
	}

	return filter, nil
}
