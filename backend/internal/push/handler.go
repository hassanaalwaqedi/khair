package push

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/fcm"
	"github.com/khair/backend/pkg/response"
)

// Service manages authenticated device registrations and sends FCM messages.
type Service struct {
	db  *sql.DB
	fcm *fcm.Client
}

// NewService creates a new push notification service.
func NewService(db *sql.DB, fcmClient *fcm.Client) *Service {
	return &Service{db: db, fcm: fcmClient}
}

// RegisterToken assigns a physical device token to the authenticated account.
// The unique token constraint deliberately moves a shared device to its most
// recently authenticated user, preventing User A from receiving User B's push.
func (s *Service) RegisterToken(userID uuid.UUID, token, platform string) error {
	token = strings.TrimSpace(token)
	platform = strings.ToLower(strings.TrimSpace(platform))
	if len(token) < 20 || len(token) > 4096 {
		return fmt.Errorf("invalid device token")
	}
	if platform != "android" && platform != "ios" && platform != "web" {
		return fmt.Errorf("invalid device platform")
	}

	_, err := s.db.Exec(`
		INSERT INTO device_tokens (user_id, token, platform, last_seen_at, is_active)
		VALUES ($1, $2, $3, NOW(), true)
		ON CONFLICT (token) DO UPDATE SET
			user_id = EXCLUDED.user_id,
			platform = EXCLUDED.platform,
			last_seen_at = NOW(),
			is_active = true,
			updated_at = NOW()
	`, userID, token, platform)
	if err != nil {
		return fmt.Errorf("register device token: %w", err)
	}
	return nil
}

// RemoveToken deactivates only the current authenticated user's token.
func (s *Service) RemoveToken(userID uuid.UUID, token string) error {
	_, err := s.db.Exec(`
		UPDATE device_tokens
		SET is_active = false, updated_at = NOW()
		WHERE user_id = $1 AND token = $2
	`, userID, strings.TrimSpace(token))
	return err
}

// DeactivateToken retires a token Firebase has declared invalid. It is not
// scoped to a user because Firebase is the authoritative source for that
// device-token lifecycle event.
func (s *Service) DeactivateToken(token string) error {
	_, err := s.db.Exec(`
		UPDATE device_tokens
		SET is_active = false, updated_at = NOW()
		WHERE token = $1
	`, token)
	return err
}

