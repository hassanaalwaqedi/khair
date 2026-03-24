package lesson

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/response"
)

// Handler handles lesson request HTTP endpoints
type Handler struct {
	service *Service
}

// NewHandler creates a new lesson handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers lesson request routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	protected := r.Group("")
	protected.Use(authMiddleware)
	{
		protected.POST("/lesson-requests", h.CreateRequest)
		protected.GET("/my/lesson-requests", h.GetMyRequests)
		protected.GET("/sheikh/lesson-requests", h.GetSheikhRequests)
		protected.POST("/lesson-requests/:id/respond", h.RespondToRequest)
		protected.POST("/lesson-requests/:id/schedule", h.ScheduleRequest)
	}
}

// CreateRequestBody is the request body for creating a lesson request
type CreateRequestBody struct {
	SheikhID      string  `json:"sheikh_id" binding:"required"`
	Message       string  `json:"message" binding:"required"`
	PreferredTime *string `json:"preferred_time"`
}

// CreateRequest handles POST /lesson-requests
func (h *Handler) CreateRequest(c *gin.Context) {
	var body CreateRequestBody
	if err := c.ShouldBindJSON(&body); err != nil {
		response.BadRequest(c, "sheikh_id and message are required")
		return
	}

	userID := c.MustGet("user_id").(uuid.UUID)
	sheikhID, err := uuid.Parse(body.SheikhID)
	if err != nil {
		response.BadRequest(c, "Invalid sheikh ID")
		return
	}

	var preferredTime *time.Time
	if body.PreferredTime != nil {
		t, err := time.Parse(time.RFC3339, *body.PreferredTime)
		if err == nil {
			preferredTime = &t
		}
	}

	req, err := h.service.CreateRequest(userID, sheikhID, body.Message, preferredTime)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Created(c, req)
}

// GetMyRequests handles GET /my/lesson-requests (student view)
func (h *Handler) GetMyRequests(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	reqs, err := h.service.GetStudentRequests(userID)
	if err != nil {
		response.InternalServerError(c, "Failed to load requests")
		return
	}
	if reqs == nil {
		reqs = []LessonRequest{}
	}
	response.Success(c, reqs)
}

// GetSheikhRequests handles GET /sheikh/lesson-requests (sheikh view)
func (h *Handler) GetSheikhRequests(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	reqs, err := h.service.GetSheikhRequests(userID)
	if err != nil {
		response.InternalServerError(c, "Failed to load requests")
		return
	}
	if reqs == nil {
		reqs = []LessonRequest{}
	}
	response.Success(c, reqs)
}

// RespondBody is the request body for responding to a lesson request
type RespondBody struct {
	Status string `json:"status" binding:"required"`
}

// RespondToRequest handles POST /lesson-requests/:id/respond
func (h *Handler) RespondToRequest(c *gin.Context) {
	reqID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid request ID")
		return
	}

	var body RespondBody
	if err := c.ShouldBindJSON(&body); err != nil {
		response.BadRequest(c, "Status is required (accepted or rejected)")
		return
	}

	userID := c.MustGet("user_id").(uuid.UUID)
	req, err := h.service.RespondToRequest(userID, reqID, body.Status)
	if err != nil {
		response.Error(c, http.StatusBadRequest, err.Error())
		return
	}

	response.Success(c, req)
}

// ScheduleBody is the request body for scheduling a lesson
type ScheduleBody struct {
	MeetingLink     string `json:"meeting_link" binding:"required"`
	MeetingPlatform string `json:"meeting_platform" binding:"required"`
	ScheduledTime   string `json:"scheduled_time" binding:"required"`
}

// ScheduleRequest handles POST /lesson-requests/:id/schedule
func (h *Handler) ScheduleRequest(c *gin.Context) {
	reqID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid request ID")
		return
	}

	var body ScheduleBody
	if err := c.ShouldBindJSON(&body); err != nil {
		response.BadRequest(c, "meeting_link, meeting_platform, and scheduled_time are required")
		return
	}

	scheduledTime, err := time.Parse(time.RFC3339, body.ScheduledTime)
	if err != nil {
		response.BadRequest(c, "Invalid scheduled_time format (use RFC3339)")
		return
	}

	userID := c.MustGet("user_id").(uuid.UUID)
	if err := h.service.ScheduleLesson(userID, reqID, body.MeetingLink, body.MeetingPlatform, scheduledTime); err != nil {
		response.Error(c, http.StatusBadRequest, err.Error())
		return
	}

	response.Success(c, gin.H{"message": "Lesson scheduled"})
}
