package trust

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/internal/trust/audit"
	"github.com/khair/backend/internal/trust/moderation"
	"github.com/khair/backend/internal/trust/reporting"
	"github.com/khair/backend/internal/trust/score"
)

// Handler handles Trust & Safety API endpoints
type Handler struct {
	audit      *audit.Service
	moderation *moderation.Service
	reporting  *reporting.Service
	score      *score.Service
}

// NewHandler creates a new Trust & Safety handler
func NewHandler(
	auditSvc *audit.Service,
	moderationSvc *moderation.Service,
	reportingSvc *reporting.Service,
	scoreSvc *score.Service,
) *Handler {
	return &Handler{
		audit:      auditSvc,
		moderation: moderationSvc,
		reporting:  reportingSvc,
		score:      scoreSvc,
	}
}

// RegisterRoutes registers Trust & Safety routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware, adminMiddleware gin.HandlerFunc) {
	// Public report endpoint (no auth required)
	r.POST("/reports", h.CreateReport)

	// Admin-only endpoints
	admin := r.Group("/admin")
	admin.Use(authMiddleware, adminMiddleware)
	{
		// Reports management
		admin.GET("/reports", h.ListReports)
		admin.GET("/reports/:id", h.GetReport)
		admin.POST("/reports/:id/resolve", h.ResolveReport)
		admin.POST("/reports/:id/dismiss", h.DismissReport)

		// Organizer trust management
		admin.GET("/organizers/:id/trust", h.GetOrganizerTrust)
		admin.GET("/organizers/:id/trust-history", h.GetTrustHistory)
		admin.POST("/organizers/:id/warn", h.WarnOrganizer)
		admin.POST("/organizers/:id/suspend", h.SuspendOrganizer)
		admin.POST("/organizers/:id/ban", h.BanOrganizer)
		admin.POST("/organizers/:id/reinstate", h.ReinstateOrganizer)

		// Audit logs
		admin.GET("/audit-logs", h.ListAuditLogs)

		// Moderation keywords
		admin.GET("/keywords", h.ListKeywords)
		admin.POST("/keywords", h.AddKeyword)
		admin.DELETE("/keywords/:id", h.RemoveKeyword)

		// Moderation flags
		admin.GET("/events/:id/flags", h.GetEventFlags)
		admin.POST("/flags/:id/resolve", h.ResolveFlag)
	}
}

// CreateReport handles public report submission
// POST /reports
func (h *Handler) CreateReport(c *gin.Context) {
	var req models.CreateReportRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": err.Error()})
		return
	}

	// Determine reporter type
	var reporterType models.ReporterType
	var reporterID *uuid.UUID

	if userID, exists := c.Get("userID"); exists && userID != nil {
		reporterType = models.ReporterUser
		id := userID.(uuid.UUID)
		reporterID = &id
	} else {
		reporterType = models.ReporterGuest
	}

	report, err := h.reporting.CreateReport(c.Request.Context(), req, reporterType, reporterID, c.ClientIP())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to create report"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"data":    report,
		"message": "Report submitted successfully",
	})
}

// ListReports handles admin report listing
// GET /admin/reports
func (h *Handler) ListReports(c *gin.Context) {
	limit := 50
	offset := 0
	// Parse query params...

	var status *models.ReportStatus
	if s := c.Query("status"); s != "" {
		st := models.ReportStatus(s)
		status = &st
	}

	var targetType *models.ReportTargetType
	if t := c.Query("target_type"); t != "" {
		tt := models.ReportTargetType(t)
		targetType = &tt
	}

	reports, total, err := h.reporting.ListReports(c.Request.Context(), status, targetType, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to list reports"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    reports,
		"total":   total,
	})
}

// GetReport retrieves a single report
// GET /admin/reports/:id
func (h *Handler) GetReport(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid report ID"})
		return
	}

	report, err := h.reporting.GetReport(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Report not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": report})
}

// ResolveReport resolves a report
// POST /admin/reports/:id/resolve
func (h *Handler) ResolveReport(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid report ID"})
		return
	}

	var req models.ResolveReportRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": err.Error()})
		return
	}

	adminID := c.MustGet("userID").(uuid.UUID)

	err = h.reporting.ResolveReport(c.Request.Context(), id, adminID, req.Action, req.Notes)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to resolve report"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Report resolved"})
}

// DismissReport dismisses a report
// POST /admin/reports/:id/dismiss
func (h *Handler) DismissReport(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid report ID"})
		return
	}

	var req struct {
		Notes *string `json:"notes"`
	}
	c.ShouldBindJSON(&req)

	adminID := c.MustGet("userID").(uuid.UUID)

	err = h.reporting.DismissReport(c.Request.Context(), id, adminID, req.Notes)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to dismiss report"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Report dismissed"})
}

// GetOrganizerTrust retrieves trust info for an organizer
// GET /admin/organizers/:id/trust
func (h *Handler) GetOrganizerTrust(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid organizer ID"})
		return
	}

	trustScore, err := h.score.GetOrCreateTrustScore(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to get trust score"})
		return
	}

	state, err := h.score.GetOrganizerState(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to get trust state"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"trust_score": trustScore,
			"state":       state,
		},
	})
}