// GetUserTokens returns every active device token for a user.
func (s *Service) GetUserTokens(userID uuid.UUID) ([]string, error) {
	rows, err := s.db.Query(`
		SELECT token FROM device_tokens
		WHERE user_id = $1 AND is_active = true
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tokens []string
	for rows.Next() {
		var token string
		if err := rows.Scan(&token); err != nil {
			return nil, err
		}
		tokens = append(tokens, token)
	}
	return tokens, rows.Err()
}

// SendToUser delivers a notification to every active device for the account.
// Notification content is persisted before this method is invoked; this method
// only transports it and safely records its delivery outcome.
func (s *Service) SendToUser(userID uuid.UUID, title, body string, data map[string]string) {
	start := time.Now()
	payload := publicFCMData(data)
	notificationID := strings.TrimSpace(payload["notification_id"])
	notificationType := strings.TrimSpace(payload["type"])

	if s == nil || s.fcm == nil || !s.fcm.IsEnabled() {
		log.Printf("[PUSH] delivery_skipped notification_id=%q type=%q user_id=%s reason=%q",
			notificationID, notificationType, userID, "fcm_not_configured")
		return
	}

	tokens, err := s.GetUserTokens(userID)
	if err != nil {
		log.Printf("[PUSH] delivery_failed notification_id=%q type=%q user_id=%s reason=%q",
			notificationID, notificationType, userID, "token_lookup_failed")
		return
	}
	if len(tokens) == 0 {
		log.Printf("[PUSH] delivery_skipped notification_id=%q type=%q user_id=%s reason=%q",
			notificationID, notificationType, userID, "no_active_devices")
		return
	}

	for _, result := range s.fcm.SendToMultiple(tokens, title, body, payload) {
		latencyMs := time.Since(start).Milliseconds()
		if result.Err == nil {
			log.Printf("[PUSH] delivery_sent notification_id=%q type=%q user_id=%s device_count=%d attempts=%d latency_ms=%d",
				notificationID, notificationType, userID, len(tokens), result.Attempts, latencyMs)
			continue
		}
		if fcm.IsInvalidToken(result.Err) {
			if err := s.DeactivateToken(result.Token); err != nil {
				log.Printf("[PUSH] invalid_token_cleanup_failed notification_id=%q type=%q user_id=%s",
					notificationID, notificationType, userID)
				continue
			}
			log.Printf("[PUSH] token_deactivated notification_id=%q type=%q user_id=%s attempts=%d latency_ms=%d",
				notificationID, notificationType, userID, result.Attempts, latencyMs)
			continue
		}
		log.Printf("[PUSH] delivery_failed notification_id=%q type=%q user_id=%s category=%q attempts=%d latency_ms=%d",
			notificationID, notificationType, userID, deliveryFailureCategory(result.Err), result.Attempts, latencyMs)
	}
}

// publicFCMData is a final server-side privacy boundary. Business services may
// retain richer metadata in the authenticated notification center, but only
// navigation identifiers and non-sensitive status enter Firebase payloads.
// NEVER add: JWT tokens, FCM tokens, email, phone, message body, or OTP codes.
func publicFCMData(data map[string]string) map[string]string {
	allowed := map[string]struct{}{
		"notification_id": {},
		"type":            {},
		"status":          {},
		"entity_type":     {},
		"entity_id":       {},
		"event_id":        {},
		"application_id":  {},
		"ticket_id":       {},
		"announcement_id": {},
		// Messaging routing metadata (no content, no PII)
		"conversation_id": {},
		"message_id":      {},
		"sender_id":       {},
	}
	payload := make(map[string]string, len(allowed))
	for key, value := range data {
		if _, ok := allowed[key]; ok && strings.TrimSpace(value) != "" {
			payload[key] = value
		}
	}
	return payload
}

func deliveryFailureCategory(err error) string {
	if fcm.IsTransient(err) {
		return "transient"
	}
	if fcm.IsInvalidToken(err) {
		return "invalid_token"
	}
	return "permanent"
}

// Handler handles authenticated device token endpoints.
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
		devices.DELETE("", h.Unregister)
		// Kept temporarily for already-released clients. New clients send the
		// token in an authenticated JSON body, not in the request URL.
		devices.DELETE("/:token", h.UnregisterLegacy)
	}
}

// RegisterRequest is the request body for registering a device token.
type RegisterRequest struct {
	Token    string `json:"token" binding:"required"`
	Platform string `json:"platform" binding:"required,oneof=android ios web"`
}

type unregisterRequest struct {
	Token string `json:"token" binding:"required"`
}

// Register handles POST /devices.
func (h *Handler) Register(c *gin.Context) {
	uid, ok := authenticatedUserID(c)
	if !ok {
		response.Error(c, http.StatusUnauthorized, "Not authenticated")
		return
	}

	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Token and platform are required")
		return
	}
	if err := h.service.RegisterToken(uid, req.Token, req.Platform); err != nil {
		response.BadRequest(c, "Invalid device registration")
		return
	}

	response.SuccessWithMessage(c, "Device registered", nil)
}

// Unregister handles DELETE /devices.
func (h *Handler) Unregister(c *gin.Context) {
	uid, ok := authenticatedUserID(c)
	if !ok {
		response.Error(c, http.StatusUnauthorized, "Not authenticated")
		return
	}
	var req unregisterRequest
	if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.Token) == "" {
		response.BadRequest(c, "Device token is required")
		return
	}
	h.remove(c, uid, req.Token)
}

// UnregisterLegacy handles DELETE /devices/:token for existing clients.
func (h *Handler) UnregisterLegacy(c *gin.Context) {
	uid, ok := authenticatedUserID(c)
	if !ok {
		response.Error(c, http.StatusUnauthorized, "Not authenticated")
		return
	}
	h.remove(c, uid, c.Param("token"))
}

func (h *Handler) remove(c *gin.Context, userID uuid.UUID, token string) {
	if err := h.service.RemoveToken(userID, token); err != nil {
		response.InternalServerError(c, "Failed to unregister device")
		return
	}
	response.SuccessWithMessage(c, "Device unregistered", nil)
}

func authenticatedUserID(c *gin.Context) (uuid.UUID, bool) {
	userID, exists := c.Get("user_id")
	if !exists {
		return uuid.Nil, false
	}
	uid, ok := userID.(uuid.UUID)
	return uid, ok && uid != uuid.Nil
}
