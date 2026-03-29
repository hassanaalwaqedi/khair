package event

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

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
	}

	// Protected routes — auth-aware event details (shows join status + online link)
	authEvents := r.Group("/events")
	authEvents.Use(authMiddleware)
	{
		authEvents.GET("/:id/details", h.GetByIDAuth)
	}

	// Protected routes for organizers
	protected := r.Group("/events")
	protected.Use(authMiddleware)
	protected.Use(middleware.OrganizerOnly())
	{
		protected.POST("", h.Create)
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

// ListPublic lists approved events
func (h *Handler) ListPublic(c *gin.Context) {
	filter := h.buildFilter(c)

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
	ID                           uuid.UUID  `json:"id"`
	OrganizerID                  uuid.UUID  `json:"organizer_id"`
	Title                        string     `json:"title"`
	Description                  *string    `json:"description,omitempty"`
	EventType                    string     `json:"event_type"`
	Language                     *string    `json:"language,omitempty"`
	Country                      *string    `json:"country,omitempty"`
	City                         *string    `json:"city,omitempty"`
	Address                      *string    `json:"address,omitempty"`
	Latitude                     *float64   `json:"latitude,omitempty"`
	Longitude                    *float64   `json:"longitude,omitempty"`
	StartDate                    time.Time  `json:"start_date"`
	EndDate                      *time.Time `json:"end_date,omitempty"`
	ImageURL                     *string    `json:"image_url,omitempty"`
	Capacity                     *int       `json:"capacity,omitempty"`
	ReservedCount                int        `json:"reserved_count"`
	GenderRestriction            *string    `json:"gender_restriction,omitempty"`
	AgeMin                       *int       `json:"age_min,omitempty"`
	AgeMax                       *int       `json:"age_max,omitempty"`
	TicketPrice                  *float64   `json:"ticket_price,omitempty"`
	Currency                     *string    `json:"currency,omitempty"`
	Status                       string     `json:"status"`
	IsPublished                  bool       `json:"is_published"`
	IsOnline                     bool       `json:"is_online"`
	OnlineLink                   *string    `json:"online_link,omitempty"`
	JoinInstructions             *string    `json:"join_instructions,omitempty"`
	JoinLinkVisibleBeforeMinutes int        `json:"join_link_visible_before_minutes"`
	RejectionReason              *string    `json:"rejection_reason,omitempty"`
	ApprovedAt                   *time.Time `json:"approved_at,omitempty"`
	CreatedAt                    time.Time  `json:"created_at"`
	UpdatedAt                    time.Time  `json:"updated_at"`
	OrganizerName                string     `json:"organizer_name"`
	// User-specific fields
	IsUserJoined  bool `json:"is_user_joined"`
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
		response.NotFound(c, "Event not found")
		return
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
		AgeMin:                       event.AgeMin,
		AgeMax:                       event.AgeMax,
		TicketPrice:                  event.TicketPrice,
		Currency:                     event.Currency,
		Status:                       event.Status,
		IsPublished:                  event.IsPublished,
		IsOnline:                     event.IsOnline,
		OnlineLink:                   onlineLink,
		JoinInstructions:             event.JoinInstructions,
		JoinLinkVisibleBeforeMinutes: event.JoinLinkVisibleBeforeMinutes,
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
func (h *Handler) buildFilter(c *gin.Context) *EventFilter {
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

	if language := c.Query("language"); language != "" {
		filter.Language = &language
	}

	if startDate := c.Query("start_date"); startDate != "" {
		if t, err := time.Parse(time.RFC3339, startDate); err == nil {
			filter.StartDate = &t
		}
	}

	if endDate := c.Query("end_date"); endDate != "" {
		if t, err := time.Parse(time.RFC3339, endDate); err == nil {
			filter.EndDate = &t
		}
	}

	if search := c.Query("search"); search != "" {
		filter.Search = &search
	}

	if c.Query("trending") == "true" {
		filter.Trending = true
	}

	return filter
}
