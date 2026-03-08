package growthanalytics

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/khair/backend/pkg/response"
)

// Service provides growth analytics.
type Service struct {
	db *sql.DB
}

// NewService creates a new growth analytics service.
func NewService(db *sql.DB) *Service {
	return &Service{db: db}
}

// GrowthOverview contains top-level growth metrics.
type GrowthOverview struct {
	DAU                int64   `json:"dau"`
	WAU                int64   `json:"wau"`
	MAU                int64   `json:"mau"`
	TotalRegistrations int64   `json:"total_registrations"`
	NewUsersToday      int64   `json:"new_users_today"`
	NewUsersThisWeek   int64   `json:"new_users_this_week"`
	EventsCreatedToday int64   `json:"events_created_today"`
	EventsThisMonth    int64   `json:"events_this_month"`
	AvgEventsPerDay    float64 `json:"avg_events_per_day"`
}

// GetOverview returns growth metrics.
func (s *Service) GetOverview() (*GrowthOverview, error) {
	o := &GrowthOverview{}
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	weekAgo := today.AddDate(0, 0, -7)
	monthAgo := today.AddDate(0, -1, 0)

	// Active users (based on updated_at as proxy)
	s.db.QueryRow(`SELECT COUNT(*) FROM users WHERE updated_at >= $1`, today).Scan(&o.DAU)
	s.db.QueryRow(`SELECT COUNT(*) FROM users WHERE updated_at >= $1`, weekAgo).Scan(&o.WAU)
	s.db.QueryRow(`SELECT COUNT(*) FROM users WHERE updated_at >= $1`, monthAgo).Scan(&o.MAU)

	s.db.QueryRow(`SELECT COUNT(*) FROM users`).Scan(&o.TotalRegistrations)
	s.db.QueryRow(`SELECT COUNT(*) FROM users WHERE created_at >= $1`, today).Scan(&o.NewUsersToday)
	s.db.QueryRow(`SELECT COUNT(*) FROM users WHERE created_at >= $1`, weekAgo).Scan(&o.NewUsersThisWeek)
	s.db.QueryRow(`SELECT COUNT(*) FROM events WHERE created_at >= $1`, today).Scan(&o.EventsCreatedToday)
	s.db.QueryRow(`SELECT COUNT(*) FROM events WHERE created_at >= $1`, monthAgo).Scan(&o.EventsThisMonth)

	// Avg events per day (last 30 days)
	if o.EventsThisMonth > 0 {
		o.AvgEventsPerDay = float64(o.EventsThisMonth) / 30.0
	}

	return o, nil
}

// RetentionCohort tracks users who returned after registration.
type RetentionCohort struct {
	CohortWeek  string  `json:"cohort_week"`
	UsersJoined int64   `json:"users_joined"`
	ReturnedW1  int64   `json:"returned_w1"`
	ReturnedW2  int64   `json:"returned_w2"`
	RetentionW1 float64 `json:"retention_w1_pct"`
	RetentionW2 float64 `json:"retention_w2_pct"`
}

// GetRetention returns weekly retention cohorts (last 8 weeks).
func (s *Service) GetRetention() ([]RetentionCohort, error) {
	rows, err := s.db.Query(`
		WITH cohorts AS (
			SELECT DATE_TRUNC('week', created_at) AS cohort_week,
			       id AS user_id
			FROM users
			WHERE created_at > NOW() - interval '8 weeks'
		)
		SELECT
			TO_CHAR(c.cohort_week, 'YYYY-MM-DD') AS week,
			COUNT(DISTINCT c.user_id) AS joined,
			COUNT(DISTINCT CASE WHEN u.updated_at >= c.cohort_week + interval '1 week' THEN c.user_id END) AS returned_w1,
			COUNT(DISTINCT CASE WHEN u.updated_at >= c.cohort_week + interval '2 weeks' THEN c.user_id END) AS returned_w2
		FROM cohorts c
		JOIN users u ON u.id = c.user_id
		GROUP BY c.cohort_week
		ORDER BY c.cohort_week DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cohorts []RetentionCohort
	for rows.Next() {
		var c RetentionCohort
		rows.Scan(&c.CohortWeek, &c.UsersJoined, &c.ReturnedW1, &c.ReturnedW2)
		if c.UsersJoined > 0 {
			c.RetentionW1 = float64(c.ReturnedW1) / float64(c.UsersJoined) * 100
			c.RetentionW2 = float64(c.ReturnedW2) / float64(c.UsersJoined) * 100
		}
		cohorts = append(cohorts, c)
	}
	if cohorts == nil {
		cohorts = []RetentionCohort{}
	}
	return cohorts, nil
}

// ReferralFunnel tracks referral conversion.
type ReferralFunnel struct {
	TotalReferrals     int64   `json:"total_referrals"`
	CompletedReferrals int64   `json:"completed_referrals"`
	TotalPointsAwarded int64   `json:"total_points_awarded"`
	ConversionRate     float64 `json:"conversion_rate_pct"`
}

// GetReferralFunnel returns referral conversion data.
func (s *Service) GetReferralFunnel() (*ReferralFunnel, error) {
	f := &ReferralFunnel{}
	s.db.QueryRow(`SELECT COUNT(*) FROM referrals`).Scan(&f.TotalReferrals)
	s.db.QueryRow(`SELECT COUNT(*) FROM referrals WHERE status = 'rewarded'`).Scan(&f.CompletedReferrals)
	s.db.QueryRow(`SELECT COALESCE(SUM(inviter_reward + invitee_reward), 0) FROM referrals`).Scan(&f.TotalPointsAwarded)

	var totalUsers int64
	s.db.QueryRow(`SELECT COUNT(*) FROM users`).Scan(&totalUsers)
	if totalUsers > 0 {
		f.ConversionRate = float64(f.TotalReferrals) / float64(totalUsers) * 100
	}

	return f, nil
}

// ── Handler ──

// Handler handles growth analytics HTTP endpoints.
type Handler struct {
	service *Service
}

// NewHandler creates a new growth analytics handler.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers growth analytics routes under /admin/growth.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	growth := r.Group("/growth")
	{
		growth.GET("/overview", h.Overview)
		growth.GET("/retention", h.Retention)
		growth.GET("/referrals", h.Referrals)
	}
}

// Overview handles GET /admin/growth/overview
func (h *Handler) Overview(c *gin.Context) {
	overview, err := h.service.GetOverview()
	if err != nil {
		response.InternalServerError(c, "Failed to get growth overview")
		return
	}
	response.Success(c, overview)
}

// Retention handles GET /admin/growth/retention
func (h *Handler) Retention(c *gin.Context) {
	cohorts, err := h.service.GetRetention()
	if err != nil {
		response.Error(c, http.StatusInternalServerError, "Failed to get retention data")
		return
	}
	response.Success(c, cohorts)
}

// Referrals handles GET /admin/growth/referrals
func (h *Handler) Referrals(c *gin.Context) {
	funnel, err := h.service.GetReferralFunnel()
	if err != nil {
		response.InternalServerError(c, "Failed to get referral data")
		return
	}
	response.Success(c, funnel)
}
