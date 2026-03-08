package reputation

import (
	"database/sql"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/response"
)

// Score represents an organizer's reputation breakdown.
type Score struct {
	OrganizerID     uuid.UUID `json:"organizer_id"`
	OrganizerName   string    `json:"organizer_name"`
	CompletedEvents int       `json:"completed_events"`
	CancelledEvents int       `json:"cancelled_events"`
	TotalAttendees  int       `json:"total_attendees"`
	AvgRating       float64   `json:"avg_rating"`
	ReputationScore float64   `json:"reputation_score"`
	IsVerified      bool      `json:"is_verified"`
}

// Service handles organizer reputation.
type Service struct {
	db *sql.DB
}

// NewService creates a new reputation service.
func NewService(db *sql.DB) *Service {
	return &Service{db: db}
}

// GetReputation returns the reputation score for an organizer.
func (s *Service) GetReputation(organizerID uuid.UUID) (*Score, error) {
	score := &Score{OrganizerID: organizerID}

	// Try cached reputation first
	err := s.db.QueryRow(`
		SELECT r.completed_events, r.cancelled_events, r.total_attendees,
		       r.avg_rating, r.reputation_score, r.is_verified, o.name
		FROM organizer_reputation r
		JOIN organizers o ON o.id = r.organizer_id
		WHERE r.organizer_id = $1
	`, organizerID).Scan(
		&score.CompletedEvents, &score.CancelledEvents, &score.TotalAttendees,
		&score.AvgRating, &score.ReputationScore, &score.IsVerified, &score.OrganizerName,
	)
	if err == sql.ErrNoRows {
		// Compute live
		return s.ComputeReputation(organizerID)
	}
	if err != nil {
		return nil, err
	}
	return score, nil
}

// ComputeReputation calculates and caches the reputation for an organizer.
func (s *Service) ComputeReputation(organizerID uuid.UUID) (*Score, error) {
	score := &Score{OrganizerID: organizerID}

	s.db.QueryRow(`SELECT name FROM organizers WHERE id = $1`, organizerID).Scan(&score.OrganizerName)
	s.db.QueryRow(`SELECT COUNT(*) FROM events WHERE organizer_id = $1 AND status = 'approved'`, organizerID).Scan(&score.CompletedEvents)
	s.db.QueryRow(`SELECT COUNT(*) FROM events WHERE organizer_id = $1 AND status = 'cancelled'`, organizerID).Scan(&score.CancelledEvents)
	s.db.QueryRow(`
		SELECT COUNT(*) FROM attendees a
		JOIN events e ON e.id = a.event_id
		WHERE e.organizer_id = $1
	`, organizerID).Scan(&score.TotalAttendees)

	// Average rating from all organizer's events
	s.db.QueryRow(`
		SELECT COALESCE(AVG(r.overall_rating), 0)
		FROM event_reviews r
		JOIN events e ON e.id = r.event_id
		WHERE e.organizer_id = $1
	`, organizerID).Scan(&score.AvgRating)

	// Reputation formula: weighted combination
	totalEvents := score.CompletedEvents + score.CancelledEvents
	completionRate := 0.0
	if totalEvents > 0 {
		completionRate = float64(score.CompletedEvents) / float64(totalEvents)
	}

	score.ReputationScore = (score.AvgRating * 20) + (completionRate * 50) + float64(min(score.CompletedEvents, 10))*3
	if score.ReputationScore > 100 {
		score.ReputationScore = 100
	}

	score.IsVerified = score.ReputationScore >= 70 && score.CompletedEvents >= 3

	// Upsert cached score
	s.db.Exec(`
		INSERT INTO organizer_reputation (organizer_id, completed_events, cancelled_events,
			total_attendees, avg_rating, reputation_score, is_verified)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		ON CONFLICT (organizer_id) DO UPDATE SET
			completed_events = $2, cancelled_events = $3, total_attendees = $4,
			avg_rating = $5, reputation_score = $6, is_verified = $7, updated_at = NOW()
	`, organizerID, score.CompletedEvents, score.CancelledEvents, score.TotalAttendees,
		score.AvgRating, score.ReputationScore, score.IsVerified)

	return score, nil
}

// ── Handler ──

// Handler handles reputation HTTP endpoints.
type Handler struct {
	service *Service
}

// NewHandler creates a new reputation handler.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers reputation routes.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	r.GET("/organizers/:id/reputation", h.GetReputation)
}

// GetReputation handles GET /organizers/:id/reputation
func (h *Handler) GetReputation(c *gin.Context) {
	orgID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid organizer ID")
		return
	}

	score, err := h.service.GetReputation(orgID)
	if err != nil {
		response.InternalServerError(c, "Failed to get reputation")
		return
	}
	response.Success(c, score)
}
