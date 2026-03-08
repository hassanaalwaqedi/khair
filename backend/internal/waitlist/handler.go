package waitlist

import (
	"database/sql"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/response"
)

// Service handles waitlist logic.
type Service struct {
	db *sql.DB
}

// NewService creates a new waitlist service.
func NewService(db *sql.DB) *Service {
	return &Service{db: db}
}

// Join adds a user to the event waitlist.
func (s *Service) Join(eventID, userID uuid.UUID) (int, error) {
	// Get next position
	var maxPos sql.NullInt64
	s.db.QueryRow(`SELECT MAX(position) FROM event_waitlist WHERE event_id = $1`, eventID).Scan(&maxPos)
	nextPos := 1
	if maxPos.Valid {
		nextPos = int(maxPos.Int64) + 1
	}

	_, err := s.db.Exec(`
		INSERT INTO event_waitlist (event_id, user_id, position, status)
		VALUES ($1, $2, $3, 'waiting')
	`, eventID, userID, nextPos)
	if err != nil {
		return 0, fmt.Errorf("join waitlist: %w", err)
	}
	return nextPos, nil
}

// Leave removes a user from the waitlist.
func (s *Service) Leave(eventID, userID uuid.UUID) error {
	_, err := s.db.Exec(`DELETE FROM event_waitlist WHERE event_id = $1 AND user_id = $2`, eventID, userID)
	return err
}

// GetPosition returns the user's position on the waitlist.
func (s *Service) GetPosition(eventID, userID uuid.UUID) (int, string, error) {
	var pos int
	var status string
	err := s.db.QueryRow(`
		SELECT position, status FROM event_waitlist 
		WHERE event_id = $1 AND user_id = $2
	`, eventID, userID).Scan(&pos, &status)
	if err != nil {
		return 0, "", fmt.Errorf("not on waitlist")
	}
	return pos, status, nil
}

// PromoteNext offers the next spot to the first person on the waitlist.
func (s *Service) PromoteNext(eventID uuid.UUID) (*uuid.UUID, error) {
	var userID uuid.UUID
	err := s.db.QueryRow(`
		UPDATE event_waitlist SET status = 'offered'
		WHERE id = (
			SELECT id FROM event_waitlist
			WHERE event_id = $1 AND status = 'waiting'
			ORDER BY position ASC LIMIT 1
		)
		RETURNING user_id
	`, eventID).Scan(&userID)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil // no one on waitlist
		}
		return nil, err
	}
	return &userID, nil
}

// WaitlistCount returns the number of people on the waitlist.
func (s *Service) WaitlistCount(eventID uuid.UUID) int {
	var count int
	s.db.QueryRow(`SELECT COUNT(*) FROM event_waitlist WHERE event_id = $1 AND status = 'waiting'`, eventID).Scan(&count)
	return count
}

// ── Handler ──

// Handler handles waitlist HTTP endpoints.
type Handler struct {
	service *Service
}

// NewHandler creates a new waitlist handler.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers waitlist routes.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	r.POST("/events/:id/waitlist", authMiddleware, h.Join)
	r.DELETE("/events/:id/waitlist", authMiddleware, h.Leave)
	r.GET("/events/:id/waitlist/position", authMiddleware, h.Position)
}

// Join handles POST /events/:id/waitlist
func (h *Handler) Join(c *gin.Context) {
	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	userID, _ := c.Get("user_id")
	uid := userID.(uuid.UUID)

	pos, err := h.service.Join(eventID, uid)
	if err != nil {
		response.Error(c, http.StatusConflict, "Already on waitlist")
		return
	}

	response.Success(c, gin.H{
		"message":  "Added to waitlist",
		"position": pos,
	})
}

// Leave handles DELETE /events/:id/waitlist
func (h *Handler) Leave(c *gin.Context) {
	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	userID, _ := c.Get("user_id")
	uid := userID.(uuid.UUID)

	_ = h.service.Leave(eventID, uid)
	response.SuccessWithMessage(c, "Removed from waitlist", nil)
}

// Position handles GET /events/:id/waitlist/position
func (h *Handler) Position(c *gin.Context) {
	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	userID, _ := c.Get("user_id")
	uid := userID.(uuid.UUID)

	pos, status, err := h.service.GetPosition(eventID, uid)
	if err != nil {
		response.BadRequest(c, "Not on waitlist")
		return
	}

	response.Success(c, gin.H{
		"position":       pos,
		"status":         status,
		"total_waitlist": h.service.WaitlistCount(eventID),
	})
}
