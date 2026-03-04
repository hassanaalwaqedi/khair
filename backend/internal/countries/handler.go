package countries

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/pkg/response"
)

// Handler handles country-related HTTP requests
type Handler struct {
	repo *Repository
}

// NewHandler creates a new countries handler
func NewHandler(repo *Repository) *Handler {
	return &Handler{repo: repo}
}

// RegisterRoutes registers country routes (public, no auth required)
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	group := rg.Group("/countries")
	{
		group.GET("", h.List)
		group.GET("/search", h.Search)
	}
}

// List returns all active countries
// GET /api/v1/countries
func (h *Handler) List(c *gin.Context) {
	result, err := h.repo.ListActive()
	if err != nil {
		response.Error(c, http.StatusInternalServerError, "Failed to load countries")
		return
	}

	if result == nil {
		result = []models.Country{}
	}
	response.Success(c, result)
}

// Search returns countries matching a query
// GET /api/v1/countries/search?q=saudi
func (h *Handler) Search(c *gin.Context) {
	query := c.Query("q")
	if query == "" {
		h.List(c)
		return
	}

	result, err := h.repo.Search(query)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, "Search failed")
		return
	}

	if result == nil {
		result = []models.Country{}
	}
	response.Success(c, result)
}
