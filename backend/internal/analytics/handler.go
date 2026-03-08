package analytics

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/khair/backend/pkg/response"
)

// Service provides analytics queries.
type Service struct {
	db *sql.DB
}

// NewService creates a new analytics service.
func NewService(db *sql.DB) *Service {
	return &Service{db: db}
}

// Overview contains top-level platform metrics.
type Overview struct {
	TotalUsers      int64   `json:"total_users"`
	ActiveUsers     int64   `json:"active_users"`
	TotalOrganizers int64   `json:"total_organizers"`
	TotalEvents     int64   `json:"total_events"`
	ApprovedEvents  int64   `json:"approved_events"`
	PendingEvents   int64   `json:"pending_events"`
	ApprovalRate    float64 `json:"approval_rate"`
	TotalAttendees  int64   `json:"total_attendees"`
}

// GetOverview returns platform-wide metrics.
func (s *Service) GetOverview() (*Overview, error) {
	o := &Overview{}

	_ = s.db.QueryRow(`SELECT COUNT(*) FROM users`).Scan(&o.TotalUsers)
	_ = s.db.QueryRow(`SELECT COUNT(*) FROM users WHERE updated_at > NOW() - interval '30 days'`).Scan(&o.ActiveUsers)
	_ = s.db.QueryRow(`SELECT COUNT(*) FROM organizers`).Scan(&o.TotalOrganizers)
	_ = s.db.QueryRow(`SELECT COUNT(*) FROM events`).Scan(&o.TotalEvents)
	_ = s.db.QueryRow(`SELECT COUNT(*) FROM events WHERE status = 'approved'`).Scan(&o.ApprovedEvents)
	_ = s.db.QueryRow(`SELECT COUNT(*) FROM events WHERE status = 'pending'`).Scan(&o.PendingEvents)

	if o.TotalEvents > 0 {
		o.ApprovalRate = float64(o.ApprovedEvents) / float64(o.TotalEvents) * 100
	}

	// Total attendees (registrations)
	_ = s.db.QueryRow(`SELECT COUNT(*) FROM attendees`).Scan(&o.TotalAttendees)

	return o, nil
}

// EventMetrics contains event-related analytics.
type EventMetrics struct {
	ByCategory []CategoryCount `json:"by_category"`
	ByCountry  []CountryCount  `json:"by_country"`
	ByMonth    []MonthCount    `json:"by_month"`
}

// CategoryCount is events per category.
type CategoryCount struct {
	Category string `json:"category"`
	Count    int64  `json:"count"`
}

// CountryCount is events per country.
type CountryCount struct {
	Country string `json:"country"`
	Count   int64  `json:"count"`
}

// MonthCount is events per month.
type MonthCount struct {
	Month string `json:"month"`
	Count int64  `json:"count"`
}

// GetEventMetrics returns event analytics.
func (s *Service) GetEventMetrics() (*EventMetrics, error) {
	m := &EventMetrics{}

	// By category
	rows, err := s.db.Query(`
		SELECT COALESCE(event_type, 'unknown'), COUNT(*)
		FROM events GROUP BY event_type ORDER BY COUNT(*) DESC LIMIT 20
	`)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var c CategoryCount
			rows.Scan(&c.Category, &c.Count)
			m.ByCategory = append(m.ByCategory, c)
		}
	}

	// By country
	rows2, err := s.db.Query(`
		SELECT COALESCE(country, 'unknown'), COUNT(*)
		FROM events GROUP BY country ORDER BY COUNT(*) DESC LIMIT 20
	`)
	if err == nil {
		defer rows2.Close()
		for rows2.Next() {
			var c CountryCount
			rows2.Scan(&c.Country, &c.Count)
			m.ByCountry = append(m.ByCountry, c)
		}
	}

	// By month (last 12 months)
	rows3, err := s.db.Query(`
		SELECT TO_CHAR(created_at, 'YYYY-MM') AS month, COUNT(*)
		FROM events WHERE created_at > NOW() - interval '12 months'
		GROUP BY month ORDER BY month
	`)
	if err == nil {
		defer rows3.Close()
		for rows3.Next() {
			var c MonthCount
			rows3.Scan(&c.Month, &c.Count)
			m.ByMonth = append(m.ByMonth, c)
		}
	}

	return m, nil
}

// UserMetrics contains user analytics.
type UserMetrics struct {
	TotalUsers    int64       `json:"total_users"`
	NewThisMonth  int64       `json:"new_this_month"`
	NewLastMonth  int64       `json:"new_last_month"`
	GrowthPercent float64     `json:"growth_percent"`
	ByRole        []RoleCount `json:"by_role"`
}

// RoleCount is users per role.
type RoleCount struct {
	Role  string `json:"role"`
	Count int64  `json:"count"`
}

// GetUserMetrics returns user analytics.
func (s *Service) GetUserMetrics() (*UserMetrics, error) {
	m := &UserMetrics{}

	_ = s.db.QueryRow(`SELECT COUNT(*) FROM users`).Scan(&m.TotalUsers)

	now := time.Now()
	startOfMonth := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	startOfLastMonth := startOfMonth.AddDate(0, -1, 0)

	_ = s.db.QueryRow(`SELECT COUNT(*) FROM users WHERE created_at >= $1`, startOfMonth).Scan(&m.NewThisMonth)
	_ = s.db.QueryRow(`SELECT COUNT(*) FROM users WHERE created_at >= $1 AND created_at < $2`, startOfLastMonth, startOfMonth).Scan(&m.NewLastMonth)

	if m.NewLastMonth > 0 {
		m.GrowthPercent = float64(m.NewThisMonth-m.NewLastMonth) / float64(m.NewLastMonth) * 100
	}

	rows, err := s.db.Query(`SELECT role, COUNT(*) FROM users GROUP BY role ORDER BY COUNT(*) DESC`)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var r RoleCount
			rows.Scan(&r.Role, &r.Count)
			m.ByRole = append(m.ByRole, r)
		}
	}

	return m, nil
}

// ── Handler ──

// Handler handles analytics HTTP endpoints.
type Handler struct {
	service *Service
}

// NewHandler creates a new analytics handler.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers analytics routes under /admin/analytics.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	analytics := r.Group("/analytics")
	{
		analytics.GET("/overview", h.GetOverview)
		analytics.GET("/events", h.GetEvents)
		analytics.GET("/users", h.GetUsers)
	}
}

// GetOverview handles GET /admin/analytics/overview
func (h *Handler) GetOverview(c *gin.Context) {
	overview, err := h.service.GetOverview()
	if err != nil {
		response.InternalServerError(c, "Failed to get analytics")
		return
	}
	response.Success(c, overview)
}

// GetEvents handles GET /admin/analytics/events
func (h *Handler) GetEvents(c *gin.Context) {
	metrics, err := h.service.GetEventMetrics()
	if err != nil {
		response.InternalServerError(c, "Failed to get event metrics")
		return
	}
	response.Success(c, metrics)
}

// GetUsers handles GET /admin/analytics/users
func (h *Handler) GetUsers(c *gin.Context) {
	metrics, err := h.service.GetUserMetrics()
	if err != nil {
		response.Error(c, http.StatusInternalServerError, "Failed to get user metrics")
		return
	}
	response.Success(c, metrics)
}
