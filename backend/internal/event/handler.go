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
// @Summary List approved events
// @Description List all approved events with optional filters
// @Tags events
// @Accept json
// @Produce json
// @Param country query string false "Filter by country"
// @Param city query string false "Filter by city"
// @Param event_type query string false "Filter by event type"
// @Param language query string false "Filter by language"
// @Param start_date query string false "Filter by start date (RFC3339)"
// @Param end_date query string false "Filter by end date (RFC3339)"
// @Param page query int false "Page number" default(1)
// @Param page_size query int false "Page size" default(20)
// @Success 200 {object} response.PaginatedResponse
// @Router /events [get]
func (h *Handler) ListPublic(c *gin.Context) {
	filter := h.buildFilter(c)

	events, total, err := h.service.ListPublic(filter)
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}

	response.Paginated(c, events, filter.Page, filter.PageSize, total)
}

// GetByID gets an event by ID
// @Summary Get event details
// @Description Get detailed information about an event
// @Tags events
// @Accept json
// @Produce json
// @Param id path string true "Event ID"
// @Success 200 {object} models.EventWithOrganizer
// @Failure 404 {object} response.Response
// @Router /events/{id} [get]
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

	response.Success(c, event)
}

// Create creates a new event
// @Summary Create a new event
// @Description Create a new event (organizer only)
// @Tags events
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body CreateEventRequest true "Event details"
// @Success 201 {object} models.Event
// @Failure 400 {object} response.Response
// @Failure 401 {object} response.Response
// @Router /events [post]
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
// @Summary Update an event
// @Description Update an existing event (organizer only, must own the event)
// @Tags events
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path string true "Event ID"
// @Param request body UpdateEventRequest true "Event details"
// @Success 200 {object} models.Event
// @Failure 400 {object} response.Response
// @Failure 401 {object} response.Response
// @Failure 403 {object} response.Response
// @Router /events/{id} [put]
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
// @Summary Delete an event
// @Description Delete an existing event (organizer only, must own the event)
// @Tags events
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path string true "Event ID"
// @Success 200 {object} response.Response
// @Failure 400 {object} response.Response
// @Failure 401 {object} response.Response
// @Failure 403 {object} response.Response
// @Router /events/{id} [delete]
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
// @Summary Submit event for review
// @Description Submit an event for admin review (organizer only)
// @Tags events
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path string true "Event ID"
// @Success 200 {object} models.Event
// @Failure 400 {object} response.Response
// @Failure 401 {object} response.Response
// @Router /events/{id}/submit [post]
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
// @Summary Get my events
// @Description Get all events created by the current organizer
// @Tags events
// @Accept json
// @Produce json
// @Security BearerAuth
// @Success 200 {object} []models.Event
// @Failure 401 {object} response.Response
// @Router /my/events [get]
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
