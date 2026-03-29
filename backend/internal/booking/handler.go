package booking

import (
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/response"
)

// Handler handles HTTP requests for the booking system.
type Handler struct {
	service *Service
}

// NewHandler creates a new booking handler.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers booking routes.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	// Public: anyone can view availability and slots
	r.GET("/sheikhs/:id/availability", h.GetAvailability)
	r.GET("/sheikhs/:id/available-slots", h.GetAvailableSlots)

	protected := r.Group("")
	protected.Use(authMiddleware)
	{
		// Sheikh: manage availability
		protected.PUT("/sheikh/availability", h.SetAvailability)
		protected.DELETE("/sheikh/availability/:day", h.DeleteAvailability)

		// Sheikh: settings
		protected.GET("/sheikh/booking-settings", h.GetBookingSettings)
		protected.PUT("/sheikh/booking-settings", h.UpdateBookingSettings)

		// Sheikh: bookings
		protected.GET("/sheikh/bookings", h.GetSheikhBookings)
		protected.POST("/bookings/:id/respond", h.RespondToBooking)

		// Sheikh: blocked times
		protected.GET("/sheikh/blocked-times", h.GetBlockedTimes)
		protected.POST("/sheikh/blocked-times", h.AddBlockedTime)
		protected.DELETE("/sheikh/blocked-times/:id", h.RemoveBlockedTime)

		// Student: bookings
		protected.POST("/bookings", h.CreateBooking)
		protected.GET("/my/bookings", h.GetMyBookings)
		protected.POST("/bookings/:id/cancel", h.CancelBooking)
	}
}

// ── Public Endpoints ──

func (h *Handler) GetAvailability(c *gin.Context) {
	sheikhID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid sheikh ID")
		return
	}

	rules, err := h.service.GetAvailability(sheikhID)
	if err != nil {
		response.InternalServerError(c, "Failed to load availability")
		return
	}
	response.Success(c, rules)
}

func (h *Handler) GetAvailableSlots(c *gin.Context) {
	sheikhID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid sheikh ID")
		return
	}

	dateStr := c.Query("date")
	if dateStr == "" {
		response.BadRequest(c, "date query parameter required (YYYY-MM-DD)")
		return
	}
	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		response.BadRequest(c, "Invalid date format, use YYYY-MM-DD")
		return
	}

	slots, err := h.service.GetAvailableSlots(sheikhID, date)
	if err != nil {
		response.InternalServerError(c, "Failed to generate slots")
		return
	}
	response.Success(c, slots)
}

// ── Sheikh Endpoints ──

type setAvailabilityBody struct {
	Rules []struct {
		DayOfWeek           int    `json:"day_of_week"`
		StartTime           string `json:"start_time" binding:"required"`
		EndTime             string `json:"end_time" binding:"required"`
		SlotDurationMinutes int    `json:"slot_duration_minutes"`
		BreakMinutes        int    `json:"break_minutes"`
		IsActive            bool   `json:"is_active"`
	} `json:"rules" binding:"required"`
}

func (h *Handler) SetAvailability(c *gin.Context) {
	var body setAvailabilityBody
	if err := c.ShouldBindJSON(&body); err != nil {
		response.BadRequest(c, "Invalid request body")
		return
	}

	sheikhID, err := h.resolveSheikhID(c)
	if err != nil {
		response.Unauthorized(c, "Not a sheikh")
		return
	}

	var rules []AvailabilityRule
	for _, r := range body.Rules {
		rules = append(rules, AvailabilityRule{
			DayOfWeek:           r.DayOfWeek,
			StartTime:           r.StartTime,
			EndTime:             r.EndTime,
			SlotDurationMinutes: r.SlotDurationMinutes,
			BreakMinutes:        r.BreakMinutes,
			IsActive:            r.IsActive,
		})
	}

	if err := h.service.SetAvailability(sheikhID, rules); err != nil {
		response.InternalServerError(c, "Failed to save availability")
		return
	}
	response.Success(c, gin.H{"message": "Availability updated"})
}

