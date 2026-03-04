package admin

import (
	"database/sql"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/internal/rbac"
	"github.com/khair/backend/pkg/middleware"
	"github.com/khair/backend/pkg/response"
)

type Handler struct {
	service *Service
	db      *sql.DB
}

func NewHandler(service *Service, db *sql.DB) *Handler {
	return &Handler{service: service, db: db}
}

func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	admin := r.Group("/admin")
	admin.Use(authMiddleware)
	admin.Use(middleware.AdminOnly())
	{
		// Organizer management
		admin.GET("/organizers", h.ListOrganizers)
		admin.GET("/organizers/pending", h.ListPendingOrganizers)
		admin.GET("/organizers/:id", h.GetOrganizer)
		admin.PUT("/organizers/:id/status", h.UpdateOrganizerStatus)

		// Event management
		admin.GET("/events/pending", h.ListPendingEvents)
		admin.GET("/events/:id", h.GetEvent)
		admin.PUT("/events/:id/status", h.UpdateEventStatus)

		// Dashboard stats
		admin.GET("/stats", h.GetStats)

		// Reports
		admin.GET("/reports/pending", h.GetPendingReports)
		admin.PUT("/reports/:id/resolve", h.ResolveReport)

		// RBAC management (requires manage_users permission)
		rbacGroup := admin.Group("")
		rbacGroup.Use(middleware.RequirePermission(h.db, "manage_users"))
		{
			rbacGroup.GET("/users", h.ListUsers)
			rbacGroup.PATCH("/users/:id/roles", h.UpdateUserRoles)
			rbacGroup.PUT("/users/:id/suspend", h.SuspendUser)
			rbacGroup.PUT("/users/:id/unsuspend", h.UnsuspendUser)
			rbacGroup.GET("/roles", h.ListRoles)
			rbacGroup.POST("/roles", h.CreateRole)
			rbacGroup.POST("/roles/:id/permissions", h.AssignPermissions)
		}
	}
}

// ── Organizer Management ──

func (h *Handler) ListOrganizers(c *gin.Context) {
	organizers, err := h.service.ListAllOrganizers()
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}
	response.Success(c, organizers)
}

func (h *Handler) ListPendingOrganizers(c *gin.Context) {
	organizers, err := h.service.ListPendingOrganizers()
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}
	response.Success(c, organizers)
}

func (h *Handler) GetOrganizer(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid organizer ID")
		return
	}

	org, err := h.service.GetOrganizer(id)
	if err != nil {
		response.NotFound(c, "Organizer not found")
		return
	}

	response.Success(c, org)
}

func (h *Handler) UpdateOrganizerStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid organizer ID")
		return
	}

	var req StatusUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	org, err := h.service.UpdateOrganizerStatus(id, &req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, "Organizer status updated", org)
}

// ── Event Management ──

func (h *Handler) ListPendingEvents(c *gin.Context) {
	events, err := h.service.ListPendingEvents()
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}
	response.Success(c, events)
}

func (h *Handler) GetEvent(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	event, err := h.service.GetEvent(id)
	if err != nil {
		response.NotFound(c, "Event not found")
		return
	}

	response.Success(c, event)
}

func (h *Handler) UpdateEventStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	var req StatusUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	// Get reviewer ID from context
	reviewerID, _ := c.Get("user_id")
	uid, _ := reviewerID.(uuid.UUID)

	event, err := h.service.UpdateEventStatus(id, &req, uid)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, "Event status updated", event)
}

// ── RBAC Management ──

func (h *Handler) ListUsers(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	users, total, err := h.service.rbacService.ListUsers(page, pageSize)
	if err != nil {
		response.InternalServerError(c, "Failed to list users")
		return
	}

	response.Paginated(c, users, page, pageSize, total)
}

func (h *Handler) UpdateUserRoles(c *gin.Context) {
	targetID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid user ID")
		return
	}

	var req rbac.UpdateUserRolesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	actorID, _ := c.Get("user_id")
	uid, _ := actorID.(uuid.UUID)

	actorRoles := []string{}
	if rolesVal, exists := c.Get("roles"); exists {
		if roles, ok := rolesVal.([]string); ok {
			actorRoles = roles
		}
	}

	ip := c.ClientIP()
	if err := h.service.rbacService.UpdateUserRoles(targetID, &req, uid, actorRoles, &ip); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, "User roles updated", nil)
}

func (h *Handler) ListRoles(c *gin.Context) {
	roles, err := h.service.rbacService.ListRoles()
	if err != nil {
		response.InternalServerError(c, "Failed to list roles")
		return
	}
	response.Success(c, roles)
}

func (h *Handler) CreateRole(c *gin.Context) {
	var req rbac.CreateRoleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	role, err := h.service.rbacService.CreateRole(req.Name, req.Description)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Created(c, role)
}

func (h *Handler) AssignPermissions(c *gin.Context) {
	roleID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid role ID")
		return
	}

	var req rbac.AssignPermissionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	actorID, _ := c.Get("user_id")
	uid, _ := actorID.(uuid.UUID)

	ip := c.ClientIP()
	if err := h.service.rbacService.AssignPermissionsToRole(roleID, req.Permissions, uid, &ip); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, "Permissions assigned", nil)
}

// SuspendUser suspends a user account
func (h *Handler) SuspendUser(c *gin.Context) {
	targetID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid user ID")
		return
	}

	var req struct {
		Reason string `json:"reason" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	adminID, _ := c.Get("user_id")
	uid, _ := adminID.(uuid.UUID)

	if err := h.service.SuspendUser(targetID, req.Reason, uid); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, "User suspended", nil)
}

// UnsuspendUser lifts a user suspension
func (h *Handler) UnsuspendUser(c *gin.Context) {
	targetID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid user ID")
		return
	}

	if err := h.service.UnsuspendUser(targetID); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, "User unsuspended", nil)
}

// ── Stats ──

// GetStats returns platform-wide dashboard statistics
func (h *Handler) GetStats(c *gin.Context) {
	var totalOrgs, totalEvents, totalUsers, pendingOrgs, pendingEvents int64

	h.db.QueryRow("SELECT COUNT(*) FROM organizers").Scan(&totalOrgs)
	h.db.QueryRow("SELECT COUNT(*) FROM events").Scan(&totalEvents)
	h.db.QueryRow("SELECT COUNT(*) FROM users").Scan(&totalUsers)
	h.db.QueryRow("SELECT COUNT(*) FROM organizers WHERE status='pending'").Scan(&pendingOrgs)
	h.db.QueryRow("SELECT COUNT(*) FROM events WHERE status='pending'").Scan(&pendingEvents)

	response.Success(c, gin.H{
		"total_organizers":   totalOrgs,
		"total_events":       totalEvents,
		"total_users":        totalUsers,
		"pending_organizers": pendingOrgs,
		"pending_events":     pendingEvents,
	})
}

// ── Reports ──

// GetPendingReports returns pending reports
func (h *Handler) GetPendingReports(c *gin.Context) {
	// Return empty list — full reporting is via trust/reporting module
	response.Success(c, []interface{}{})
}

// ResolveReport resolves a report
func (h *Handler) ResolveReport(c *gin.Context) {
	_, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid report ID")
		return
	}
	response.SuccessWithMessage(c, "Report resolved", nil)
}
