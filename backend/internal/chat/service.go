package chat

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/notification"
	"github.com/khair/backend/internal/push"
	"github.com/khair/backend/internal/ws"
)

// Service handles chat business logic
type Service struct {
	repo     *Repository
	notifSvc *notification.Service
	pushSvc  *push.Service
	wsHub    *ws.Hub
}

// NewService creates a new chat service
func NewService(db *sql.DB, notifSvc *notification.Service, pushSvc *push.Service, wsHub *ws.Hub) *Service {
	return &Service{
		repo:     NewRepository(db),
		notifSvc: notifSvc,
		pushSvc:  pushSvc,
		wsHub:    wsHub,
	}
}

// CreateConversation creates a conversation (called when lesson request is accepted)
func (s *Service) CreateConversation(studentID, sheikhID uuid.UUID, lessonRequestID *uuid.UUID) error {
	// Check if conversation already exists
	existing, err := s.repo.GetConversationByParticipants(studentID, sheikhID)
	if err == nil && existing != nil {
		return nil
	}

	conv := &Conversation{
		ID:              uuid.New(),
		StudentID:       studentID,
		SheikhID:        sheikhID,
		LessonRequestID: lessonRequestID,
		CreatedAt:       time.Now(),
	}

	if err := s.repo.CreateConversation(conv); err != nil {
		return fmt.Errorf("create conversation: %w", err)
	}

	return nil
}

// GetOrCreateConversation returns existing conversation or creates a new one
func (s *Service) GetOrCreateConversation(userID, sheikhID uuid.UUID) (*Conversation, error) {
	// Try to find existing
	existing, err := s.repo.GetConversationByParticipants(userID, sheikhID)
	if err == nil && existing != nil {
		return existing, nil
	}

	// Create new
	conv := &Conversation{
		ID:        uuid.New(),
		StudentID: userID,
		SheikhID:  sheikhID,
		CreatedAt: time.Now(),
	}

	if err := s.repo.CreateConversation(conv); err != nil {
		return nil, fmt.Errorf("create conversation: %w", err)
	}

	return conv, nil
}

// GetConversations returns all conversations for a user
func (s *Service) GetConversations(userID uuid.UUID) ([]Conversation, error) {
	return s.repo.ListConversations(userID)
}

// GetMessages returns messages in a conversation (with access check)
func (s *Service) GetMessages(userID, conversationID uuid.UUID, page, pageSize int) ([]Message, error) {
	if !s.repo.IsParticipant(userID, conversationID) {
		return nil, fmt.Errorf("you are not a participant in this conversation")
	}

	offset := (page - 1) * pageSize
	return s.repo.GetMessages(conversationID, pageSize, offset)
}

// SendMessage sends a message in a conversation
func (s *Service) SendMessage(senderID, conversationID uuid.UUID, text string) (*Message, error) {
	if !s.repo.IsParticipant(senderID, conversationID) {
		return nil, fmt.Errorf("you are not a participant in this conversation")
	}

	msg := &Message{
		ID:             uuid.New(),
		ConversationID: conversationID,
		SenderID:       senderID,
		Message:        text,
		IsRead:         false,
		CreatedAt:      time.Now(),
	}

	if err := s.repo.CreateMessage(msg); err != nil {
		return nil, fmt.Errorf("send message: %w", err)
	}

	// Push via WebSocket in real-time
	go s.broadcastMessage(senderID, conversationID, msg)

	// Notify recipient (in-app + push notification)
	go s.notifyNewMessage(senderID, conversationID, text)

	return msg, nil
}

// MarkAsRead marks all messages as read for the user in a conversation
func (s *Service) MarkAsRead(userID, conversationID uuid.UUID) error {
	if !s.repo.IsParticipant(userID, conversationID) {
		return fmt.Errorf("you are not a participant in this conversation")
	}
	return s.repo.MarkAsRead(conversationID, userID)
}

// broadcastMessage pushes the message via WebSocket to the recipient
func (s *Service) broadcastMessage(senderID, conversationID uuid.UUID, msg *Message) {
	if s.wsHub == nil {
		return
	}

	recipientID, err := s.repo.GetRecipientID(conversationID, senderID)
	if err != nil {
		return
	}

	// Send to recipient via WebSocket
	s.wsHub.BroadcastToUser(recipientID.String(), "chat_message", map[string]interface{}{
		"id":              msg.ID.String(),
		"conversation_id": msg.ConversationID.String(),
		"sender_id":       msg.SenderID.String(),
		"message":         msg.Message,
		"is_read":         msg.IsRead,
		"created_at":      msg.CreatedAt.Format(time.RFC3339Nano),
		"sender_name":     msg.SenderName,
	})

	// Also send to sender's other devices
	s.wsHub.BroadcastToUser(senderID.String(), "chat_message", map[string]interface{}{
		"id":              msg.ID.String(),
		"conversation_id": msg.ConversationID.String(),
		"sender_id":       msg.SenderID.String(),
		"message":         msg.Message,
		"is_read":         msg.IsRead,
		"created_at":      msg.CreatedAt.Format(time.RFC3339Nano),
		"sender_name":     msg.SenderName,
	})
}

func (s *Service) notifyNewMessage(senderID, conversationID uuid.UUID, text string) {
	recipientID, err := s.repo.GetRecipientID(conversationID, senderID)
	if err != nil {
		return
	}

	title := "New Message"
	body := truncate(text, 100)

	if s.notifSvc != nil {
		_ = s.notifSvc.CreateTyped(recipientID, title, body, "chat_message", map[string]string{
			"conversation_id": conversationID.String(),
		})
	}
	if s.pushSvc != nil {
		s.pushSvc.SendToUser(recipientID, title, body, map[string]string{
			"type":            "chat_message",
			"conversation_id": conversationID.String(),
		})
	}
}

func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}