func (h *Handler) DeleteAvailability(c *gin.Context) {
	sheikhID, err := h.resolveSheikhID(c)
	if err != nil {
		response.Unauthorized(c, "Not a sheikh")
		return
	}

	day, err := strconv.Atoi(c.Param("day"))
	if err != nil {
		response.BadRequest(c, "Invalid day of week")
		return
	}

	if err := h.service.DeleteAvailability(sheikhID, day); err != nil {
		response.InternalServerError(c, "Failed to delete")
		return
	}
	response.Success(c, gin.H{"message": "Availability removed"})
}

func (h *Handler) GetBookingSettings(c *gin.Context) {
	sheikhID, err := h.resolveSheikhID(c)
	if err != nil {
		response.Unauthorized(c, "Not a sheikh")
		return
	}

	settings, err := h.service.GetSettings(sheikhID)
	if err != nil {
		response.InternalServerError(c, "Failed to load settings")
		return
	}
	response.Success(c, settings)
}

type updateSettingsBody struct {
	Timezone           string   `json:"timezone"`
	AutoApprove        bool     `json:"auto_approve"`
	PrayerBlocking     bool     `json:"prayer_blocking"`
	DefaultMeetingLink *string  `json:"default_meeting_link"`
	DefaultPlatform    *string  `json:"default_platform"`
	Latitude           *float64 `json:"latitude"`
	Longitude          *float64 `json:"longitude"`
}

func (h *Handler) UpdateBookingSettings(c *gin.Context) {
	var body updateSettingsBody
	if err := c.ShouldBindJSON(&body); err != nil {
		response.BadRequest(c, "Invalid request body")
		return
	}

	sheikhID, err := h.resolveSheikhID(c)
	if err != nil {
		response.Unauthorized(c, "Not a sheikh")
		return
	}

	settings := &BookingSettings{
		SheikhID:           sheikhID,
		Timezone:           body.Timezone,
		AutoApprove:        body.AutoApprove,
		PrayerBlocking:     body.PrayerBlocking,
		DefaultMeetingLink: body.DefaultMeetingLink,
		DefaultPlatform:    body.DefaultPlatform,
		Latitude:           body.Latitude,
		Longitude:          body.Longitude,
	}
	if settings.Timezone == "" {
		settings.Timezone = "UTC"
	}

	if err := h.service.UpdateSettings(settings); err != nil {
		response.InternalServerError(c, "Failed to update settings")
		return
	}
	response.Success(c, settings)
}

func (h *Handler) GetSheikhBookings(c *gin.Context) {
	sheikhID, err := h.resolveSheikhID(c)
	if err != nil {
		response.Unauthorized(c, "Not a sheikh")
		return
	}

	bookings, err := h.service.GetSheikhBookings(sheikhID)
	if err != nil {
		response.InternalServerError(c, "Failed to load bookings")
		return
	}
	response.Success(c, bookings)
}

type respondBody struct {
	Status string `json:"status" binding:"required"`
}

func (h *Handler) RespondToBooking(c *gin.Context) {
	var body respondBody
	if err := c.ShouldBindJSON(&body); err != nil {
		response.BadRequest(c, "status is required")
		return
	}

	bookingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid booking ID")
		return
	}

	sheikhID, err := h.resolveSheikhID(c)
	if err != nil {
		response.Unauthorized(c, "Not a sheikh")
		return
	}

	if err := h.service.RespondToBooking(bookingID, sheikhID, body.Status); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	response.Success(c, gin.H{"message": "Booking " + body.Status})
}

func (h *Handler) GetBlockedTimes(c *gin.Context) {
	sheikhID, err := h.resolveSheikhID(c)
	if err != nil {
		response.Unauthorized(c, "Not a sheikh")
		return
	}

	blocks, err := h.service.GetBlockedTimes(sheikhID)
	if err != nil {
		response.InternalServerError(c, "Failed to load blocked times")
		return
	}
	response.Success(c, blocks)
}

