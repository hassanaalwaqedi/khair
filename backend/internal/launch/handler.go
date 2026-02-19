package launch

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Handler provides launch control API endpoints
type Handler struct {
	service *Service
}

// NewHandler creates a new launch control handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers launch control admin routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware, adminMiddleware gin.HandlerFunc) {
	admin := r.Group("/admin/launch")
	admin.Use(authMiddleware, adminMiddleware)
	{
		admin.GET("/config", h.GetConfig)
		admin.PUT("/config", h.UpdateConfig)
		admin.GET("/invites", h.ListInvites)
		admin.POST("/invites", h.CreateInvite)
		admin.DELETE("/invites/:code", h.RevokeInvite)
	}
}

// GetConfig returns current launch configuration
// GET /admin/launch/config
func (h *Handler) GetConfig(c *gin.Context) {
	config := h.service.GetConfig(c.Request.Context())

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    config,
	})
}

// UpdateConfigRequest is the request body for updating config
type UpdateConfigRequest struct {
	LaunchCountryCode *string `json:"launch_country_code"`
	CountryRestricted *bool   `json:"country_restricted"`
	MaxOrganizers     *int    `json:"max_organizers"`
	OrganizerLimited  *bool   `json:"organizer_limited"`
	InviteOnlyMode    *bool   `json:"invite_only_mode"`
}

// UpdateConfig updates launch configuration
// PUT /admin/launch/config
func (h *Handler) UpdateConfig(c *gin.Context) {
	var req UpdateConfigRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"error":   "Invalid request body",
		})
		return
	}

	updates := make(map[string]interface{})
	if req.LaunchCountryCode != nil {
		updates["launch_country_code"] = *req.LaunchCountryCode
	}
	if req.CountryRestricted != nil {
		updates["country_restricted"] = *req.CountryRestricted
	}
	if req.MaxOrganizers != nil {
		updates["max_organizers"] = *req.MaxOrganizers
	}
	if req.OrganizerLimited != nil {
		updates["organizer_limited"] = *req.OrganizerLimited
	}
	if req.InviteOnlyMode != nil {
		updates["invite_only_mode"] = *req.InviteOnlyMode
	}

	err := h.service.UpdateConfig(c.Request.Context(), updates)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   "Failed to update configuration",
		})
		return
	}

	config := h.service.GetConfig(c.Request.Context())
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    config,
		"message": "Configuration updated",
	})
}

// ListInvites returns all invitation codes
// GET /admin/launch/invites
func (h *Handler) ListInvites(c *gin.Context) {
	invites, err := h.service.ListInviteCodes(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   "Failed to list invitations",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    invites,
	})
}

// CreateInviteRequest is the request body for creating an invite
type CreateInviteRequest struct {
	Email     string `json:"email"`
	ValidDays int    `json:"valid_days"`
}

// CreateInvite creates a new invitation code
// POST /admin/launch/invites
func (h *Handler) CreateInvite(c *gin.Context) {
	var req CreateInviteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"error":   "Invalid request body",
		})
		return
	}

	if req.ValidDays <= 0 {
		req.ValidDays = 30 // Default 30 days
	}

	adminID := c.MustGet("userID").(uuid.UUID)

	invite, err := h.service.GenerateInviteCode(c.Request.Context(), req.Email, adminID, req.ValidDays)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   "Failed to create invitation",
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"data":    invite,
		"message": "Invitation code created",
	})
}

// RevokeInvite revokes an invitation code
// DELETE /admin/launch/invites/:code
func (h *Handler) RevokeInvite(c *gin.Context) {
	code := c.Param("code")

	err := h.service.RevokeInviteCode(c.Request.Context(), code)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   "Failed to revoke invitation",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Invitation revoked",
	})
}

// RegistrationCheckMiddleware checks if organizer registration is allowed
func (h *Handler) RegistrationCheckMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get country from request body or header
		country := c.GetHeader("X-Country-Code")
		inviteCode := c.GetHeader("X-Invite-Code")

		// Also check request body for country
		if country == "" {
			var body struct {
				Country    string `json:"country"`
				InviteCode string `json:"invite_code"`
			}
			c.ShouldBindJSON(&body)
			if body.Country != "" {
				country = body.Country
			}
			if body.InviteCode != "" {
				inviteCode = body.InviteCode
			}
		}

		err := h.service.CanRegisterOrganizer(c.Request.Context(), country, inviteCode)
		if err != nil {
			c.JSON(http.StatusForbidden, gin.H{
				"success": false,
				"error":   err.Error(),
				"code":    "REGISTRATION_BLOCKED",
			})
			c.Abort()
			return
		}

		c.Next()
	}
}
