package models

import (
	"time"

	"github.com/google/uuid"
)

// SupportArticle represents a knowledge base article for AI/Human reference
type SupportArticle struct {
	ID          uuid.UUID `json:"id"`
	Slug        string    `json:"slug"`
	Title       string    `json:"title"`
	Content     string    `json:"content"`
	Category    string    `json:"category"`
	Language    string    `json:"language"`
	IsPublished bool      `json:"is_published"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// SupportTicket represents an escalated user issue
type SupportTicket struct {
	ID                   uuid.UUID  `json:"id"`
	UserID               uuid.UUID  `json:"user_id"`
	AssignedTo           *uuid.UUID `json:"assigned_to,omitempty"`
	Category             string     `json:"category"`
	Subject              string     `json:"subject"`
	Status               string     `json:"status"`   // ai_active, waiting_for_agent, human_active, resolved, closed
	Priority             string     `json:"priority"` // 'normal', 'high'
	AISummary            *string    `json:"ai_summary,omitempty"`
	CreatedAt            time.Time  `json:"created_at"`
	UpdatedAt            time.Time  `json:"updated_at"`
	FirstHumanResponseAt *time.Time `json:"first_human_response_at,omitempty"`
	ResolvedAt           *time.Time `json:"resolved_at,omitempty"`
	ClosedAt             *time.Time `json:"closed_at,omitempty"`
	Language             string     `json:"language"`
	ContextType          *string    `json:"context_type,omitempty"`
	ContextID            *uuid.UUID `json:"context_id,omitempty"`
}

// SupportMessage represents a single message in a support ticket
type SupportMessage struct {
	ID           uuid.UUID              `json:"id"`
	TicketID     uuid.UUID              `json:"ticket_id"`
	SenderType   string                 `json:"sender_type"` // 'user', 'ai', 'support_agent', 'system'
	SenderUserID *uuid.UUID             `json:"sender_user_id,omitempty"`
	Body         string                 `json:"body"`
	MessageType  string                 `json:"message_type"` // 'text', 'attachment', 'internal_note'
	CreatedAt    time.Time              `json:"created_at"`
	ReadAt       *time.Time             `json:"read_at,omitempty"`
	Metadata     map[string]interface{} `json:"metadata,omitempty"`

	// Derived fields for API responses
	SenderName *string            `json:"sender_name,omitempty"`
	Attachment *SupportAttachment `json:"attachment,omitempty"`
}

// SupportAction is trusted, server-defined navigation metadata. Flutter maps
// only these action IDs to routes; it never follows arbitrary AI-provided URLs.
type SupportAction struct {
	Type  string `json:"type"`
	Label string `json:"label"`
}

type SupportAttachment struct {
	ID        uuid.UUID `json:"id"`
	MessageID uuid.UUID `json:"message_id"`
	FileURL   string    `json:"file_url"`
	MimeType  string    `json:"mime_type"`
	SizeBytes int64     `json:"size_bytes"`
	CreatedAt time.Time `json:"created_at"`
}

// SupportTicketWithDetails is used for admin view
type SupportTicketWithDetails struct {
	SupportTicket
	UserName       string  `json:"user_name"`
	UserEmail      string  `json:"user_email"`
	AssignedToName *string `json:"assigned_to_name,omitempty"`
}

// CreateSupportTicketRequest
type CreateSupportTicketRequest struct {
	Category string `json:"category" binding:"required"`
	Subject  string `json:"subject" binding:"required"`
}

// CreateSupportConversationRequest opens (or resumes) a user's active
// conversation. Context is optional and is never treated as authorization.
type CreateSupportConversationRequest struct {
	Language    string  `json:"language"`
	ContextType *string `json:"context_type,omitempty"`
	ContextID   *string `json:"context_id,omitempty"`
	// ForceNew starts a fresh AI conversation without deleting or changing an
	// existing human-support ticket. It is only set from the explicit “New AI
	// chat” action in the client.
	ForceNew bool `json:"force_new,omitempty"`
}

// SupportMessageRequest
type SupportMessageRequest struct {
	Body        string `json:"body" binding:"required"`
	MessageType string `json:"message_type,omitempty"` // defaults to text
}
