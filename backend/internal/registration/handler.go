package registration

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/khair/backend/pkg/response"
)

// Handler handles registration HTTP requests
type Handler struct {
	service *Service
}

// NewHandler creates a new registration handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers registration routes (public, rate-limited)
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, registerRL gin.HandlerFunc, verifyRL gin.HandlerFunc, resendRL gin.HandlerFunc) {
	reg := r.Group("/register")
	{
		if registerRL != nil {
			reg.POST("/step1", registerRL, h.Step1)
			reg.POST("/step2", registerRL, h.Step2)
			reg.POST("/step3", registerRL, h.Step3)
			reg.POST("/step4", registerRL, h.Step4)
		} else {
			reg.POST("/step1", h.Step1)
			reg.POST("/step2", h.Step2)
			reg.POST("/step3", h.Step3)
			reg.POST("/step4", h.Step4)
		}
		if verifyRL != nil {
			reg.POST("/verify-code", verifyRL, h.VerifyCode)
		} else {
			reg.POST("/verify-code", h.VerifyCode)
		}
		if resendRL != nil {
			reg.POST("/resend-code", resendRL, h.ResendCode)
		} else {
			reg.POST("/resend-code", h.ResendCode)
		}
		reg.GET("/draft", h.LoadDraft)
		reg.POST("/suggestions", h.GetSuggestions)
	}
}

// Step1 handles role selection and credentials
// @Summary Registration Step 1 - Role & Credentials
// @Tags registration
// @Accept json
// @Produce json
// @Param request body Step1Request true "Role and credentials"
// @Success 201 {object} StepResponse
// @Router /register/step1 [post]
func (h *Handler) Step1(c *gin.Context) {
	var req Step1Request
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	result, err := h.service.ProcessStep1(&req, c.ClientIP())
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Created(c, result)
}

// Step2 handles basic profile info
// @Summary Registration Step 2 - Basic Info
// @Tags registration
// @Accept json
// @Produce json
// @Param request body Step2Request true "Basic profile info"
// @Success 200 {object} StepResponse
// @Router /register/step2 [post]
func (h *Handler) Step2(c *gin.Context) {
	var req Step2Request
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	result, err := h.service.ProcessStep2(&req, c.ClientIP())
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Success(c, result)
}

// Step3 handles role-specific info
// @Summary Registration Step 3 - Role-Specific Info
// @Tags registration
// @Accept json
// @Produce json
// @Param request body Step3Request true "Role-specific data"
// @Success 200 {object} StepResponse
// @Router /register/step3 [post]
func (h *Handler) Step3(c *gin.Context) {
	var req Step3Request
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	result, err := h.service.ProcessStep3(&req, c.ClientIP())
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Success(c, result)
}

// Step4 finalizes registration
// @Summary Registration Step 4 - Complete Registration
// @Tags registration
// @Accept json
// @Produce json
// @Param request body Step4Request true "Finalize registration"
// @Success 201 {object} RegistrationCompleteResponse
// @Router /register/step4 [post]
func (h *Handler) Step4(c *gin.Context) {
	var req Step4Request
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	result, err := h.service.ProcessStep4(&req, c.ClientIP())
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Created(c, result)
}

// VerifyCode verifies a user's email with a 6-digit code
// @Summary Verify email with code
// @Tags registration
// @Accept json
// @Produce json
// @Param request body VerifyCodeRequest true "Email and verification code"
// @Success 200 {object} map[string]interface{}
// @Router /register/verify-code [post]
func (h *Handler) VerifyCode(c *gin.Context) {
	var req VerifyCodeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	user, err := h.service.VerifyCode(&req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Success(c, map[string]interface{}{
		"user":    user,
		"message": "Email verified successfully. Your account is now active.",
	})
}

// ResendCode resends a verification code
// @Summary Resend verification code
// @Tags registration
// @Accept json
// @Produce json
// @Param request body ResendCodeRequest true "Email to resend code to"
// @Success 200 {object} map[string]interface{}
// @Router /register/resend-code [post]
func (h *Handler) ResendCode(c *gin.Context) {
	var req ResendCodeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	err := h.service.ResendCode(&req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	// Always return success to prevent email enumeration
	response.Success(c, map[string]interface{}{
		"message": "If your email is registered, a new verification code has been sent.",
	})
}

// LoadDraft loads a saved registration draft
// @Summary Load registration draft
// @Tags registration
// @Produce json
// @Param email query string true "Email to load draft for"
// @Success 200 {object} StepResponse
// @Router /register/draft [get]
func (h *Handler) LoadDraft(c *gin.Context) {
	email := c.Query("email")
	if email == "" {
		response.BadRequest(c, "Email is required")
		return
	}

	result, err := h.service.LoadDraft(email)
	if err != nil {
		response.NotFound(c, err.Error())
		return
	}

	response.Success(c, result)
}

// GetSuggestions returns smart suggestions
// @Summary Get smart registration suggestions
// @Tags registration
// @Accept json
// @Produce json
// @Success 200 {object} StepResponse
// @Router /register/suggestions [post]
func (h *Handler) GetSuggestions(c *gin.Context) {
	var req struct {
		Role string                 `json:"role" binding:"required"`
		Data map[string]interface{} `json:"data"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	result, err := h.service.GetSuggestions(req.Role, req.Data)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, "Failed to generate suggestions")
		return
	}

	response.Success(c, result)
}