type addBlockedTimeBody struct {
	StartTime string `json:"start_time" binding:"required"`
	EndTime   string `json:"end_time" binding:"required"`
	Reason    string `json:"reason"`
	Note      string `json:"note"`
}

func (h *Handler) AddBlockedTime(c *gin.Context) {
	var body addBlockedTimeBody
	if err := c.ShouldBindJSON(&body); err != nil {
		response.BadRequest(c, "start_time and end_time are required")
		return
	}

	sheikhID, err := h.resolveSheikhID(c)
	if err != nil {
		response.Unauthorized(c, "Not a sheikh")
		return
	}

	startTime, err := time.Parse(time.RFC3339, body.StartTime)
	if err != nil {
		response.BadRequest(c, "Invalid start_time format")
		return
	}
	endTime, err := time.Parse(time.RFC3339, body.EndTime)
	if err != nil {
		response.BadRequest(c, "Invalid end_time format")
		return
	}

	reason := body.Reason
	if reason == "" {
		reason = "manual"
	}

	bt := &BlockedTime{
		SheikhID:  sheikhID,
		StartTime: startTime,
		EndTime:   endTime,
		Reason:    reason,
	}
	if body.Note != "" {
		bt.Note = &body.Note
	}

	if err := h.service.AddBlockedTime(bt); err != nil {
		response.InternalServerError(c, "Failed to add blocked time")
		return
	}
	response.Success(c, bt)
}

func (h *Handler) RemoveBlockedTime(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid ID")
		return
	}

	sheikhID, err := h.resolveSheikhID(c)
	if err != nil {
		response.Unauthorized(c, "Not a sheikh")
		return
	}

	if err := h.service.RemoveBlockedTime(id, sheikhID); err != nil {
		response.InternalServerError(c, "Failed to remove blocked time")
		return
	}
	response.Success(c, gin.H{"message": "Blocked time removed"})
}

// ── Student Endpoints ──

type createBookingBody struct {
	SheikhID  string `json:"sheikh_id" binding:"required"`
	StartTime string `json:"start_time" binding:"required"`
	Duration  int    `json:"duration"` // in minutes
	Notes     string `json:"notes"`
}

func (h *Handler) CreateBooking(c *gin.Context) {
	var body createBookingBody
	if err := c.ShouldBindJSON(&body); err != nil {
		response.BadRequest(c, "sheikh_id and start_time are required")
		return
	}

	sheikhID, err := uuid.Parse(body.SheikhID)
	if err != nil {
		response.BadRequest(c, "Invalid sheikh_id")
		return
	}

	startTime, err := time.Parse(time.RFC3339, body.StartTime)
	if err != nil {
		response.BadRequest(c, "Invalid start_time format (use RFC3339)")
		return
	}

	duration := body.Duration
	if duration == 0 {
		duration = 30 // default
	}

	userID := c.MustGet("user_id").(uuid.UUID)

	booking, err := h.service.CreateBooking(userID, sheikhID, startTime, duration, body.Notes)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	response.Success(c, booking)
}

func (h *Handler) GetMyBookings(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	bookings, err := h.service.GetStudentBookings(userID)
	if err != nil {
		response.InternalServerError(c, "Failed to load bookings")
		return
	}
	response.Success(c, bookings)
}

func (h *Handler) CancelBooking(c *gin.Context) {
	bookingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid booking ID")
		return
	}

	userID := c.MustGet("user_id").(uuid.UUID)

	if err := h.service.CancelBooking(bookingID, userID); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	response.Success(c, gin.H{"message": "Booking cancelled"})
}

// ── Helper ──

// resolveSheikhID looks up the sheikh_id for the current user from the DB.
func (h *Handler) resolveSheikhID(c *gin.Context) (uuid.UUID, error) {
	userID := c.MustGet("user_id").(uuid.UUID)
	return h.service.repo.GetSheikhIDByUserID(userID)
}
