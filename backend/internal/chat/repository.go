package chat

import (
	"database/sql"
	"time"

	"github.com/google/uuid"
)

// Conversation represents a chat between a student and sheikh
type Conversation struct {
	ID              uuid.UUID  `json:"id"`
	StudentID       uuid.UUID  `json:"student_id"`
	SheikhID        uuid.UUID  `json:"sheikh_id"`
	LessonRequestID *uuid.UUID `json:"lesson_request_id,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	// Joined fields
	OtherPartyName  string     `json:"other_party_name,omitempty"`
	OtherPartyAvatar *string   `json:"other_party_avatar,omitempty"`
	LastMessage      *string   `json:"last_message,omitempty"`
	LastMessageAt    *time.Time `json:"last_message_at,omitempty"`
	UnreadCount      int        `json:"unread_count"`
}

// Message represents a single chat message
type Message struct {
	ID             uuid.UUID `json:"id"`
	ConversationID uuid.UUID `json:"conversation_id"`
	SenderID       uuid.UUID `json:"sender_id"`
	Message        string    `json:"message"`
	IsRead         bool      `json:"is_read"`
	CreatedAt      time.Time `json:"created_at"`
	SenderName     string    `json:"sender_name,omitempty"`
}

// Repository handles database operations for chat
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new chat repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// CreateConversation creates a new conversation
func (r *Repository) CreateConversation(conv *Conversation) error {
	_, err := r.db.Exec(`
		INSERT INTO conversations (id, student_id, sheikh_id, lesson_request_id, created_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (student_id, sheikh_id) DO NOTHING`,
		conv.ID, conv.StudentID, conv.SheikhID, conv.LessonRequestID, conv.CreatedAt,
	)
	return err
}

// GetConversationByParticipants finds an existing conversation
func (r *Repository) GetConversationByParticipants(studentID uuid.UUID, sheikhID uuid.UUID) (*Conversation, error) {
	var conv Conversation
	err := r.db.QueryRow(`
		SELECT id, student_id, sheikh_id, lesson_request_id, created_at
		FROM conversations
		WHERE student_id = $1 AND sheikh_id = $2`,
		studentID, sheikhID,
	).Scan(&conv.ID, &conv.StudentID, &conv.SheikhID, &conv.LessonRequestID, &conv.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &conv, nil
}

// GetConversation gets a single conversation by ID
func (r *Repository) GetConversation(id uuid.UUID) (*Conversation, error) {
	var conv Conversation
	err := r.db.QueryRow(`
		SELECT id, student_id, sheikh_id, lesson_request_id, created_at
		FROM conversations
		WHERE id = $1`, id,
	).Scan(&conv.ID, &conv.StudentID, &conv.SheikhID, &conv.LessonRequestID, &conv.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &conv, nil
}

// ListConversations returns all conversations for a user with last message info
func (r *Repository) ListConversations(userID uuid.UUID) ([]Conversation, error) {
	rows, err := r.db.Query(`
		SELECT c.id, c.student_id, c.sheikh_id, c.lesson_request_id, c.created_at,
		       CASE
		         WHEN c.student_id = $1 THEN COALESCE(su.display_name, su.email)
		         ELSE COALESCE(u.display_name, u.email)
		       END as other_party_name,
		       CASE
		         WHEN c.student_id = $1 THEN sp.avatar_url
		         ELSE p.avatar_url
		       END as other_party_avatar,
		       (SELECT m.message FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message,
		       (SELECT m.created_at FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message_at,
		       (SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.id AND m.sender_id != $1 AND m.is_read = false) as unread_count
		FROM conversations c
		JOIN sheikhs s ON s.id = c.sheikh_id
		JOIN users su ON su.id = s.user_id
		LEFT JOIN profiles sp ON sp.user_id = s.user_id
		JOIN users u ON u.id = c.student_id
		LEFT JOIN profiles p ON p.user_id = c.student_id
		WHERE c.student_id = $1 OR s.user_id = $1
		ORDER BY last_message_at DESC NULLS LAST, c.created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var conversations []Conversation
	for rows.Next() {
		var conv Conversation
		if err := rows.Scan(
			&conv.ID, &conv.StudentID, &conv.SheikhID, &conv.LessonRequestID, &conv.CreatedAt,
			&conv.OtherPartyName, &conv.OtherPartyAvatar,
			&conv.LastMessage, &conv.LastMessageAt, &conv.UnreadCount,
		); err != nil {
			continue
		}
		conversations = append(conversations, conv)
	}
	return conversations, nil
}

// CreateMessage inserts a new message
func (r *Repository) CreateMessage(msg *Message) error {
	_, err := r.db.Exec(`
		INSERT INTO messages (id, conversation_id, sender_id, message, is_read, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)`,
		msg.ID, msg.ConversationID, msg.SenderID, msg.Message, msg.IsRead, msg.CreatedAt,
	)
	return err
}

// GetMessages returns messages for a conversation (newest first, paginated)
func (r *Repository) GetMessages(conversationID uuid.UUID, limit, offset int) ([]Message, error) {
	rows, err := r.db.Query(`
		SELECT m.id, m.conversation_id, m.sender_id, m.message, m.is_read, m.created_at,
		       COALESCE(u.display_name, u.email) as sender_name
		FROM messages m
		JOIN users u ON u.id = m.sender_id
		WHERE m.conversation_id = $1
		ORDER BY m.created_at ASC
		LIMIT $2 OFFSET $3`,
		conversationID, limit, offset,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []Message
	for rows.Next() {
		var msg Message
		if err := rows.Scan(&msg.ID, &msg.ConversationID, &msg.SenderID,
			&msg.Message, &msg.IsRead, &msg.CreatedAt, &msg.SenderName); err != nil {
			continue
		}
		messages = append(messages, msg)
	}
	return messages, nil
}

// MarkAsRead marks all messages in a conversation as read for a specific user
func (r *Repository) MarkAsRead(conversationID, userID uuid.UUID) error {
	_, err := r.db.Exec(`
		UPDATE messages SET is_read = true
		WHERE conversation_id = $1 AND sender_id != $2 AND is_read = false`,
		conversationID, userID,
	)
	return err
}

// IsParticipant checks if a user is part of a conversation
func (r *Repository) IsParticipant(userID, conversationID uuid.UUID) bool {
	var exists bool
	r.db.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM conversations c
			JOIN sheikhs s ON s.id = c.sheikh_id
			WHERE c.id = $1 AND (c.student_id = $2 OR s.user_id = $2)
		)`, conversationID, userID,
	).Scan(&exists)
	return exists
}

// GetRecipientID returns the other participant's user_id in a conversation
func (r *Repository) GetRecipientID(conversationID, senderID uuid.UUID) (uuid.UUID, error) {
	var recipientID uuid.UUID
	err := r.db.QueryRow(`
		SELECT CASE
			WHEN c.student_id = $2 THEN s.user_id
			ELSE c.student_id
		END
		FROM conversations c
		JOIN sheikhs s ON s.id = c.sheikh_id
		WHERE c.id = $1`, conversationID, senderID,
	).Scan(&recipientID)
	return recipientID, err
}
