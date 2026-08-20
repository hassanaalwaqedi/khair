package notification

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/khair/backend/pkg/response"

	"github.com/gin-gonic/gin"
)

const queryTimeout = 5 * time.Second

// Notification represents a user notification
type Notification struct {
	ID               uuid.UUID         `json:"id"`
	UserID           uuid.UUID         `json:"user_id"`
	Title            string            `json:"title"`
	Message          string            `json:"message"`
	NotificationType string            `json:"notification_type"`
	Data             map[string]string `json:"data"`
	IsRead           bool              `json:"is_read"`
	CreatedAt        time.Time         `json:"created_at"`
}

// Service handles notification business logic
type Service struct {
	db *sql.DB
}

// NewService creates a new notification service
func NewService(db *sql.DB) *Service {
	return &Service{db: db}
}

// Create inserts a new notification for a user
func (s *Service) Create(userID uuid.UUID, title, message string) error {
	return s.CreateTyped(userID, title, message, "general", nil)
}

// CreateTyped inserts a notification with type and data for deep linking
func (s *Service) CreateTyped(userID uuid.UUID, title, message, notifType string, data map[string]string) error {
	_, _, err := s.CreateTypedOnce(userID, title, message, notifType, data, "")
	return err
}

// CreateTypedWithID persists a notification and returns the authoritative
// notification ID used by the matching FCM payload.
func (s *Service) CreateTypedWithID(userID uuid.UUID, title, message, notifType string, data map[string]string) (uuid.UUID, error) {
	id, _, err := s.CreateTypedOnce(userID, title, message, notifType, data, "")
	return id, err
}

// CreateTypedOnce persists one logical notification at most once per user and
// dedupe key. The boolean is false when an API or worker retry already created
// the notification, in which case a second push must not be sent.
func (s *Service) CreateTypedOnce(userID uuid.UUID, title, message, notifType string, data map[string]string, dedupeKey string) (uuid.UUID, bool, error) {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	dataJSON, _ := json.Marshal(data)
	if data == nil {
		dataJSON = []byte("{}")
	}

	var id uuid.UUID
	if dedupeKey == "" {
		err := s.db.QueryRowContext(ctx,
			`INSERT INTO notifications (user_id, title, message, notification_type, data)
			 VALUES ($1, $2, $3, $4, $5)
			 RETURNING id`,
			userID, title, message, notifType, dataJSON,
		).Scan(&id)
		if err != nil {
			return uuid.Nil, false, fmt.Errorf("create notification: %w", err)
		}
		return id, true, nil
	}

	err := s.db.QueryRowContext(ctx,
		`INSERT INTO notifications (user_id, title, message, notification_type, data, dedupe_key)
		 VALUES ($1, $2, $3, $4, $5, $6)
		 ON CONFLICT (user_id, dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING
		 RETURNING id`,
		userID, title, message, notifType, dataJSON, dedupeKey,
	).Scan(&id)
	if err == nil {
		return id, true, nil
	}
	if err != sql.ErrNoRows {
		return uuid.Nil, false, fmt.Errorf("create notification: %w", err)
	}
	if err := s.db.QueryRowContext(ctx,
		`SELECT id FROM notifications WHERE user_id = $1 AND dedupe_key = $2`,
		userID, dedupeKey,
	).Scan(&id); err != nil {
		return uuid.Nil, false, fmt.Errorf("load deduplicated notification: %w", err)
	}
	return id, false, nil
}

// CreateForAll inserts a notification for every active user. Returns the count of users notified.
func (s *Service) CreateForAll(title, message string) (int64, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	result, err := s.db.ExecContext(ctx,
		`INSERT INTO notifications (user_id, title, message)
		 SELECT id, $1, $2 FROM users WHERE status != 'suspended'`,
		title, message,
	)
	if err != nil {
		return 0, fmt.Errorf("create notification for all: %w", err)
	}
	count, _ := result.RowsAffected()
	return count, nil
}

