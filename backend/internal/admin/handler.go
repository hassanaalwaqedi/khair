package admin

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/middleware"
	"github.com/khair/backend/pkg/response"
)

// Handler handles admin HTTP requests
type Handler struct {
	service *Service
}

// NewHandler creates a new admin handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers admin routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	admin := r.Group("/admin")
	admin.Use(authMiddleware)
	admin.Use(middleware.AdminOnly())
	{
		// Organizer management
		admin.GET("/organizers", h.ListOrganizers)
		admin.GET("/organizers/pending", h.ListPendingOrganizers)
		admin.GET("/organizers/:id", h.GetOrganizer)
		admin.PUT("/organizers/:id/status", h.UpdateOrganizerStatus)

		// Event management
		admin.GET("/events/pending", h.ListPendingEvents)
		admin.GET("/events/:id", h.GetEvent)
		admin.PUT("/events/:id/status", h.UpdateEventStatus)
	}
}

// ListOrganizers lists all organizers
// @Summary List all organizers
// @Description List all organizers (admin only)
// @Tags admin
// @Accept json
// @Produce json
// @Security BearerAuth
// @Success 200 {object} []models.Organizer
// @Failure 401 {object} response.Response
// @Failure 403 {object} response.Response
// @Router /admin/organizers [get]
func (h *Handler) ListOrganizers(c *gin.Context) {
	organizers, err := h.service.ListAllOrganizers()
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}
	response.Success(c, organizers)
}

// ListPendingOrganizers lists pending organizers
// @Summary List pending organizers
// @Description List organizers pending approval (admin only)
// @Tags admin
// @Accept json
// @Produce json
// @Security BearerAuth
// @Success 200 {object} []models.Organizer
// @Failure 401 {object} response.Response
// @Failure 403 {object} response.Response
// @Router /admin/organizers/pending [get]
func (h *Handler) ListPendingOrganizers(c *gin.Context) {
	organizers, err := h.service.ListPendingOrganizers()
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}
	response.Success(c, organizers)
}

// GetOrganizer gets an organizer by ID
// @Summary Get organizer details
// @Description Get detailed information about an organizer (admin only)
// @Tags admin
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path string true "Organizer ID"
// @Success 200 {object} models.Organizer
// @Failure 401 {object} response.Response
// @Failure 403 {object} response.Response
// @Failure 404 {object} response.Response
// @Router /admin/organizers/{id} [get]
func (h *Handler) GetOrganizer(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid organizer ID")
		return
	}

	org, err := h.service.GetOrganizer(id)
	if err != nil {
		response.NotFound(c, "Organizer not found")
		return
	}

	response.Success(c, org)
}

// UpdateOrganizerStatus updates an organizer's status
// @Summary Update organizer status
// @Description Approve or reject an organizer (admin only)
// @Tags admin
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path string true "Organizer ID"
// @Param request body StatusUpdateRequest true "Status update"
// @Success 200 {object} models.Organizer
// @Failure 400 {object} response.Response
// @Failure 401 {object} response.Response
// @Failure 403 {object} response.Response
// @Router /admin/organizers/{id}/status [put]
func (h *Handler) UpdateOrganizerStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid organizer ID")
		return
	}

	var req StatusUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	org, err := h.service.UpdateOrganizerStatus(id, &req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, "Organizer status updated", org)
}

// ListPendingEvents lists pending events
// @Summary List pending events
// @Description List events pending approval (admin only)
// @Tags admin
// @Accept json
// @Produce json
// @Security BearerAuth
// @Success 200 {object} []models.EventWithOrganizer
// @Failure 401 {object} response.Response
// @Failure 403 {object} response.Response
// @Router /admin/events/pending [get]
func (h *Handler) ListPendingEvents(c *gin.Context) {
	events, err := h.service.ListPendingEvents()
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}
	response.Success(c, events)
}

// GetEvent gets an event by ID
// @Summary Get event details
// @Description Get detailed information about an event (admin only)
// @Tags admin
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path string true "Event ID"
// @Success 200 {object} models.EventWithOrganizer
// @Failure 401 {object} response.Response
// @Failure 403 {object} response.Response
// @Failure 404 {object} response.Response
// @Router /admin/events/{id} [get]
func (h *Handler) GetEvent(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	event, err := h.service.GetEvent(id)
	if err != nil {
		response.NotFound(c, "Event not found")
		return
	}

	response.Success(c, event)
}

// UpdateEventStatus updates an event's status
// @Summary Update event status
// @Description Approve or reject an event (admin only)
// @Tags admin
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path string true "Event ID"
// @Param request body StatusUpdateRequest true "Status update"
// @Success 200 {object} models.EventWithOrganizer
// @Failure 400 {object} response.Response
// @Failure 401 {object} response.Response
// @Failure 403 {object} response.Response
// @Router /admin/events/{id}/status [put]
func (h *Handler) UpdateEventStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	var req StatusUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	event, err := h.service.UpdateEventStatus(id, &req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, "Event status updated", event)
}
