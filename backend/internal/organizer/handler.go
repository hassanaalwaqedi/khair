package organizer

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/middleware"
	"github.com/khair/backend/pkg/response"
)

// Handler handles organizer HTTP requests
type Handler struct {
	service *Service
}

// NewHandler creates a new organizer handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers organizer routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	// Public routes
	organizers := r.Group("/organizers")
	{
		organizers.GET("/:id", h.GetByID)
	}

	// Protected routes
	protected := r.Group("/organizers")
	protected.Use(authMiddleware)
	protected.Use(middleware.OrganizerOnly())
	{
		protected.GET("/me", h.GetMyProfile)
		protected.PUT("/me", h.UpdateMyProfile)
		protected.GET("/me/messages", h.GetMessages)
		protected.PUT("/me/messages/:messageId/read", h.MarkMessageRead)
	}

	// Organizer registration (auth required, no organizer-only check)
	authGroup := r.Group("/auth")
	authGroup.Use(authMiddleware)
	{
		authGroup.POST("/register-organizer", h.RegisterAsOrganizer)
	}
}

// GetByID gets an organizer by ID
// @Summary Get organizer details
// @Description Get public information about an organizer
// @Tags organizers
// @Accept json
// @Produce json
// @Param id path string true "Organizer ID"
// @Success 200 {object} models.Organizer
// @Failure 404 {object} response.Response
// @Router /organizers/{id} [get]
func (h *Handler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid organizer ID")
		return
	}

	org, err := h.service.GetByID(id)
	if err != nil {
		response.NotFound(c, "Organizer not found")
		return
	}

	// Only show approved organizers publicly
	if org.Status != "approved" {
		response.NotFound(c, "Organizer not found")
		return
	}

	response.Success(c, org)
}

// GetMyProfile gets the current organizer's profile
// @Summary Get my profile
// @Description Get the current organizer's profile
// @Tags organizers
// @Accept json
// @Produce json
// @Security BearerAuth
// @Success 200 {object} models.Organizer
// @Failure 401 {object} response.Response
// @Router /organizers/me [get]
func (h *Handler) GetMyProfile(c *gin.Context) {
	userIDVal, _ := c.Get("user_id")
	userID, _ := userIDVal.(uuid.UUID)

	org, err := h.service.GetMyProfile(userID)
	if err != nil {
		response.NotFound(c, "Profile not found")
		return
	}

	response.Success(c, org)
}

// UpdateMyProfile updates the current organizer's profile
// @Summary Update my profile
// @Description Update the current organizer's profile
// @Tags organizers
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body UpdateProfileRequest true "Profile details"
// @Success 200 {object} models.Organizer
// @Failure 400 {object} response.Response
// @Failure 401 {object} response.Response
// @Router /organizers/me [put]
func (h *Handler) UpdateMyProfile(c *gin.Context) {
	var req UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	userIDVal, _ := c.Get("user_id")
	userID, _ := userIDVal.(uuid.UUID)

	org, err := h.service.UpdateProfile(userID, &req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Success(c, org)
}

// GetMessages returns messages for the current organizer
func (h *Handler) GetMessages(c *gin.Context) {
	// Return empty messages list until full messaging is built
	response.Success(c, []interface{}{})
}

// MarkMessageRead marks a message as read
func (h *Handler) MarkMessageRead(c *gin.Context) {
	response.SuccessWithMessage(c, "Message marked as read", nil)
}

// RegisterAsOrganizer handles organizer registration from an authenticated user
func (h *Handler) RegisterAsOrganizer(c *gin.Context) {
	var req struct {
		OrganizationName string `json:"organization_name" binding:"required"`
		Description      string `json:"description"`
		Country          string `json:"country"`
		City             string `json:"city"`
		ContactEmail     string `json:"contact_email"`
		Website          string `json:"website"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	userIDVal, _ := c.Get("user_id")
	userID, _ := userIDVal.(uuid.UUID)

	org, err := h.service.RegisterAsOrganizer(userID, req.OrganizationName, req.Description, req.Country, req.City, req.ContactEmail, req.Website)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Created(c, org)
}