// ListByUserID returns all notifications for a user, newest first
func (s *Service) ListByUserID(userID uuid.UUID) ([]Notification, error) {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	rows, err := s.db.QueryContext(ctx,
		`SELECT id, user_id, title, message,
		        COALESCE(notification_type, 'general'),
		        COALESCE(data, '{}'),
		        is_read, created_at
		 FROM notifications WHERE user_id = $1
		 ORDER BY created_at DESC LIMIT 50`,
		userID,
	)
	if err != nil {
		// Fallback: try without notification_type and data columns (pre-migration)
		rows, err = s.db.QueryContext(ctx,
			`SELECT id, user_id, title, message, is_read, created_at
			 FROM notifications WHERE user_id = $1
			 ORDER BY created_at DESC LIMIT 50`,
			userID,
		)
		if err != nil {
			return nil, fmt.Errorf("list notifications: %w", err)
		}
		defer rows.Close()

		var notifications []Notification
		for rows.Next() {
			var n Notification
			if err := rows.Scan(&n.ID, &n.UserID, &n.Title, &n.Message, &n.IsRead, &n.CreatedAt); err != nil {
				return nil, fmt.Errorf("scan notification: %w", err)
			}
			n.NotificationType = "general"
			n.Data = map[string]string{}
			notifications = append(notifications, n)
		}
		if notifications == nil {
			notifications = []Notification{}
		}
		return notifications, nil
	}
	defer rows.Close()

	var notifications []Notification
	for rows.Next() {
		var n Notification
		var dataJSON []byte
		if err := rows.Scan(&n.ID, &n.UserID, &n.Title, &n.Message, &n.NotificationType, &dataJSON, &n.IsRead, &n.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan notification: %w", err)
		}
		if len(dataJSON) > 0 {
			_ = json.Unmarshal(dataJSON, &n.Data)
		}
		if n.Data == nil {
			n.Data = map[string]string{}
		}
		notifications = append(notifications, n)
	}
	if notifications == nil {
		notifications = []Notification{}
	}
	return notifications, nil
}

// GetUnreadCount returns the count of unread notifications for a user
func (s *Service) GetUnreadCount(userID uuid.UUID) (int, error) {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	var count int
	err := s.db.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = false`,
		userID,
	).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("get unread count: %w", err)
	}
	return count, nil
}

// MarkAsRead marks a single notification as read
func (s *Service) MarkAsRead(notificationID, userID uuid.UUID) error {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	_, err := s.db.ExecContext(ctx,
		`UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2`,
		notificationID, userID,
	)
	if err != nil {
		return fmt.Errorf("mark notification read: %w", err)
	}
	return nil
}

// MarkAllRead marks all notifications as read for a user
func (s *Service) MarkAllRead(userID uuid.UUID) error {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	_, err := s.db.ExecContext(ctx,
		`UPDATE notifications SET is_read = true WHERE user_id = $1 AND is_read = false`,
		userID,
	)
	if err != nil {
		return fmt.Errorf("mark all notifications read: %w", err)
	}
	return nil
}

// Handler handles notification HTTP requests
type Handler struct {
	service *Service
}

// NewHandler creates a new notification handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers notification routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	notifications := r.Group("/notifications")
	notifications.Use(authMiddleware)
	{
		notifications.GET("", h.List)
		notifications.GET("/unread-count", h.UnreadCount)
		notifications.PUT("/:id/read", h.MarkRead)
		notifications.PUT("/read-all", h.MarkAllRead)
	}
}

// List returns user's notifications
func (h *Handler) List(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, ok := userID.(uuid.UUID)
	if !ok {
		response.Unauthorized(c, "Invalid user session")
		return
	}

	notifications, err := h.service.ListByUserID(uid)
	if err != nil {
		fmt.Printf("[NOTIFICATION] Error listing notifications for user %s: %v\n", uid, err)
		response.InternalServerError(c, "Failed to load notifications")
		return
	}
	response.Success(c, notifications)
}

// UnreadCount returns unread notification count
func (h *Handler) UnreadCount(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, ok := userID.(uuid.UUID)
	if !ok {
		response.Success(c, gin.H{"unread_count": 0})
		return
	}

	count, err := h.service.GetUnreadCount(uid)
	if err != nil {
		fmt.Printf("[NOTIFICATION] Error getting unread count for user %s: %v\n", uid, err)
		response.Success(c, gin.H{"unread_count": 0})
		return
	}
	response.Success(c, gin.H{"unread_count": count})
}

// MarkRead marks a single notification as read
func (h *Handler) MarkRead(c *gin.Context) {
	notifID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid notification ID")
		return
	}

	userID, _ := c.Get("user_id")
	uid, _ := userID.(uuid.UUID)

	if err := h.service.MarkAsRead(notifID, uid); err != nil {
		response.InternalServerError(c, "Failed to mark notification as read")
		return
	}
	response.SuccessWithMessage(c, "Notification marked as read", nil)
}

// MarkAllRead marks all notifications as read for the user
func (h *Handler) MarkAllRead(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := userID.(uuid.UUID)

	if err := h.service.MarkAllRead(uid); err != nil {
		response.InternalServerError(c, "Failed to mark notifications as read")
		return
	}
	response.SuccessWithMessage(c, "All notifications marked as read", nil)
}
