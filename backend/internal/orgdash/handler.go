package orgdash

import (
	"errors"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/internal/eligibility"
	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/pkg/response"
)

// Handler handles organization dashboard HTTP requests
type Handler struct {
	service *Service
}

// NewHandler creates a new orgdash handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// helper to extract org_id set by RBAC middleware
func getOrgID(c *gin.Context) uuid.UUID {
	return c.MustGet("org_id").(uuid.UUID)
}

// helper to extract actor user_id
func getActorID(c *gin.Context) uuid.UUID {
	val, exists := c.Get("user_id")
	if !exists || val == nil {
		return uuid.Nil
	}
	switch v := val.(type) {
	case uuid.UUID:
		return v
	case string:
		uid, err := uuid.Parse(v)
		if err != nil {
			return uuid.Nil
		}
		return uid
	default:
		return uuid.Nil
	}
}

// GetHubDashboard is the self-scoped Organizer Hub endpoint. It deliberately
// never accepts an organization id, preventing an organizer from enumerating
// another organization's private operational data.
func (h *Handler) GetHubDashboard(c *gin.Context) {
	userID := getActorID(c)
	if userID == uuid.Nil {
		response.Unauthorized(c, "Authentication required")
		return
	}
	dashboard, err := h.service.GetHubDashboard(
		userID,
		c.DefaultQuery("range", "30d"),
		c.Query("start"),
		c.Query("end"),
	)
	if err != nil {
		if errors.Is(err, ErrOrganizerAccess) {
			response.Forbidden(c, "Approved organizer access required")
			return
		}
		if err.Error() == "unsupported dashboard range" ||
			(len(err.Error()) > 12 && err.Error()[:12] == "custom range") {
			response.BadRequest(c, err.Error())
			return
		}
		response.InternalServerError(c, "Failed to load organizer hub")
		return
	}
	response.Success(c, dashboard)
}

// requireOrgRole must be called after the scoped authorization middleware in
// main. Read-only viewers never gain mutation permissions simply by knowing an
// organization id.
func requireOrgRole(c *gin.Context, minimum string) bool {
	if role, _ := c.Get("role"); role == models.RoleAdmin || role == "super_admin" {
		return true
	}
	role, _ := c.Get("org_role")
	if value, ok := role.(string); ok && models.OrgRoleLevel(value) >= models.OrgRoleLevel(minimum) {
		return true
	}
	response.Forbidden(c, "Your organization role does not allow this action")
	return false
}

// ── Dashboard ──

// GetDashboard returns overview statistics
func (h *Handler) GetDashboard(c *gin.Context) {
	stats, err := h.service.GetDashboardStats(getOrgID(c))
	if err != nil {
		response.InternalServerError(c, "Failed to load dashboard: "+err.Error())
		return
	}
	response.Success(c, stats)
}

// GetAnalytics returns full analytics data
func (h *Handler) GetAnalytics(c *gin.Context) {
	data, err := h.service.GetAnalytics(getOrgID(c))
	if err != nil {
		response.InternalServerError(c, "Failed to load analytics: "+err.Error())
		return
	}
	response.Success(c, data)
}

// GetActivity returns recent audit log entries
func (h *Handler) GetActivity(c *gin.Context) {
	limitStr := c.DefaultQuery("limit", "20")
	limit, _ := strconv.Atoi(limitStr)
	logs, err := h.service.GetRecentActivity(getOrgID(c), limit)
	if err != nil {
		response.InternalServerError(c, "Failed to load activity")
		return
	}
	response.Success(c, logs)
}

// ── Event Management ──

// ListEvents lists org events
func (h *Handler) ListEvents(c *gin.Context) {
	orgID := getOrgID(c)
	pageStr := c.DefaultQuery("page", "1")
	pageSizeStr := c.DefaultQuery("page_size", "20")
	page, _ := strconv.Atoi(pageStr)
	pageSize, _ := strconv.Atoi(pageSizeStr)

	var status *string
	if s := c.Query("status"); s != "" {
		status = &s
	}

	events, count, err := h.service.ListOrgEvents(orgID, status, page, pageSize)
	if err != nil {
		response.InternalServerError(c, "Failed to list events")
		return
	}
	response.Paginated(c, events, page, pageSize, count)
}

