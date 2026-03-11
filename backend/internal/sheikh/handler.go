package sheikh

import (
	"github.com/gin-gonic/gin"

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

// RegisterRoutes registers sheikh directory routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	r.GET("/sheikhs", h.ListSheikhs)
}

// ListSheikhs returns all public sheikh profiles
// @Summary List sheikhs
// @Description Get all active sheikh profiles for the public directory
// @Tags sheikhs
// @Produce json
// @Success 200 {object} response.Response
// @Router /sheikhs [get]
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
