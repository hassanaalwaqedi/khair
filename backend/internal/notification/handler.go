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
	ID                    uuid.UUID         `json:"id"`
	UserID                uuid.UUID         `json:"user_id"`
	ActorUserID           *uuid.UUID        `json:"actor_user_id,omitempty"`
	Title                 string            `json:"title"`
	Message               string            `json:"message"`
	NotificationType      string            `json:"notification_type"`
	Data                  map[string]string `json:"data"`
	RelatedEventID        *uuid.UUID        `json:"related_event_id,omitempty"`
	RelatedConversationID *uuid.UUID        `json:"related_conversation_id,omitempty"`
	RelatedMessageID      *uuid.UUID        `json:"related_message_id,omitempty"`
	ActionURL             string            `json:"action_url,omitempty"`
	IsRead                bool              `json:"is_read"`
	ReadAt                *time.Time        `json:"read_at,omitempty"`
	CreatedAt             time.Time         `json:"created_at"`
}

// NotificationPreferences controls optional delivery channels. Essential
// safety and moderation notifications are never suppressed by these flags.
type NotificationPreferences struct {
	Messages               bool `json:"messages"`
	EventRegistrations     bool `json:"event_registrations"`
	EventUpdates           bool `json:"event_updates"`
	EventReminders         bool `json:"event_reminders"`
	OrganizerAnnouncements bool `json:"organizer_announcements"`
	SystemNotifications    bool `json:"system_notifications"`
	BrowserPush            bool `json:"browser_push"`
	EmailNotifications     bool `json:"email_notifications"`
}

// Service handles notification business logic
type Service struct {
	db       *sql.DB
	realtime RealtimePublisher
}

// RealtimePublisher is deliberately a small interface so notification does
// not import the WebSocket package (and remains easy to test). The API wires
// this to the authenticated user-targeted hub at startup.
type RealtimePublisher interface {
	BroadcastToUser(userID string, messageType string, data interface{})
}

// NewService creates a new notification service
func NewService(db *sql.DB) *Service {
	return &Service{db: db}
}

func (s *Service) SetRealtimePublisher(publisher RealtimePublisher) {
	s.realtime = publisher
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
		s.publishRealtime(userID, id, title, message, notifType, data)
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
		s.publishRealtime(userID, id, title, message, notifType, data)
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
		`SELECT id, user_id, actor_user_id, title, message,
		        related_event_id, related_conversation_id, related_message_id,
		        COALESCE(action_url, ''),
		        COALESCE(notification_type, 'general'),
		        COALESCE(data, '{}'),
		        is_read, read_at, created_at
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
		var actorID, eventID, conversationID, messageID sql.NullString
		if err := rows.Scan(&n.ID, &n.UserID, &actorID, &n.Title, &n.Message,
			&eventID, &conversationID, &messageID, &n.ActionURL,
			&n.NotificationType, &dataJSON, &n.IsRead, &n.ReadAt, &n.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan notification: %w", err)
		}
		n.ActorUserID = parseUUID(actorID)
		n.RelatedEventID = parseUUID(eventID)
		n.RelatedConversationID = parseUUID(conversationID)
		n.RelatedMessageID = parseUUID(messageID)
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
		`UPDATE notifications SET is_read = true, read_at = NOW() WHERE id = $1 AND user_id = $2`,
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
		`UPDATE notifications SET is_read = true, read_at = NOW() WHERE user_id = $1 AND is_read = false`,
		userID,
	)
	if err != nil {
		return fmt.Errorf("mark all notifications read: %w", err)
	}
	return nil
}

func (s *Service) publishRealtime(userID, notificationID uuid.UUID, title, message, notifType string, data map[string]string) {
	if s == nil || s.realtime == nil {
		return
	}
	payload := make(map[string]string, len(data)+5)
	for key, value := range data {
		payload[key] = value
	}
	payload["notification_id"] = notificationID.String()
	payload["type"] = notifType
	payload["title"] = title
	payload["message"] = message
	s.realtime.BroadcastToUser(userID.String(), "notification.created", payload)
}

// Delete removes a notification only when it belongs to the authenticated
// user. This is a local inbox action; it never deletes the underlying domain
// event or message.
func (s *Service) Delete(notificationID, userID uuid.UUID) error {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()
	_, err := s.db.ExecContext(ctx,
		`DELETE FROM notifications WHERE id = $1 AND user_id = $2`, notificationID, userID)
	if err != nil {
		return fmt.Errorf("delete notification: %w", err)
	}
	return nil
}

func (s *Service) GetPreferences(userID uuid.UUID) (NotificationPreferences, error) {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()
	var p NotificationPreferences
	err := s.db.QueryRowContext(ctx, `
		SELECT messages, event_registrations, event_updates, event_reminders,
		       organizer_announcements, system_notifications, browser_push,
		       email_notifications
		FROM notification_preferences WHERE user_id = $1`, userID).Scan(
		&p.Messages, &p.EventRegistrations, &p.EventUpdates, &p.EventReminders,
		&p.OrganizerAnnouncements, &p.SystemNotifications, &p.BrowserPush,
		&p.EmailNotifications)
	if err == sql.ErrNoRows {
		p = NotificationPreferences{Messages: true, EventRegistrations: true,
			EventUpdates: true, EventReminders: true, OrganizerAnnouncements: true,
			SystemNotifications: true, BrowserPush: true, EmailNotifications: true}
		return p, nil
	}
	if err != nil {
		return p, fmt.Errorf("get notification preferences: %w", err)
	}
	return p, nil
}

func (s *Service) UpdatePreferences(userID uuid.UUID, p NotificationPreferences) error {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO notification_preferences
		(user_id, messages, event_registrations, event_updates, event_reminders,
		 organizer_announcements, system_notifications, browser_push, email_notifications)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
		ON CONFLICT (user_id) DO UPDATE SET
		messages=EXCLUDED.messages, event_registrations=EXCLUDED.event_registrations,
		event_updates=EXCLUDED.event_updates, event_reminders=EXCLUDED.event_reminders,
		organizer_announcements=EXCLUDED.organizer_announcements,
		system_notifications=EXCLUDED.system_notifications,
		browser_push=EXCLUDED.browser_push,
		email_notifications=EXCLUDED.email_notifications, updated_at=NOW()`,
		userID, p.Messages, p.EventRegistrations, p.EventUpdates, p.EventReminders,
		p.OrganizerAnnouncements, p.SystemNotifications, p.BrowserPush,
		p.EmailNotifications)
	if err != nil {
		return fmt.Errorf("update notification preferences: %w", err)
	}
	return nil
}

