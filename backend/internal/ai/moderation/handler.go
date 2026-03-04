package moderation

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/middleware"
	"github.com/khair/backend/pkg/response"
)

type Handler struct {
	service *ModerationService
}

func NewHandler(service *ModerationService) *Handler {
	return &Handler{service: service}
}

func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	admin := r.Group("/admin/moderation")
	admin.Use(authMiddleware)
	admin.Use(middleware.AdminOnly())
	{
		admin.GET("/queue", h.GetModerationQueue)
		admin.GET("/high-risk", h.GetHighRiskEvents)
		admin.GET("/events/:id/scans", h.GetEventScans)
	}

	orgRisk := r.Group("/admin/organizers")
	orgRisk.Use(authMiddleware)
	orgRisk.Use(middleware.AdminOnly())
	{
		orgRisk.GET("/risk-ranking", h.GetOrganizerRiskRanking)
	}
}

func (h *Handler) GetModerationQueue(c *gin.Context) {
	limit, offset := parsePagination(c)

	items, total, err := h.service.GetModerationQueue(limit, offset)
	if err != nil {
		response.InternalServerError(c, "Failed to get moderation queue")
		return
	}

	page := (offset / limit) + 1
	response.Paginated(c, items, page, limit, total)
}

func (h *Handler) GetHighRiskEvents(c *gin.Context) {
	limit, offset := parsePagination(c)

	items, total, err := h.service.GetHighRiskEvents(limit, offset)
	if err != nil {
		response.InternalServerError(c, "Failed to get high-risk events")
		return
	}

	page := (offset / limit) + 1
	response.Paginated(c, items, page, limit, total)
}

func (h *Handler) GetOrganizerRiskRanking(c *gin.Context) {
	limit, offset := parsePagination(c)

	rankings, total, err := h.service.GetOrganizerRiskRanking(limit, offset)
	if err != nil {
		response.InternalServerError(c, "Failed to get organizer risk ranking")
		return
	}

	page := (offset / limit) + 1
	response.Paginated(c, rankings, page, limit, total)
}

func (h *Handler) GetEventScans(c *gin.Context) {
	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	scans, err := h.service.GetEventScans(eventID)
	if err != nil {
		response.InternalServerError(c, "Failed to get event scans")
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    scans,
	})
}

func parsePagination(c *gin.Context) (int, int) {
	limit := 20
	offset := 0

	if l := c.Query("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 100 {
			limit = parsed
		}
	}
	if o := c.Query("offset"); o != "" {
		if parsed, err := strconv.Atoi(o); err == nil && parsed >= 0 {
			offset = parsed
		}
	}
	if page := c.Query("page"); page != "" {
		if p, err := strconv.Atoi(page); err == nil && p > 0 {
			offset = (p - 1) * limit
		}
	}
	return limit, offset
}
