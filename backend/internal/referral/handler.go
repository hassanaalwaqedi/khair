package referral

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"fmt"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/response"
)

const (
	inviterReward = 100
	inviteeReward = 50
)

// Service handles referral logic.
type Service struct {
	db *sql.DB
}

// NewService creates a new referral service.
func NewService(db *sql.DB) *Service {
	return &Service{db: db}
}

// GenerateCode creates a unique referral code for a user (idempotent).
func (s *Service) GenerateCode(userID uuid.UUID) (string, error) {
	// Check if user already has a code
	var existing sql.NullString
	err := s.db.QueryRow(`SELECT referral_code FROM users WHERE id = $1`, userID).Scan(&existing)
	if err != nil {
		return "", fmt.Errorf("query user: %w", err)
	}
	if existing.Valid && existing.String != "" {
		return existing.String, nil
	}

	// Generate 6-byte random code
	b := make([]byte, 6)
	rand.Read(b)
	code := "KH" + hex.EncodeToString(b)[:8]

	_, err = s.db.Exec(`UPDATE users SET referral_code = $1 WHERE id = $2`, code, userID)
	if err != nil {
		return "", fmt.Errorf("set referral code: %w", err)
	}
	return code, nil
}

// ApplyCode applies a referral code for a new user.
func (s *Service) ApplyCode(inviteeID uuid.UUID, code string) error {
	// Find the inviter
	var inviterID uuid.UUID
	err := s.db.QueryRow(`SELECT id FROM users WHERE referral_code = $1`, code).Scan(&inviterID)
	if err != nil {
		return fmt.Errorf("invalid referral code")
	}

	// Prevent self-referral
	if inviterID == inviteeID {
		return fmt.Errorf("cannot refer yourself")
	}

	// Check if already referred
	var exists bool
	s.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM referrals WHERE invitee_id = $1)`, inviteeID).Scan(&exists)
	if exists {
		return fmt.Errorf("already used a referral code")
	}

	// Create referral record
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	_, err = tx.Exec(`
		INSERT INTO referrals (inviter_id, invitee_id, status, inviter_reward, invitee_reward)
		VALUES ($1, $2, 'rewarded', $3, $4)
	`, inviterID, inviteeID, inviterReward, inviteeReward)
	if err != nil {
		return fmt.Errorf("create referral: %w", err)
	}

	// Award points
	_, err = tx.Exec(`UPDATE users SET reward_points = reward_points + $1, referred_by = $2 WHERE id = $3`,
		inviteeReward, inviterID, inviteeID)
	if err != nil {
		return fmt.Errorf("award invitee: %w", err)
	}

	_, err = tx.Exec(`UPDATE users SET reward_points = reward_points + $1 WHERE id = $2`,
		inviterReward, inviterID)
	if err != nil {
		return fmt.Errorf("award inviter: %w", err)
	}

	return tx.Commit()
}

// Stats represents referral statistics for a user.
type Stats struct {
	ReferralCode  string `json:"referral_code"`
	TotalReferred int    `json:"total_referred"`
	TotalPoints   int    `json:"total_points"`
	RewardPoints  int    `json:"reward_points"`
}

// GetStats returns referral stats for a user.
func (s *Service) GetStats(userID uuid.UUID) (*Stats, error) {
	stats := &Stats{}

	// Get or generate referral code
	code, err := s.GenerateCode(userID)
	if err != nil {
		return nil, err
	}
	stats.ReferralCode = code

	s.db.QueryRow(`SELECT COUNT(*) FROM referrals WHERE inviter_id = $1`, userID).Scan(&stats.TotalReferred)
	s.db.QueryRow(`SELECT COALESCE(SUM(inviter_reward), 0) FROM referrals WHERE inviter_id = $1`, userID).Scan(&stats.TotalPoints)
	s.db.QueryRow(`SELECT reward_points FROM users WHERE id = $1`, userID).Scan(&stats.RewardPoints)

	return stats, nil
}

// ── Handler ──

// Handler handles referral HTTP endpoints.
type Handler struct {
	service *Service
}

// NewHandler creates a new referral handler.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers referral routes.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	ref := r.Group("/referral", authMiddleware)
	{
		ref.POST("/apply", h.Apply)
		ref.GET("/stats", h.GetStats)
		ref.GET("/code", h.GetCode)
	}
}

// ApplyRequest is the request body for applying a referral code.
type ApplyRequest struct {
	Code string `json:"code" binding:"required"`
}

// Apply handles POST /referral/apply
func (h *Handler) Apply(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid := userID.(uuid.UUID)

	var req ApplyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Referral code is required")
		return
	}

	if err := h.service.ApplyCode(uid, req.Code); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, "Referral code applied successfully", nil)
}

// GetStats handles GET /referral/stats
func (h *Handler) GetStats(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid := userID.(uuid.UUID)

	stats, err := h.service.GetStats(uid)
	if err != nil {
		response.InternalServerError(c, "Failed to get referral stats")
		return
	}
	response.Success(c, stats)
}

// GetCode handles GET /referral/code
func (h *Handler) GetCode(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid := userID.(uuid.UUID)

	code, err := h.service.GenerateCode(uid)
	if err != nil {
		response.InternalServerError(c, "Failed to generate referral code")
		return
	}
	response.Success(c, gin.H{"referral_code": code})
}