// CreateEvent creates a new event
func (h *Handler) CreateEvent(c *gin.Context) {
	if !requireOrgRole(c, models.OrgRoleEventManager) {
		return
	}
	orgID := getOrgID(c)
	actorID := getActorID(c)

	var req CreateEventRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	ev, err := h.service.CreateEvent(orgID, &req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	targetType := "event"
	h.service.LogAction(orgID, actorID, "event.created", &targetType, &ev.ID, map[string]string{"title": ev.Title}, nil)
	response.Created(c, ev)
}

// UpdateEvent updates an event
func (h *Handler) UpdateEvent(c *gin.Context) {
	if !requireOrgRole(c, models.OrgRoleEventManager) {
		return
	}
	orgID := getOrgID(c)
	actorID := getActorID(c)

	eventID, err := uuid.Parse(c.Param("event_id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	var req UpdateEventRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	ev, err := h.service.UpdateEvent(orgID, eventID, &req, actorID)
	if err != nil {
		var eligibilityErr *eligibility.Error
		if errors.As(err, &eligibilityErr) {
			response.ErrorWithCode(c, eligibilityErr.HTTPStatus, eligibilityErr.Code, eligibilityErr.Message)
			return
		}
		response.BadRequest(c, err.Error())
		return
	}

	targetType := "event"
	h.service.LogAction(orgID, actorID, "event.updated", &targetType, &eventID, nil, nil)
	response.Success(c, ev)
}

// GetEventAttendees gets the attendees for an event
func (h *Handler) GetEventAttendees(c *gin.Context) {
	if !requireOrgRole(c, models.OrgRoleViewer) {
		return
	}
	orgID := getOrgID(c)

	eventID, err := uuid.Parse(c.Param("event_id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	page := 1
	pageSize := 20
	// Try parsing query params if needed...

	search := c.Query("search")

	resp, err := h.service.GetEventAttendees(orgID, eventID, page, pageSize, search)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Success(c, resp)
}

// CancelEvent cancels an event
func (h *Handler) CancelEvent(c *gin.Context) {
	if !requireOrgRole(c, models.OrgRoleEventManager) {
		return
	}
	orgID := getOrgID(c)
	actorID := getActorID(c)

	eventID, err := uuid.Parse(c.Param("event_id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	if err := h.service.CancelEvent(orgID, eventID); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	targetType := "event"
	h.service.LogAction(orgID, actorID, "event.cancelled", &targetType, &eventID, nil, nil)
	response.SuccessWithMessage(c, "Event cancelled", nil)
}

// DuplicateEvent duplicates an event
func (h *Handler) DuplicateEvent(c *gin.Context) {
	if !requireOrgRole(c, models.OrgRoleEventManager) {
		return
	}
	orgID := getOrgID(c)
	actorID := getActorID(c)

	eventID, err := uuid.Parse(c.Param("event_id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	ev, err := h.service.DuplicateEvent(orgID, eventID)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	targetType := "event"
	h.service.LogAction(orgID, actorID, "event.duplicated", &targetType, &ev.ID, map[string]string{"source_event_id": eventID.String()}, nil)
	response.Created(c, ev)
}

// ── Members ──

// ListMembers lists org members
func (h *Handler) ListMembers(c *gin.Context) {
	members, err := h.service.ListMembers(getOrgID(c))
	if err != nil {
		response.InternalServerError(c, "Failed to list members")
		return
	}
	response.Success(c, members)
}

// AddMember adds a member
func (h *Handler) AddMember(c *gin.Context) {
	if !requireOrgRole(c, models.OrgRoleAdmin) {
		return
	}
	orgID := getOrgID(c)
	actorID := getActorID(c)

	var req struct {
		Email string `json:"email" binding:"required,email"`
		Role  string `json:"role" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	member, err := h.service.AddMember(orgID, req.Email, req.Role)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	targetType := "member"
	h.service.LogAction(orgID, actorID, "member.added", &targetType, &member.ID, map[string]string{"email": req.Email, "role": req.Role}, nil)
	response.Created(c, member)
}

// UpdateMemberRole changes a member's role
func (h *Handler) UpdateMemberRole(c *gin.Context) {
	if !requireOrgRole(c, models.OrgRoleAdmin) {
		return
	}
	orgID := getOrgID(c)
	actorID := getActorID(c)

	memberID, err := uuid.Parse(c.Param("member_id"))
	if err != nil {
		response.BadRequest(c, "Invalid member ID")
		return
	}

	var req struct {
		Role string `json:"role" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	if err := h.service.UpdateMemberRole(memberID, req.Role); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	targetType := "member"
	h.service.LogAction(orgID, actorID, "member.role_changed", &targetType, &memberID, map[string]string{"new_role": req.Role}, nil)
	response.SuccessWithMessage(c, "Role updated", nil)
}

// RemoveMember removes a member
func (h *Handler) RemoveMember(c *gin.Context) {
	if !requireOrgRole(c, models.OrgRoleAdmin) {
		return
	}
	orgID := getOrgID(c)
	actorID := getActorID(c)

	memberID, err := uuid.Parse(c.Param("member_id"))
	if err != nil {
		response.BadRequest(c, "Invalid member ID")
		return
	}

	if err := h.service.RemoveMember(memberID); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	targetType := "member"
	h.service.LogAction(orgID, actorID, "member.removed", &targetType, &memberID, nil, nil)
	response.SuccessWithMessage(c, "Member removed", nil)
}

// ── Profile ──

// GetProfile returns the org profile
func (h *Handler) GetProfile(c *gin.Context) {
	org, err := h.service.GetProfile(getOrgID(c))
	if err != nil {
		response.NotFound(c, "Organization not found")
		return
	}
	response.Success(c, org)
}

// UpdateProfile updates the org profile
func (h *Handler) UpdateProfile(c *gin.Context) {
	if !requireOrgRole(c, models.OrgRoleAdmin) {
		return
	}
	orgID := getOrgID(c)
	actorID := getActorID(c)

	var req UpdateOrgProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	org, err := h.service.UpdateProfile(orgID, &req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	targetType := "profile"
	h.service.LogAction(orgID, actorID, "profile.updated", &targetType, &orgID, nil, nil)
	response.Success(c, org)
}
