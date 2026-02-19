package featureflags

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Handler provides feature flag API endpoints
type Handler struct {
	service *Service
}

// NewHandler creates a new feature flag handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers feature flag admin routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware, adminMiddleware gin.HandlerFunc) {
	admin := r.Group("/admin/feature-flags")
	admin.Use(authMiddleware, adminMiddleware)
	{
		admin.GET("", h.ListFlags)
		admin.GET("/:name", h.GetFlag)
		admin.PUT("/:name", h.UpdateFlag)
	}
}

// ListFlags returns all feature flags
// GET /admin/feature-flags
func (h *Handler) ListFlags(c *gin.Context) {
	flags, err := h.service.GetAll(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   "Failed to retrieve feature flags",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    flags,
	})
}

// GetFlag returns a specific feature flag
// GET /admin/feature-flags/:name
func (h *Handler) GetFlag(c *gin.Context) {
	name := c.Param("name")

	flag, err := h.service.Get(c.Request.Context(), name)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"error":   "Feature flag not found",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    flag,
	})
}

// UpdateFlagRequest is the request body for updating a flag
type UpdateFlagRequest struct {
	Enabled bool `json:"enabled"`
}

// UpdateFlag updates a feature flag
// PUT /admin/feature-flags/:name
func (h *Handler) UpdateFlag(c *gin.Context) {
	name := c.Param("name")

	var req UpdateFlagRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"error":   "Invalid request body",
		})
		return
	}

	// Get admin ID
	adminID := "system"
	if userID, exists := c.Get("userID"); exists {
		adminID = userID.(uuid.UUID).String()
	}

	err := h.service.Set(c.Request.Context(), name, req.Enabled, adminID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"error":   "Failed to update feature flag",
		})
		return
	}

	flag, _ := h.service.Get(c.Request.Context(), name)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    flag,
		"message": "Feature flag updated",
	})
}

// RequireFlagMiddleware returns middleware that blocks if a flag is disabled
func (h *Handler) RequireFlagMiddleware(flagName string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !h.service.IsEnabled(c.Request.Context(), flagName) {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"success": false,
				"error":   "This feature is currently disabled",
				"code":    "FEATURE_DISABLED",
			})
			c.Abort()
			return
		}
		c.Next()
	}
}
