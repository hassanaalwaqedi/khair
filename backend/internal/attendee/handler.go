package attendee

import (
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/response"
)

// Handler handles attendee HTTP requests
type Handler struct {
	service *Service
}

// NewHandler creates a new attendee handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// ListAttendees lists attendees for an event
func (h *Handler) ListAttendees(c *gin.Context) {
	orgID := c.MustGet("org_id").(uuid.UUID)

	eventID, err := uuid.Parse(c.Param("event_id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	// Verify event belongs to this org
	if err := h.service.VerifyEventOwnership(eventID, orgID); err != nil {
		response.NotFound(c, "Event not found in this organization")
		return
	}

	pageStr := c.DefaultQuery("page", "1")
	pageSizeStr := c.DefaultQuery("page_size", "20")
	page, _ := strconv.Atoi(pageStr)
	pageSize, _ := strconv.Atoi(pageSizeStr)

	var search, status *string
	if s := c.Query("search"); s != "" {
		search = &s
	}
	if s := c.Query("status"); s != "" {
		status = &s
	}

	attendees, count, err := h.service.ListByEvent(eventID, search, status, page, pageSize)
	if err != nil {
		response.InternalServerError(c, "Failed to list attendees")
		return
	}
	response.Paginated(c, attendees, page, pageSize, count)
}

// MarkAttendance marks attendance for an attendee
func (h *Handler) MarkAttendance(c *gin.Context) {
	regID, err := uuid.Parse(c.Param("reg_id"))
	if err != nil {
		response.BadRequest(c, "Invalid registration ID")
		return
	}

	var req struct {
		Attended bool `json:"attended"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request")
		return
	}

	if err := h.service.MarkAttendance(regID, req.Attended); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	response.SuccessWithMessage(c, "Attendance updated", nil)
}

// RemoveAttendee removes an attendee
func (h *Handler) RemoveAttendee(c *gin.Context) {
	regID, err := uuid.Parse(c.Param("reg_id"))
	if err != nil {
		response.BadRequest(c, "Invalid registration ID")
		return
	}

	if err := h.service.RemoveAttendee(regID); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	response.SuccessWithMessage(c, "Attendee removed", nil)
}

// ExportCSV exports attendees as CSV
func (h *Handler) ExportCSV(c *gin.Context) {
	orgID := c.MustGet("org_id").(uuid.UUID)

	eventID, err := uuid.Parse(c.Param("event_id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	if err := h.service.VerifyEventOwnership(eventID, orgID); err != nil {
		response.NotFound(c, "Event not found in this organization")
		return
	}

	csvData, err := h.service.ExportCSV(eventID)
	if err != nil {
		response.InternalServerError(c, "Failed to export attendees")
		return
	}

	c.Header("Content-Type", "text/csv")
	c.Header("Content-Disposition", "attachment; filename=attendees.csv")
	c.Data(200, "text/csv", csvData)
}
