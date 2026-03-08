package push

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/fcm"
	"github.com/khair/backend/pkg/response"
)

// Service manages device tokens and sends push notifications.
type Service struct {
	db  *sql.DB
	fcm *fcm.Client
}

// NewService creates a new push notification service.
func NewService(db *sql.DB, fcmClient *fcm.Client) *Service {
	return &Service{db: db, fcm: fcmClient}
}

// RegisterToken stores a device token for a user.
func (s *Service) RegisterToken(userID uuid.UUID, token, platform string) error {
	_, err := s.db.Exec(`
		INSERT INTO device_tokens (user_id, token, platform)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id, token) DO UPDATE SET updated_at = NOW()
	`, userID, token, platform)
	if err != nil {
		return fmt.Errorf("register device token: %w", err)
	}
	return nil
}

// RemoveToken removes a device token.
func (s *Service) RemoveToken(userID uuid.UUID, token string) error {
	_, err := s.db.Exec(`DELETE FROM device_tokens WHERE user_id = $1 AND token = $2`, userID, token)
	return err
}

// GetUserTokens returns all device tokens for a user.
func (s *Service) GetUserTokens(userID uuid.UUID) ([]string, error) {
	rows, err := s.db.Query(`SELECT token FROM device_tokens WHERE user_id = $1`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tokens []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		tokens = append(tokens, t)
	}
	return tokens, nil
}

// SendToUser sends a push notification to all of a user's devices.
func (s *Service) SendToUser(userID uuid.UUID, title, body string, data map[string]string) {
	tokens, err := s.GetUserTokens(userID)
	if err != nil {
		log.Printf("[PUSH] Error getting tokens for %s: %v", userID, err)
		return
	}
	if len(tokens) == 0 {
		return
	}
	s.fcm.SendToMultiple(tokens, title, body, data)
}

// ── Handler ──

// Handler handles device token HTTP endpoints.
type Handler struct {
	service *Service
}

// NewHandler creates a new push handler.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers push notification routes.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	devices := r.Group("/devices", authMiddleware)
	{
		devices.POST("", h.Register)
		devices.DELETE("/:token", h.Unregister)
	}
}

// RegisterRequest is the request body for registering a device token.
type RegisterRequest struct {
	Token    string `json:"token" binding:"required"`
	Platform string `json:"platform" binding:"required,oneof=android ios web"`
}

// Register handles POST /devices
func (h *Handler) Register(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		response.Error(c, http.StatusUnauthorized, "Not authenticated")
		return
	}

	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Token and platform are required")
		return
	}

	uid := userID.(uuid.UUID)
	if err := h.service.RegisterToken(uid, req.Token, req.Platform); err != nil {
		response.InternalServerError(c, "Failed to register device")
		return
	}

	response.SuccessWithMessage(c, "Device registered", nil)
}

// Unregister handles DELETE /devices/:token
func (h *Handler) Unregister(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		response.Error(c, http.StatusUnauthorized, "Not authenticated")
		return
	}

	token := c.Param("token")
	uid := userID.(uuid.UUID)
	_ = h.service.RemoveToken(uid, token)

	response.SuccessWithMessage(c, "Device unregistered", nil)
}
