package sheikh

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/response"
)

// Handler handles sheikh directory HTTP endpoints
type Handler struct {
	service *Service
}

// NewHandler creates a new sheikh handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers sheikh directory routes (public)
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	r.GET("/sheikhs", h.ListSheikhs)
	r.GET("/sheikhs/:id/reviews", h.GetReviews)
}

// RegisterAuthRoutes registers auth-required sheikh routes
func (h *Handler) RegisterAuthRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	auth := r.Group("")
	auth.Use(authMiddleware)
	auth.POST("/sheikhs/:id/review", h.CreateReview)
	auth.POST("/sheikhs/:id/report", h.ReportSheikh)
}

// RegisterAdminRoutes registers admin-only sheikh routes
func (h *Handler) RegisterAdminRoutes(r *gin.RouterGroup, authMiddleware, adminMiddleware gin.HandlerFunc) {
	admin := r.Group("")
	admin.Use(authMiddleware)
	admin.Use(adminMiddleware)
	admin.GET("/admin/sheikh-reports", h.ListReports)
}

// ListSheikhs returns all public sheikh profiles
func (h *Handler) ListSheikhs(c *gin.Context) {
	sheikhs, err := h.service.ListSheikhs()
	if err != nil {
		response.InternalServerError(c, "Failed to load sheikhs")
		return
	}
	if sheikhs == nil {
		sheikhs = []SheikhProfile{}
	}
	response.Success(c, sheikhs)
}

// CreateReview handles POST /sheikhs/:id/review
func (h *Handler) CreateReview(c *gin.Context) {
	sheikhID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.Error(c, http.StatusBadRequest, "Invalid sheikh ID")
		return
	}

	userIDVal, _ := c.Get("user_id")
	studentID, ok := userIDVal.(uuid.UUID)
	if !ok {
		response.Error(c, http.StatusUnauthorized, "Invalid user")
		return
	}

	var body struct {
		Rating          int     `json:"rating" binding:"required"`
		Comment         string  `json:"comment"`
		LessonRequestID *string `json:"lesson_request_id"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		response.Error(c, http.StatusBadRequest, "Rating is required (1-5)")
		return
	}

	var lessonReqID *uuid.UUID
	if body.LessonRequestID != nil && *body.LessonRequestID != "" {
		parsed, err := uuid.Parse(*body.LessonRequestID)
		if err == nil {
			lessonReqID = &parsed
		}
	}

	if err := h.service.CreateReview(studentID, sheikhID, lessonReqID, body.Rating, body.Comment); err != nil {
		msg := err.Error()
		if strings.Contains(msg, "must have") || strings.Contains(msg, "already reviewed") || strings.Contains(msg, "between 1 and 5") {
			response.Error(c, http.StatusBadRequest, msg)
		} else {
			response.InternalServerError(c, "Failed to create review")
		}
		return
	}
	response.Success(c, gin.H{"message": "Review submitted"})
}

// GetReviews handles GET /sheikhs/:id/reviews
func (h *Handler) GetReviews(c *gin.Context) {
	sheikhID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.Error(c, http.StatusBadRequest, "Invalid sheikh ID")
		return
	}

	reviews, err := h.service.GetReviews(sheikhID)
	if err != nil {
		response.InternalServerError(c, "Failed to load reviews")
		return
	}
	response.Success(c, reviews)
}

// ReportSheikh handles POST /sheikhs/:id/report
func (h *Handler) ReportSheikh(c *gin.Context) {
	sheikhID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.Error(c, http.StatusBadRequest, "Invalid sheikh ID")
		return
	}

	userIDVal, _ := c.Get("user_id")
	reporterID, ok := userIDVal.(uuid.UUID)
	if !ok {
		response.Error(c, http.StatusUnauthorized, "Invalid user")
		return
	}

	var body struct {
		Reason string `json:"reason" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		response.Error(c, http.StatusBadRequest, "Reason is required")
		return
	}

	if err := h.service.ReportSheikh(reporterID, sheikhID, body.Reason); err != nil {
		msg := err.Error()
		if strings.Contains(msg, "required") || strings.Contains(msg, "limit") {
			response.Error(c, http.StatusBadRequest, msg)
		} else {
			response.InternalServerError(c, "Failed to submit report")
		}
		return
	}
	response.Success(c, gin.H{"message": "Report submitted"})
}

// ListReports handles GET /admin/sheikh-reports (admin only)
func (h *Handler) ListReports(c *gin.Context) {
	reports, err := h.service.ListReports()
	if err != nil {
		response.InternalServerError(c, "Failed to load reports")
		return
	}
	response.Success(c, reports)
}
