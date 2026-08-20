package reservation

import (
	"fmt"
	"log"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/internal/event"
	"github.com/khair/backend/internal/notification"
	"github.com/khair/backend/internal/push"
	"github.com/khair/backend/pkg/response"
)

// Handler handles seat reservation HTTP endpoints
type Handler struct {
	service  *Service
	notifSvc *notification.Service
	pushSvc  *push.Service
	eventSvc *event.Service
}

// NewHandler creates a new reservation handler
func NewHandler(service *Service, notifSvc *notification.Service, pushSvc *push.Service, eventSvc *event.Service) *Handler {
	return &Handler{service: service, notifSvc: notifSvc, pushSvc: pushSvc, eventSvc: eventSvc}
}

// RegisterRoutes registers reservation routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	// Public: check availability
	r.GET("/events/:id/availability", h.GetAvailability)

	// Auth-required: join, cancel, my reservations, notify attendees
	protected := r.Group("")
	protected.Use(authMiddleware)
	{
		protected.POST("/events/:id/join", h.JoinEvent)
		protected.DELETE("/events/:id/join", h.CancelJoin)
		protected.GET("/events/:id/registration-status", h.CheckRegistrationStatus)
		protected.GET("/my/reservations", h.GetMyReservations)
		protected.POST("/events/:id/notify-attendees", h.NotifyAttendees)
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

	// Send notifications in background
	go h.sendStructuredJoinNotifications(uid, eventID)

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

// getOrganizerUserID gets the user_id for an organizer
func (h *Handler) getOrganizerUserID(organizerID uuid.UUID) uuid.UUID {
	var userID uuid.UUID
	err := h.service.repo.db.QueryRow(
		`SELECT user_id FROM organizers WHERE id = $1`, organizerID,
	).Scan(&userID)
	if err != nil {
		return uuid.Nil
	}
	return userID
}

// NotifyAttendeesRequest is the request body for notifying event attendees
type NotifyAttendeesRequest struct {
	Title       string `json:"title" binding:"max=160"`
	Message     string `json:"message" binding:"required"`
	Type        string `json:"type" binding:"max=32"`
	IncludeLink bool   `json:"include_link"`
}

// NotifyAttendees sends a message to all confirmed attendees of an event
// Only the event organizer can call this endpoint
func (h *Handler) NotifyAttendees(c *gin.Context) {
	userIDRaw, ok := c.Get("user_id")
	if !ok {
		response.Unauthorized(c, "Authentication required")
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

	var req NotifyAttendeesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Message is required")
		return
	}

	// Get event and verify ownership
	evt, err := h.eventSvc.GetByID(eventID)
	if err != nil {
		response.NotFound(c, "Event not found")
		return
	}

	// Check that the caller is the organizer of this event
	orgUserID := h.getOrganizerUserID(evt.OrganizerID)
	if orgUserID != uid {
		response.Error(c, 403, "Only the event organizer can send notifications to attendees")
		return
	}

	announcementType := req.Type
	if announcementType == "" {
		announcementType = "general"
	}
	if announcementType != "general" && announcementType != "schedule_change" && announcementType != "reminder" && announcementType != "important" {
		response.BadRequest(c, "Invalid announcement type")
		return
	}
	title := req.Title
	if title == "" {
		title = fmt.Sprintf("Update from %s", evt.OrganizerName)
	}
	announcementID, err := h.service.repo.StoreAnnouncement(eventID, uid, title, announcementType, req.Message, req.IncludeLink)
	if err != nil {
		response.InternalServerError(c, "Failed to store event announcement")
		return
	}

	// Get all confirmed attendee user IDs
	attendeeIDs, err := h.service.repo.GetEventAttendeeUserIDs(eventID)
	if err != nil {
		response.InternalServerError(c, "Failed to get attendees")
		return
	}

	if len(attendeeIDs) == 0 {
		response.SuccessWithMessage(c, "No confirmed attendees to notify", nil)
		return
	}

	// Send to each attendee
	go func() {
		for _, attendeeID := range attendeeIDs {
			_ = h.service.repo.QueueAnnouncementDelivery(announcementID, attendeeID)
			inAppStatus := "delivered"
			var notificationID uuid.UUID
			created := false
			if h.notifSvc != nil {
				var err error
				notificationID, created, err = h.notifSvc.CreateTypedOnce(
					attendeeID,
					title,
					req.Message,
					"organizer_announcement",
					map[string]string{
						"type":            "organizer_announcement",
						"event_id":        eventID.String(),
						"announcement_id": announcementID.String(),
					},
					"organizer_announcement:"+announcementID.String(),
				)
				if err != nil {
					inAppStatus = "failed"
				}
			}
			_ = h.service.repo.UpdateAnnouncementDelivery(announcementID, attendeeID, inAppStatus, "dispatched")
			if h.pushSvc != nil && h.notifSvc != nil && created {
				copy, err := h.notifSvc.LocalizeForUser(attendeeID, "organizer_announcement", map[string]string{
					"event_title": evt.Title,
				})
				if err != nil {
					log.Printf("[NOTIFY] Failed to localize announcement preview: %v", err)
					continue
				}
				data := map[string]string{
					"notification_id": notificationID.String(),
					"type":            "organizer_announcement",
					"entity_type":     "event",
					"entity_id":       eventID.String(),
					"event_id":        eventID.String(),
					"announcement_id": announcementID.String(),
				}
				h.pushSvc.SendToUser(attendeeID, copy.Title, copy.Message, data)
			}
		}
		log.Printf("[NOTIFY] Sent organizer message to %d attendees for event %s", len(attendeeIDs), eventID)
	}()

	response.SuccessWithMessage(c, fmt.Sprintf("Message sent to %d attendees", len(attendeeIDs)), map[string]interface{}{
		"announcement_id":    announcementID,
		"attendees_notified": len(attendeeIDs),
	})
}
