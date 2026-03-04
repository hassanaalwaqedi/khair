package auth

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/response"
)

// Handler handles auth HTTP requests
type Handler struct {
	service *Service
}

// NewHandler creates a new auth handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers auth routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, loginRL, registerRL, verifyRL, resendRL gin.HandlerFunc) {
	auth := r.Group("/auth")
	{
		if registerRL != nil {
			auth.POST("/register", registerRL, h.Register)
		} else {
			auth.POST("/register", h.Register)
		}
		if loginRL != nil {
			auth.POST("/login", loginRL, h.Login)
		} else {
			auth.POST("/login", h.Login)
		}
		if verifyRL != nil {
			auth.POST("/verify-email", verifyRL, h.VerifyEmail)
		} else {
			auth.POST("/verify-email", h.VerifyEmail)
		}
		if resendRL != nil {
			auth.POST("/resend-otp", resendRL, h.ResendOTP)
		} else {
			auth.POST("/resend-otp", h.ResendOTP)
		}
		// Refresh token endpoint (public — uses refresh token for auth)
		auth.POST("/refresh", h.RefreshToken)
	}
}

// RegisterProtectedRoutes registers auth routes that require authentication
func (h *Handler) RegisterProtectedRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	me := r.Group("/me")
	me.Use(authMiddleware)
	{
		// GDPR: Data export
		me.GET("/export", h.ExportMyData)
		// GDPR: Account deletion
		me.DELETE("", h.DeleteMyAccount)
		// Logout all devices
		me.POST("/logout-all", h.LogoutAll)
	}
}

// Register handles user registration
func (h *Handler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	result, err := h.service.Register(&req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Created(c, result)
}

// Login handles user login
func (h *Handler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	result, err := h.service.Login(&req)
	if err != nil {
		response.Unauthorized(c, err.Error())
		return
	}

	response.Success(c, result)
}

// VerifyEmail handles email verification with OTP
func (h *Handler) VerifyEmail(c *gin.Context) {
	var req VerifyEmailRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	result, err := h.service.VerifyEmail(&req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, "Email verified successfully", result)
}

// ResendOTP handles resending verification OTP
func (h *Handler) ResendOTP(c *gin.Context) {
	var req ResendOTPRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	result, err := h.service.ResendOTP(&req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Success(c, result)
}

// RefreshToken handles JWT token refresh using a refresh token
// @Summary Refresh access token
// @Tags auth
// @Accept json
// @Produce json
// @Param request body RefreshTokenRequest true "Refresh token"
// @Success 200 {object} AuthResponse
// @Router /auth/refresh [post]
func (h *Handler) RefreshToken(c *gin.Context) {
	var req RefreshTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	result, err := h.service.RefreshTokens(&req, c.GetHeader("User-Agent"), c.ClientIP())
	if err != nil {
		response.Unauthorized(c, err.Error())
		return
	}

	response.Success(c, result)
}

// LogoutAll revokes all refresh tokens for the authenticated user
// @Summary Logout from all devices
// @Tags auth
// @Produce json
// @Success 200 {object} MessageResponse
// @Router /me/logout-all [post]
func (h *Handler) LogoutAll(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := userID.(uuid.UUID)

	if err := h.service.LogoutAll(uid); err != nil {
		response.InternalServerError(c, "Failed to logout")
		return
	}

	response.SuccessWithMessage(c, "All sessions revoked", nil)
}

// ExportMyData returns all user data for GDPR compliance
// @Summary Export my data (GDPR)
// @Tags gdpr
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /me/export [get]
func (h *Handler) ExportMyData(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := userID.(uuid.UUID)

	data, err := h.service.ExportMyData(uid)
	if err != nil {
		response.InternalServerError(c, "Failed to export data")
		return
	}

	response.Success(c, data)
}

// DeleteMyAccount soft-deletes and anonymizes user data
// @Summary Delete my account (GDPR)
// @Tags gdpr
// @Produce json
// @Success 200 {object} MessageResponse
// @Router /me [delete]
func (h *Handler) DeleteMyAccount(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := userID.(uuid.UUID)

	if err := h.service.DeleteMyAccount(uid); err != nil {
		response.InternalServerError(c, "Failed to delete account")
		return
	}

	response.SuccessWithMessage(c, "Account deleted. Your data has been anonymized.", nil)
}