// GetTrustHistory retrieves trust change history
// GET /admin/organizers/:id/trust-history
func (h *Handler) GetTrustHistory(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid organizer ID"})
		return
	}

	history, err := h.score.GetTrustHistory(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to get trust history"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": history})
}

// WarnOrganizer issues a warning
// POST /admin/organizers/:id/warn
func (h *Handler) WarnOrganizer(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid organizer ID"})
		return
	}

	var req models.TrustStateChangeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": err.Error()})
		return
	}

	adminID := c.MustGet("userID").(uuid.UUID)

	err = h.score.WarnOrganizer(c.Request.Context(), id, req.Reason, adminID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to warn organizer"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Warning issued"})
}

// SuspendOrganizer suspends an organizer
// POST /admin/organizers/:id/suspend
func (h *Handler) SuspendOrganizer(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid organizer ID"})
		return
	}

	var req models.TrustStateChangeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": err.Error()})
		return
	}

	adminID := c.MustGet("userID").(uuid.UUID)

	err = h.score.SuspendOrganizer(c.Request.Context(), id, req.Reason, adminID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to suspend organizer"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Organizer suspended"})
}

// BanOrganizer bans an organizer
// POST /admin/organizers/:id/ban
func (h *Handler) BanOrganizer(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid organizer ID"})
		return
	}

	var req models.TrustStateChangeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": err.Error()})
		return
	}

	adminID := c.MustGet("userID").(uuid.UUID)

	err = h.score.BanOrganizer(c.Request.Context(), id, req.Reason, adminID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to ban organizer"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Organizer banned"})
}

// ReinstateOrganizer reinstates an organizer
// POST /admin/organizers/:id/reinstate
func (h *Handler) ReinstateOrganizer(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid organizer ID"})
		return
	}

	var req models.TrustStateChangeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": err.Error()})
		return
	}

	adminID := c.MustGet("userID").(uuid.UUID)

	err = h.score.ReinstateOrganizer(c.Request.Context(), id, req.Reason, adminID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to reinstate organizer"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Organizer reinstated"})
}

// ListAuditLogs lists audit logs with filters
// GET /admin/audit-logs
func (h *Handler) ListAuditLogs(c *gin.Context) {
	var query models.AuditLogQuery
	if err := c.ShouldBindQuery(&query); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": err.Error()})
		return
	}

	logs, total, err := h.audit.Query(c.Request.Context(), query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to query audit logs"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    logs,
		"total":   total,
	})
}

// ListKeywords lists banned keywords
// GET /admin/keywords
func (h *Handler) ListKeywords(c *gin.Context) {
	activeOnly := c.Query("active_only") == "true"

	keywords, err := h.moderation.GetKeywords(c.Request.Context(), activeOnly)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to list keywords"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": keywords})
}

// AddKeyword adds a new banned keyword
// POST /admin/keywords
func (h *Handler) AddKeyword(c *gin.Context) {
	var keyword models.BannedKeyword
	if err := c.ShouldBindJSON(&keyword); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": err.Error()})
		return
	}

	adminID := c.MustGet("userID").(uuid.UUID)
	keyword.CreatedBy = &adminID
	keyword.IsActive = true

	err := h.moderation.AddKeyword(c.Request.Context(), keyword)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to add keyword"})
		return
	}

	// Audit log
	h.audit.LogAdminAction(c.Request.Context(), adminID, models.AuditActionKeywordAdded,
		"keyword", keyword.ID, "Added keyword: "+keyword.Keyword, nil, keyword, c.ClientIP(), c.GetHeader("User-Agent"))

	c.JSON(http.StatusCreated, gin.H{"success": true, "data": keyword})
}

// RemoveKeyword deactivates a banned keyword
// DELETE /admin/keywords/:id
func (h *Handler) RemoveKeyword(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid keyword ID"})
		return
	}

	err = h.moderation.RemoveKeyword(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to remove keyword"})
		return
	}

	adminID := c.MustGet("userID").(uuid.UUID)
	h.audit.LogAdminAction(c.Request.Context(), adminID, models.AuditActionKeywordRemoved,
		"keyword", id, "Removed keyword", nil, nil, c.ClientIP(), c.GetHeader("User-Agent"))

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Keyword removed"})
}

// GetEventFlags retrieves moderation flags for an event
// GET /admin/events/:id/flags
func (h *Handler) GetEventFlags(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid event ID"})
		return
	}

	flags, err := h.moderation.GetEventFlags(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to get flags"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": flags})
}

// ResolveFlag resolves a moderation flag
// POST /admin/flags/:id/resolve
func (h *Handler) ResolveFlag(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid flag ID"})
		return
	}

	adminID := c.MustGet("userID").(uuid.UUID)

	err = h.moderation.ResolveFlag(c.Request.Context(), id, adminID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to resolve flag"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Flag resolved"})
}
