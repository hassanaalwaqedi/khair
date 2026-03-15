package calendar

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/internal/event"
	"github.com/khair/backend/pkg/response"
)

// Handler handles calendar export endpoints
type Handler struct {
	eventService *event.Service
}

// NewHandler creates a new calendar handler
func NewHandler(eventService *event.Service) *Handler {
	return &Handler{eventService: eventService}
}

// RegisterRoutes registers calendar routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	r.GET("/events/:id/calendar", h.DownloadICS)
}

// DownloadICS generates and returns an .ics calendar file for an event
// GET /events/:id/calendar
func (h *Handler) DownloadICS(c *gin.Context) {
	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	evt, err := h.eventService.GetByID(eventID)
	if err != nil {
		response.NotFound(c, "Event not found")
		return
	}

	ics := generateICS(evt.Title, safeString(evt.Description), safeString(evt.Address),
		evt.StartDate, evt.EndDate, evt.ID.String())

	c.Header("Content-Type", "text/calendar; charset=utf-8")
	c.Header("Content-Disposition", fmt.Sprintf(`attachment; filename="%s.ics"`, sanitizeFilename(evt.Title)))
	c.String(http.StatusOK, ics)
}

// generateICS creates an iCalendar (.ics) file content
func generateICS(title, description, location string, startDate time.Time, endDate *time.Time, uid string) string {
	var b strings.Builder

	b.WriteString("BEGIN:VCALENDAR\r\n")
	b.WriteString("VERSION:2.0\r\n")
	b.WriteString("PRODID:-//Khair//Khair Events//EN\r\n")
	b.WriteString("CALSCALE:GREGORIAN\r\n")
	b.WriteString("METHOD:PUBLISH\r\n")

	b.WriteString("BEGIN:VEVENT\r\n")
	b.WriteString(fmt.Sprintf("UID:%s@khair.app\r\n", uid))
	b.WriteString(fmt.Sprintf("DTSTAMP:%s\r\n", formatICSDate(time.Now())))
	b.WriteString(fmt.Sprintf("DTSTART:%s\r\n", formatICSDate(startDate)))

	if endDate != nil {
		b.WriteString(fmt.Sprintf("DTEND:%s\r\n", formatICSDate(*endDate)))
	} else {
		// Default: 2 hours after start
		b.WriteString(fmt.Sprintf("DTEND:%s\r\n", formatICSDate(startDate.Add(2*time.Hour))))
	}

	b.WriteString(fmt.Sprintf("SUMMARY:%s\r\n", escapeICS(title)))

	if description != "" {
		b.WriteString(fmt.Sprintf("DESCRIPTION:%s\r\n", escapeICS(description)))
	}
	if location != "" {
		b.WriteString(fmt.Sprintf("LOCATION:%s\r\n", escapeICS(location)))
	}

	b.WriteString("STATUS:CONFIRMED\r\n")
	b.WriteString("END:VEVENT\r\n")
	b.WriteString("END:VCALENDAR\r\n")

	return b.String()
}

func formatICSDate(t time.Time) string {
	return t.UTC().Format("20060102T150405Z")
}

func escapeICS(s string) string {
	s = strings.ReplaceAll(s, "\\", "\\\\")
	s = strings.ReplaceAll(s, ",", "\\,")
	s = strings.ReplaceAll(s, ";", "\\;")
	s = strings.ReplaceAll(s, "\n", "\\n")
	return s
}

func sanitizeFilename(s string) string {
	s = strings.ReplaceAll(s, " ", "_")
	s = strings.ReplaceAll(s, "/", "_")
	s = strings.ReplaceAll(s, "\\", "_")
	if len(s) > 50 {
		s = s[:50]
	}
	return s
}

func safeString(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
