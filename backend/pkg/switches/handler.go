package switches

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Handler provides emergency switch API endpoints
type Handler struct {
	service *Service
}

// NewHandler creates a new switches handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers switch admin routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware, adminMiddleware gin.HandlerFunc) {
	admin := r.Group("/admin/switches")
	admin.Use(authMiddleware, adminMiddleware)
	{
		admin.GET("", h.ListSwitches)
		admin.GET("/:name", h.GetSwitch)
		admin.PUT("/:name", h.UpdateSwitch)
		admin.POST("/lockdown", h.ActivateLockdown)
		admin.DELETE("/lockdown", h.LiftLockdown)
	}
}

// ListSwitches returns all switches
// GET /admin/switches
func (h *Handler) ListSwitches(c *gin.Context) {
	switches, err := h.service.GetAll(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   "Failed to retrieve switches",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    switches,
	})
}

// GetSwitch returns a specific switch
// GET /admin/switches/:name
func (h *Handler) GetSwitch(c *gin.Context) {
	name := c.Param("name")

	sw, err := h.service.Get(c.Request.Context(), name)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"error":   "Switch not found",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    sw,
	})
}

// UpdateSwitchRequest is the request body for updating a switch
type UpdateSwitchRequest struct {
	Enabled      bool    `json:"enabled"`
	Reason       string  `json:"reason" binding:"required"`
	ExpiresInMin *int    `json:"expires_in_minutes,omitempty"`
}

// UpdateSwitch updates a switch
// PUT /admin/switches/:name
func (h *Handler) UpdateSwitch(c *gin.Context) {
	name := c.Param("name")

	var req UpdateSwitchRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"error":   "Invalid request body",
		})
		return
	}

	adminID := c.MustGet("userID").(uuid.UUID)

	var expiresIn *time.Duration
	if req.ExpiresInMin != nil {
		d := time.Duration(*req.ExpiresInMin) * time.Minute
		expiresIn = &d
	}

	err := h.service.Set(c.Request.Context(), name, req.Enabled, req.Reason, adminID, expiresIn)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   "Failed to update switch",
		})
		return
	}

	sw, _ := h.service.Get(c.Request.Context(), name)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    sw,
		"message": "Switch updated",
	})
}

// LockdownRequest is the request body for lockdown
type LockdownRequest struct {
	Reason string `json:"reason" binding:"required"`
}

// ActivateLockdown activates emergency lockdown
// POST /admin/switches/lockdown
func (h *Handler) ActivateLockdown(c *gin.Context) {
	var req LockdownRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"error":   "Reason is required",
		})
		return
	}

	adminID := c.MustGet("userID").(uuid.UUID)

	err := h.service.EmergencyLockdown(c.Request.Context(), req.Reason, adminID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   "Failed to activate lockdown",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Emergency lockdown activated. All public-facing features disabled.",
	})
}

// LiftLockdown deactivates lockdown
// DELETE /admin/switches/lockdown
func (h *Handler) LiftLockdown(c *gin.Context) {
	var req LockdownRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"error":   "Reason is required",
		})
		return
	}

	adminID := c.MustGet("userID").(uuid.UUID)

	err := h.service.LiftLockdown(c.Request.Context(), req.Reason, adminID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   "Failed to lift lockdown",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Lockdown lifted. Public features restored.",
	})
}

// SwitchCheckMiddleware blocks requests if a switch is disabled
func (h *Handler) SwitchCheckMiddleware(switchName string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !h.service.IsEnabled(c.Request.Context(), switchName) {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"success": false,
				"error":   "This feature is temporarily disabled",
				"code":    "FEATURE_DISABLED",
			})
			c.Abort()
			return
		}
		c.Next()
	}
}

// LockdownMiddleware blocks all requests during lockdown
func (h *Handler) LockdownMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Skip health check endpoints
		if c.Request.URL.Path == "/health" || c.Request.URL.Path == "/ready" {
			c.Next()
			return
		}

		if h.service.IsLockdown(c.Request.Context()) {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"success": false,
				"error":   "Service temporarily unavailable for maintenance",
				"code":    "LOCKDOWN",
			})
			c.Abort()
			return
		}
		c.Next()
	}
}