func parseUUID(value sql.NullString) *uuid.UUID {
	if !value.Valid || value.String == "" {
		return nil
	}
	id, err := uuid.Parse(value.String)
	if err != nil {
		return nil
	}
	return &id
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
		// Combined summary for computing launcher badge totals.
		notifications.GET("/unread-summary", h.UnreadSummary)
		notifications.PUT("/:id/read", h.MarkRead)
		notifications.PATCH("/:id/read", h.MarkRead)
		notifications.PUT("/read-all", h.MarkAllRead)
		notifications.PATCH("/read-all", h.MarkAllRead)
		notifications.DELETE("/:id", h.Delete)
	}
	preferences := r.Group("/notification-preferences", authMiddleware)
	preferences.GET("", h.GetPreferences)
	preferences.PATCH("", h.UpdatePreferences)
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

// UnreadSummary returns a structured breakdown of unread counts.
// unread_messages is reserved for a future messaging feature and is always 0
// in the current release. Clients should use the total_unread field for the
// launcher badge count so the structure can be extended without a client update.
func (h *Handler) UnreadSummary(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, ok := userID.(uuid.UUID)
	if !ok {
		response.Success(c, gin.H{
			"unread_notifications": 0,
			"unread_messages":      0,
			"total_unread":         0,
		})
		return
	}

	count, err := h.service.GetUnreadCount(uid)
	if err != nil {
		fmt.Printf("[NOTIFICATION] Error getting unread summary for user %s: %v\n", uid, err)
		response.Success(c, gin.H{
			"unread_notifications": 0,
			"unread_messages":      0,
			"total_unread":         0,
		})
		return
	}

	response.Success(c, gin.H{
		"unread_notifications": count,
		"unread_messages":      0, // placeholder for future messaging feature
		"total_unread":         count,
	})
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

func (h *Handler) Delete(c *gin.Context) {
	notifID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid notification ID")
		return
	}
	uid, ok := authenticatedUserID(c)
	if !ok {
		response.Unauthorized(c, "Invalid user session")
		return
	}
	if err := h.service.Delete(notifID, uid); err != nil {
		response.InternalServerError(c, "Failed to delete notification")
		return
	}
	response.SuccessWithMessage(c, "Notification deleted", nil)
}

func (h *Handler) GetPreferences(c *gin.Context) {
	uid, ok := authenticatedUserID(c)
	if !ok {
		response.Unauthorized(c, "Invalid user session")
		return
	}
	p, err := h.service.GetPreferences(uid)
	if err != nil {
		response.InternalServerError(c, "Failed to load notification preferences")
		return
	}
	response.Success(c, p)
}

func (h *Handler) UpdatePreferences(c *gin.Context) {
	uid, ok := authenticatedUserID(c)
	if !ok {
		response.Unauthorized(c, "Invalid user session")
		return
	}
	var req NotificationPreferences
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid notification preferences")
		return
	}
	if err := h.service.UpdatePreferences(uid, req); err != nil {
		response.InternalServerError(c, "Failed to update notification preferences")
		return
	}
	response.Success(c, req)
}

func authenticatedUserID(c *gin.Context) (uuid.UUID, bool) {
	value, exists := c.Get("user_id")
	if !exists {
		return uuid.Nil, false
	}
	uid, ok := value.(uuid.UUID)
	return uid, ok && uid != uuid.Nil
}
