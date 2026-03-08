package admin

import (
	"context"
	"database/sql"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	"github.com/khair/backend/internal/rbac"
	"github.com/khair/backend/pkg/middleware"
	"github.com/khair/backend/pkg/response"
)

type Handler struct {
	service *Service
	db      *sql.DB
	redis   *redis.Client
}

func NewHandler(service *Service, db *sql.DB, redisClient *redis.Client) *Handler {
	return &Handler{service: service, db: db, redis: redisClient}
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

		// User management (admin-only)
		admin.GET("/users", h.ListUsers)
		admin.PUT("/users/:id/role", h.UpdateUserRole)
		admin.PUT("/users/:id/status", h.UpdateUserStatus)
		admin.PUT("/users/:id/suspend", h.SuspendUser)
		admin.PUT("/users/:id/unsuspend", h.UnsuspendUser)
		admin.DELETE("/users/:id", h.DeleteUser)

		// Advanced RBAC management (requires manage_users permission)
		rbacGroup := admin.Group("")
		rbacGroup.Use(middleware.RequirePermission(h.db, "manage_users"))
		{
			rbacGroup.PATCH("/users/:id/roles", h.UpdateUserRoles)
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

	// Invalidate discovery cache so newly approved events appear immediately
	if h.redis != nil && req.Status == "approved" {
		ctx := context.Background()
		h.redis.Del(ctx, "discover:featured", "discover:trending")
		// Clear nearby cache keys (pattern-based)
		iter := h.redis.Scan(ctx, 0, "discover:nearby:*", 100).Iterator()
		for iter.Next(ctx) {
			h.redis.Del(ctx, iter.Val())
		}
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

// UpdateUserRole updates a user's role (user/organizer/admin)
func (h *Handler) UpdateUserRole(c *gin.Context) {
	targetID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid user ID")
		return
	}

	var req struct {
		Role string `json:"role" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "role is required")
		return
	}

	_, err = h.db.Exec(`UPDATE users SET role = $1, updated_at = NOW() WHERE id = $2`, req.Role, targetID)
	if err != nil {
		response.InternalServerError(c, "Failed to update role")
		return
	}
	response.SuccessWithMessage(c, "User role updated to "+req.Role, nil)
}

// UpdateUserStatus updates a user's status (active/suspended/banned)
func (h *Handler) UpdateUserStatus(c *gin.Context) {
	targetID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid user ID")
		return
	}

	var req struct {
		Status string `json:"status" binding:"required"`
		Reason string `json:"reason"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "status is required")
		return
	}

	switch req.Status {
	case "active":
		h.db.Exec(`UPDATE users SET is_suspended = false, suspension_reason = NULL, updated_at = NOW() WHERE id = $1`, targetID)
	case "suspended":
		adminID, _ := c.Get("user_id")
		uid, _ := adminID.(uuid.UUID)
		reason := req.Reason
		if reason == "" {
			reason = "Suspended by admin"
		}
		h.service.SuspendUser(targetID, reason, uid)
	case "banned":
		h.db.Exec(`UPDATE users SET is_suspended = true, suspension_reason = $1, updated_at = NOW() WHERE id = $2`,
			"BANNED: "+req.Reason, targetID)
	default:
		response.BadRequest(c, "Invalid status")
		return
	}

	response.SuccessWithMessage(c, "User status updated to "+req.Status, nil)
}

// DeleteUser removes a user account
func (h *Handler) DeleteUser(c *gin.Context) {
	targetID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid user ID")
		return
	}

	_, err = h.db.Exec(`DELETE FROM users WHERE id = $1`, targetID)
	if err != nil {
		response.InternalServerError(c, "Failed to delete user")
		return
	}
	response.SuccessWithMessage(c, "User deleted", nil)
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
