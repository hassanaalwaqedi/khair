package reservation

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/response"
)

// Handler handles seat reservation HTTP endpoints
type Handler struct {
	service *Service
}

// NewHandler creates a new reservation handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers reservation routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	// Public: check availability
	r.GET("/events/:id/availability", h.GetAvailability)

	// Auth-required: join, cancel, my reservations
	protected := r.Group("")
	protected.Use(authMiddleware)
	{
		protected.POST("/events/:id/join", h.JoinEvent)
		protected.DELETE("/events/:id/join", h.CancelJoin)
		protected.GET("/events/:id/registration-status", h.CheckRegistrationStatus)
		protected.GET("/my/reservations", h.GetMyReservations)
	}
}

// JoinEvent reserves a seat at an event
// @Summary Join an event
// @Description Reserve a seat at an event (10 minute hold until email verification)
// @Tags reservations
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path string true "Event ID"
// @Success 200 {object} response.Response
// @Failure 400 {object} response.Response
// @Failure 401 {object} response.Response
// @Router /events/{id}/join [post]
func (h *Handler) JoinEvent(c *gin.Context) {
	userIDRaw, ok := c.Get("user_id")
	if !ok {
		response.Unauthorized(c, "Authentication required to join events")
		return
	}
	uid, ok := userIDRaw.(uuid.UUID)
	if !ok {
		response.Unauthorized(c, "Invalid user session")
		return
	}

	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	reg, err := h.service.ReserveSeat(uid, eventID)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, "Seat reserved! Verify your email to confirm.", map[string]interface{}{
		"registration_id": reg.ID,
		"status":          reg.Status,
		"reserved_until":  reg.ReservedUntil,
	})
}

// CancelJoin cancels a seat reservation
// @Summary Cancel event reservation
// @Description Cancel your seat reservation for an event
// @Tags reservations
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param id path string true "Event ID"
// @Success 200 {object} response.Response
// @Failure 400 {object} response.Response
// @Failure 401 {object} response.Response
// @Router /events/{id}/join [delete]
func (h *Handler) CancelJoin(c *gin.Context) {
	userID, ok := c.Get("user_id")
	if !ok {
		response.Unauthorized(c, "Authentication required")
		return
	}
	uid := userID.(uuid.UUID)

	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	if err := h.service.CancelReservation(uid, eventID); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, "Reservation cancelled", nil)
}

// GetAvailability checks seat availability for an event (public)
// @Summary Check event availability
// @Description Check remaining seats for a public event
// @Tags reservations
// @Produce json
// @Param id path string true "Event ID"
// @Success 200 {object} EventAvailability
// @Failure 404 {object} response.Response
// @Router /events/{id}/availability [get]
func (h *Handler) GetAvailability(c *gin.Context) {
	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	avail, err := h.service.GetEventAvailability(eventID)
	if err != nil {
		response.NotFound(c, err.Error())
		return
	}

	response.Success(c, avail)
}

// CheckRegistrationStatus checks if the user is registered for a specific event
// @Summary Check registration status
// @Description Check if the current user is registered for a specific event
// @Tags reservations
// @Produce json
// @Security BearerAuth
// @Param id path string true "Event ID"
// @Success 200 {object} response.Response
// @Router /events/{id}/registration-status [get]
func (h *Handler) CheckRegistrationStatus(c *gin.Context) {
	userID, ok := c.Get("user_id")
	if !ok {
		response.Unauthorized(c, "Authentication required")
		return
	}
	uid := userID.(uuid.UUID)

	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	status, err := h.service.CheckUserRegistration(uid, eventID)
	if err != nil {
		response.InternalServerError(c, "Failed to check registration status")
		return
	}

	response.Success(c, map[string]interface{}{
		"registered": status != "",
		"status":     status,
	})
}

// GetMyReservations gets all reservations for the current user
// @Summary Get my reservations
// @Description Get all event reservations for the current user
// @Tags reservations
// @Produce json
// @Security BearerAuth
// @Success 200 {object} response.Response
// @Failure 401 {object} response.Response
// @Router /my/reservations [get]
func (h *Handler) GetMyReservations(c *gin.Context) {
	userID, ok := c.Get("user_id")
	if !ok {
		response.Unauthorized(c, "Authentication required")
		return
	}
	uid := userID.(uuid.UUID)

	reservations, err := h.service.GetMyReservations(uid)
	if err != nil {
		response.InternalServerError(c, "Failed to load reservations")
		return
	}

	response.Success(c, reservations)
}
