package review

import (
	"database/sql"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/response"
)

// Review represents an event review.
type Review struct {
	ID                 uuid.UUID `json:"id"`
	EventID            uuid.UUID `json:"event_id"`
	UserID             uuid.UUID `json:"user_id"`
	UserName           string    `json:"user_name"`
	OverallRating      int       `json:"overall_rating"`
	OrganizationRating *int      `json:"organization_rating,omitempty"`
	VenueRating        *int      `json:"venue_rating,omitempty"`
	Comment            *string   `json:"comment,omitempty"`
	CreatedAt          time.Time `json:"created_at"`
}

// EventRatingSummary is the aggregate rating for an event.
type EventRatingSummary struct {
	AverageRating   float64 `json:"average_rating"`
	TotalReviews    int     `json:"total_reviews"`
	AvgOrganization float64 `json:"avg_organization"`
	AvgVenue        float64 `json:"avg_venue"`
}

// Service handles review logic.
type Service struct {
	db *sql.DB
}

// NewService creates a new review service.
func NewService(db *sql.DB) *Service {
	return &Service{db: db}
}

// Create adds a review for an event.
func (s *Service) Create(eventID, userID uuid.UUID, overall int, org, venue *int, comment *string) error {
	_, err := s.db.Exec(`
		INSERT INTO event_reviews (event_id, user_id, overall_rating, organization_rating, venue_rating, comment)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, eventID, userID, overall, org, venue, comment)
	if err != nil {
		return fmt.Errorf("create review: %w", err)
	}
	return nil
}

// ListByEvent returns paginated reviews for an event.
func (s *Service) ListByEvent(eventID uuid.UUID, page, pageSize int) ([]Review, int, error) {
	offset := (page - 1) * pageSize

	var total int
	s.db.QueryRow(`SELECT COUNT(*) FROM event_reviews WHERE event_id = $1`, eventID).Scan(&total)

	rows, err := s.db.Query(`
		SELECT r.id, r.event_id, r.user_id, u.name, r.overall_rating,
		       r.organization_rating, r.venue_rating, r.comment, r.created_at
		FROM event_reviews r
		JOIN users u ON u.id = r.user_id
		WHERE r.event_id = $1
		ORDER BY r.created_at DESC
		LIMIT $2 OFFSET $3
	`, eventID, pageSize, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var reviews []Review
	for rows.Next() {
		var r Review
		rows.Scan(&r.ID, &r.EventID, &r.UserID, &r.UserName, &r.OverallRating,
			&r.OrganizationRating, &r.VenueRating, &r.Comment, &r.CreatedAt)
		reviews = append(reviews, r)
	}
	if reviews == nil {
		reviews = []Review{}
	}
	return reviews, total, nil
}

// GetSummary returns the aggregate rating for an event.
func (s *Service) GetSummary(eventID uuid.UUID) (*EventRatingSummary, error) {
	summary := &EventRatingSummary{}
	s.db.QueryRow(`
		SELECT COALESCE(AVG(overall_rating), 0), COUNT(*),
		       COALESCE(AVG(organization_rating), 0), COALESCE(AVG(venue_rating), 0)
		FROM event_reviews WHERE event_id = $1
	`, eventID).Scan(&summary.AverageRating, &summary.TotalReviews, &summary.AvgOrganization, &summary.AvgVenue)
	return summary, nil
}

// ── Handler ──

// Handler handles review HTTP endpoints.
type Handler struct {
	service *Service
}

// NewHandler creates a new review handler.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers review routes.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	r.GET("/events/:id/reviews", h.List)
	r.GET("/events/:id/reviews/summary", h.Summary)
	r.POST("/events/:id/reviews", authMiddleware, h.Create)
}

// CreateRequest is the request body for creating a review.
type CreateRequest struct {
	OverallRating      int     `json:"overall_rating" binding:"required,min=1,max=5"`
	OrganizationRating *int    `json:"organization_rating" binding:"omitempty,min=1,max=5"`
	VenueRating        *int    `json:"venue_rating" binding:"omitempty,min=1,max=5"`
	Comment            *string `json:"comment"`
}

// Create handles POST /events/:id/reviews
func (h *Handler) Create(c *gin.Context) {
	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	userID, _ := c.Get("user_id")
	uid := userID.(uuid.UUID)

	var req CreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Valid overall_rating (1-5) is required")
		return
	}

	if err := h.service.Create(eventID, uid, req.OverallRating, req.OrganizationRating, req.VenueRating, req.Comment); err != nil {
		response.Error(c, http.StatusConflict, "You have already reviewed this event")
		return
	}

	response.SuccessWithMessage(c, "Review submitted", nil)
}

// List handles GET /events/:id/reviews
func (h *Handler) List(c *gin.Context) {
	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "10"))

	reviews, total, err := h.service.ListByEvent(eventID, page, pageSize)
	if err != nil {
		response.InternalServerError(c, "Failed to list reviews")
		return
	}
	response.Paginated(c, reviews, page, pageSize, int64(total))
}

// Summary handles GET /events/:id/reviews/summary
func (h *Handler) Summary(c *gin.Context) {
	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	summary, err := h.service.GetSummary(eventID)
	if err != nil {
		response.InternalServerError(c, "Failed to get review summary")
		return
	}
	response.Success(c, summary)
}
