package spiritualquote

import (
	"errors"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/response"
)

// Handler handles quote HTTP requests.
type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers public quote routes.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	quotes := r.Group("/quotes")
	{
		quotes.GET("/random", h.GetRandom)
		quotes.GET("", h.List)
	}
}

// RegisterAdminRoutes registers admin CRUD routes for quotes.
func (h *Handler) RegisterAdminRoutes(r *gin.RouterGroup, authMiddleware, adminMiddleware gin.HandlerFunc) {
	admin := r.Group("/admin/quotes")
	admin.Use(authMiddleware, adminMiddleware)
	{
		admin.GET("", h.AdminList)
		admin.POST("", h.AdminCreate)
		admin.PUT("/:id", h.AdminUpdate)
		admin.DELETE("/:id", h.AdminDelete)
	}
}

// GetRandom returns a single random active quote for a location.
func (h *Handler) GetRandom(c *gin.Context) {
	location, err := ParseLocation(c.Query("location"))
	if err != nil {
		response.BadRequest(c, MessageInvalidLocation)
		return
	}

	quote, err := h.service.GetRandom(c.Request.Context(), location)
	if err != nil {
		if errors.Is(err, ErrQuoteNotFound) {
			response.NotFound(c, MessageQuoteNotFound)
			return
		}
		response.InternalServerError(c, MessageFetchFailed)
		return
	}

	response.Success(c, quote)
}

// List returns all active quotes for a given location (public, for the rotator).
func (h *Handler) List(c *gin.Context) {
	location, err := ParseLocation(c.Query("location"))
	if err != nil {
		response.BadRequest(c, MessageInvalidLocation)
		return
	}

	quotes, err := h.service.ListByLocation(c.Request.Context(), location)
	if err != nil {
		response.InternalServerError(c, MessageFetchFailed)
		return
	}

	response.Success(c, quotes)
}

// ── Admin CRUD ──

// AdminList returns all quotes (including inactive) for the admin panel.
func (h *Handler) AdminList(c *gin.Context) {
	quotes, err := h.service.ListAll(c.Request.Context())
	if err != nil {
		response.InternalServerError(c, MessageFetchFailed)
		return
	}
	response.Success(c, quotes)
}

// CreateQuoteRequest is the request body for creating a quote.
type CreateQuoteRequest struct {
	Type            string `json:"type" binding:"required,oneof=quran hadith"`
	TextAR          string `json:"text_ar" binding:"required"`
	Source          string `json:"source" binding:"required"`
	Reference       string `json:"reference" binding:"required"`
	IsActive        bool   `json:"is_active"`
	ShowOnDashboard bool   `json:"show_on_dashboard"`
	ShowOnHome      bool   `json:"show_on_home"`
	ShowOnLogin     bool   `json:"show_on_login"`
}

// AdminCreate adds a new quote.
func (h *Handler) AdminCreate(c *gin.Context) {
	var req CreateQuoteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	quote := &Quote{
		Type:            req.Type,
		TextAR:          req.TextAR,
		Source:          req.Source,
		Reference:       req.Reference,
		IsActive:        req.IsActive,
		ShowOnDashboard: req.ShowOnDashboard,
		ShowOnHome:      req.ShowOnHome,
		ShowOnLogin:     req.ShowOnLogin,
	}

	if err := h.service.Create(c.Request.Context(), quote); err != nil {
		response.InternalServerError(c, "Failed to create quote")
		return
	}

	response.Created(c, quote)
}

// AdminUpdate modifies an existing quote.
func (h *Handler) AdminUpdate(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid quote ID")
		return
	}

	var req CreateQuoteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	quote := &Quote{
		ID:              id,
		Type:            req.Type,
		TextAR:          req.TextAR,
		Source:          req.Source,
		Reference:       req.Reference,
		IsActive:        req.IsActive,
		ShowOnDashboard: req.ShowOnDashboard,
		ShowOnHome:      req.ShowOnHome,
		ShowOnLogin:     req.ShowOnLogin,
	}

	if err := h.service.Update(c.Request.Context(), quote); err != nil {
		response.InternalServerError(c, "Failed to update quote")
		return
	}

	response.SuccessWithMessage(c, "Quote updated", quote)
}

// AdminDelete removes a quote.
func (h *Handler) AdminDelete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid quote ID")
		return
	}

	if err := h.service.Delete(c.Request.Context(), id); err != nil {
		response.InternalServerError(c, "Failed to delete quote")
		return
	}

	response.SuccessWithMessage(c, "Quote deleted", nil)
}
