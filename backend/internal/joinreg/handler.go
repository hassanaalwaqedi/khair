package joinreg

import (
	"github.com/gin-gonic/gin"
	"github.com/khair/backend/pkg/response"
)

// Handler handles join registration HTTP endpoints
type Handler struct {
	service *Service
}

// NewHandler creates a new join registration handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers join registration routes (all public, rate-limited)
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, rateLimiter gin.HandlerFunc) {
	join := r.Group("/join-register")
	join.Use(rateLimiter)
	{
		join.POST("/step1", h.Step1)
		join.POST("/step2", h.Step2)
		join.POST("/verify", h.VerifyEmail)
	}
}

// Step1 handles name + email submission
// @Summary Register Step 1 - Name and Email
// @Description Validates name and email, creates registration draft
// @Tags join-register
// @Accept json
// @Produce json
// @Param request body Step1Request true "Name and email"
// @Success 200 {object} Step1Response
// @Failure 400 {object} response.Response
// @Failure 429 {object} response.Response
// @Router /join-register/step1 [post]
func (h *Handler) Step1(c *gin.Context) {
	var req Step1Request
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Name and email are required")
		return
	}

	result, err := h.service.ProcessStep1(&req, c.ClientIP())
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Success(c, result)
}

// Step2 handles password + gender + age submission
// @Summary Register Step 2 - Password and Profile
// @Description Finalizes registration with password, gender, and optional age
// @Tags join-register
// @Accept json
// @Produce json
// @Param request body Step2Request true "Password, gender, age"
// @Success 200 {object} Step2Response
// @Failure 400 {object} response.Response
// @Failure 429 {object} response.Response
// @Router /join-register/step2 [post]
func (h *Handler) Step2(c *gin.Context) {
	var req Step2Request
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Password and gender are required")
		return
	}

	result, _, err := h.service.ProcessStep2(&req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Success(c, result)
}

// VerifyEmail handles email verification token
// @Summary Verify Email
// @Description Verifies email and auto-confirms any pending event reservations
// @Tags join-register
// @Accept json
// @Produce json
// @Param request body object{token=string} true "Verification token"
// @Success 200 {object} response.Response
// @Failure 400 {object} response.Response
// @Router /join-register/verify [post]
func (h *Handler) VerifyEmail(c *gin.Context) {
	var req struct {
		Token string `json:"token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Verification token is required")
		return
	}

	user, err := h.service.VerifyEmail(req.Token)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, "Email verified successfully! Your event reservations are confirmed.", map[string]interface{}{
		"user_id": user.ID,
		"email":   user.Email,
		"status":  user.Status,
	})
}
