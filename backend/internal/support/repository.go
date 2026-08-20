package support

import (
	"database/sql"
	"encoding/json"
	"strings"

	"github.com/google/uuid"
	"github.com/khair/backend/internal/models"
)

type Repository struct {
	db *sql.DB
}

const ticketColumns = `id, user_id, assigned_to, category, subject, status,
	priority, ai_summary, created_at, updated_at, first_human_response_at,
	resolved_at, closed_at, language, context_type, context_id`

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// Articles

func (r *Repository) GetArticles(category string, language string) ([]*models.SupportArticle, error) {
	query := `SELECT id, slug, title, content, category, language, is_published, created_at, updated_at 
			  FROM support_articles WHERE is_published = true AND language = $1`
	args := []interface{}{language}

	if category != "" {
		query += " AND category = $2"
		args = append(args, category)
	}

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var articles []*models.SupportArticle
	for rows.Next() {
		a := &models.SupportArticle{}
		err := rows.Scan(&a.ID, &a.Slug, &a.Title, &a.Content, &a.Category, &a.Language, &a.IsPublished, &a.CreatedAt, &a.UpdatedAt)
		if err != nil {
			return nil, err
		}
		articles = append(articles, a)
	}
	return articles, nil
}

// Tickets

func (r *Repository) CreateTicket(ticket *models.SupportTicket) error {
	query := `INSERT INTO support_tickets
			  (user_id, category, subject, status, priority, language, context_type, context_id)
			  VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
			  RETURNING id, created_at, updated_at`

	return r.db.QueryRow(query, ticket.UserID, ticket.Category, ticket.Subject,
		ticket.Status, ticket.Priority, ticket.Language, ticket.ContextType, ticket.ContextID).
		Scan(&ticket.ID, &ticket.CreatedAt, &ticket.UpdatedAt)
}

func (r *Repository) GetTicketByID(id uuid.UUID) (*models.SupportTicket, error) {
	query := `SELECT ` + ticketColumns + ` FROM support_tickets WHERE id = $1`

	t := &models.SupportTicket{}
	err := r.db.QueryRow(query, id).Scan(
		&t.ID, &t.UserID, &t.AssignedTo, &t.Category, &t.Subject, &t.Status,
		&t.Priority, &t.AISummary, &t.CreatedAt, &t.UpdatedAt,
		&t.FirstHumanResponseAt, &t.ResolvedAt, &t.ClosedAt, &t.Language,
		&t.ContextType, &t.ContextID,
	)
	if err != nil {
		return nil, err
	}
	return t, nil
}

func (r *Repository) UpdateTicket(t *models.SupportTicket) error {
	query := `UPDATE support_tickets SET assigned_to = $1, status = $2, priority = $3, ai_summary = $4, 
			  first_human_response_at = $5, resolved_at = $6, closed_at = $7 WHERE id = $8 RETURNING updated_at`

	return r.db.QueryRow(query, t.AssignedTo, t.Status, t.Priority, t.AISummary, t.FirstHumanResponseAt, t.ResolvedAt, t.ClosedAt, t.ID).
		Scan(&t.UpdatedAt)
}

func (r *Repository) GetUserTickets(userID uuid.UUID) ([]*models.SupportTicket, error) {
	query := `SELECT ` + ticketColumns + ` FROM support_tickets
			  WHERE user_id = $1 ORDER BY updated_at DESC`

	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tickets []*models.SupportTicket
	for rows.Next() {
		t := &models.SupportTicket{}
		err := rows.Scan(
			&t.ID, &t.UserID, &t.AssignedTo, &t.Category, &t.Subject, &t.Status,
			&t.Priority, &t.AISummary, &t.CreatedAt, &t.UpdatedAt,
			&t.FirstHumanResponseAt, &t.ResolvedAt, &t.ClosedAt, &t.Language,
			&t.ContextType, &t.ContextID,
		)
		if err != nil {
			return nil, err
		}
		tickets = append(tickets, t)
	}
	return tickets, nil
}

// GetActiveTicket returns the user's current conversation. A single active
// thread preserves AI and human context through a handoff.
func (r *Repository) GetActiveTicket(userID uuid.UUID) (*models.SupportTicket, error) {
	query := `SELECT ` + ticketColumns + ` FROM support_tickets
		WHERE user_id = $1 AND status IN ('ai_active', 'waiting_for_agent', 'human_active')
		ORDER BY updated_at DESC LIMIT 1`
	t := &models.SupportTicket{}
	err := r.db.QueryRow(query, userID).Scan(
		&t.ID, &t.UserID, &t.AssignedTo, &t.Category, &t.Subject, &t.Status,
		&t.Priority, &t.AISummary, &t.CreatedAt, &t.UpdatedAt,
		&t.FirstHumanResponseAt, &t.ResolvedAt, &t.ClosedAt, &t.Language,
		&t.ContextType, &t.ContextID,
	)
	if err != nil {
		return nil, err
	}
	return t, nil
}

// GetUserSupportContext returns only the minimum safe data used to make
// support answers relevant. It intentionally excludes private profile fields.
func (r *Repository) GetUserSupportContext(userID uuid.UUID) (language, role, organizerStatus string, err error) {
	query := `SELECT COALESCE(NULLIF(p.preferred_language, ''), 'en'),
		COALESCE(u.role, 'user'), COALESCE(o.status, '')
		FROM users u
		LEFT JOIN profiles p ON p.user_id = u.id
		LEFT JOIN organizers o ON o.user_id = u.id
		WHERE u.id = $1`
	err = r.db.QueryRow(query, userID).Scan(&language, &role, &organizerStatus)
	return
}

func (r *Repository) UpdateSubject(ticketID uuid.UUID, subject string) error {
	_, err := r.db.Exec(`UPDATE support_tickets SET subject = $1 WHERE id = $2`, subject, ticketID)
	return err
}

func (r *Repository) GetAdminTickets(status string) ([]*models.SupportTicketWithDetails, error) {
	query := `SELECT t.id, t.user_id, t.assigned_to, t.category, t.subject, t.status, t.priority, t.ai_summary, t.created_at, t.updated_at, t.first_human_response_at, t.resolved_at, t.closed_at, t.language, t.context_type, t.context_id,
			  COALESCE(NULLIF(CONCAT_WS(' ', u.first_name, u.last_name), ''), 'Khair user') AS user_name,
			  COALESCE(u.email, '') AS user_email,
			  NULLIF(CONCAT_WS(' ', a.first_name, a.last_name), '') AS assigned_to_name
			  FROM support_tickets t
			  JOIN users u ON t.user_id = u.id
			  LEFT JOIN users a ON t.assigned_to = a.id
			  WHERE 1=1`

	var args []interface{}
	if status != "" && status != "all" {
		if status == "open" {
			query += " AND t.status NOT IN ('resolved', 'closed')"
		} else {
			query += " AND t.status = $1"
			args = append(args, status)
		}
	}
	query += " ORDER BY t.created_at DESC"

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tickets []*models.SupportTicketWithDetails
	for rows.Next() {
		t := &models.SupportTicketWithDetails{}
		err := rows.Scan(
			&t.ID, &t.UserID, &t.AssignedTo, &t.Category, &t.Subject, &t.Status,
			&t.Priority, &t.AISummary, &t.CreatedAt, &t.UpdatedAt,
			&t.FirstHumanResponseAt, &t.ResolvedAt, &t.ClosedAt, &t.Language,
			&t.ContextType, &t.ContextID,
			&t.UserName, &t.UserEmail, &t.AssignedToName,
		)
		if err != nil {
			return nil, err
		}
		tickets = append(tickets, t)
	}
	return tickets, nil
}

// AssignTicket atomically assigns a ticket to an agent if it's not already assigned
func (r *Repository) AssignTicket(ticketID, agentID uuid.UUID) (bool, error) {
	query := `UPDATE support_tickets SET assigned_to = $1, status = 'human_active'
			  WHERE id = $2 AND (assigned_to IS NULL OR assigned_to = $1)
			  RETURNING id`

	var updatedID uuid.UUID
	err := r.db.QueryRow(query, agentID, ticketID).Scan(&updatedID)
	if err == sql.ErrNoRows {
		return false, nil // Already assigned to someone else
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

// Messages

func (r *Repository) CreateMessage(msg *models.SupportMessage) error {
	metadata := msg.Metadata
	if metadata == nil {
		metadata = map[string]interface{}{}
	}
	metadataJSON, err := json.Marshal(metadata)
	if err != nil {
		return err
	}
	query := `INSERT INTO support_messages
			  (ticket_id, sender_type, sender_user_id, body, message_type, metadata)
			  VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, created_at`

	return r.db.QueryRow(query, msg.TicketID, msg.SenderType, msg.SenderUserID,
		msg.Body, msg.MessageType, metadataJSON).
		Scan(&msg.ID, &msg.CreatedAt)
}

func (r *Repository) GetTicketMessages(ticketID uuid.UUID, includeInternal bool) ([]*models.SupportMessage, error) {
	query := `SELECT m.id, m.ticket_id, m.sender_type, m.sender_user_id, m.body, m.message_type, m.created_at, m.read_at, m.metadata,
			  u.first_name || ' ' || u.last_name as sender_name,
			  a.id, a.file_url, a.mime_type, a.size_bytes, a.created_at
			  FROM support_messages m
			  LEFT JOIN users u ON m.sender_user_id = u.id
			  LEFT JOIN support_attachments a ON m.id = a.message_id
			  WHERE m.ticket_id = $1`

	if !includeInternal {
		query += ` AND m.message_type != 'internal_note'`
	}
	query += ` ORDER BY m.created_at ASC`

	rows, err := r.db.Query(query, ticketID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var msgs []*models.SupportMessage
	for rows.Next() {
		m := &models.SupportMessage{}
		var attID sql.NullString
		var fileURL, mimeType sql.NullString
		var sizeBytes sql.NullInt64
		var attCreated sql.NullTime
		var metadataJSON []byte

		err := rows.Scan(
			&m.ID, &m.TicketID, &m.SenderType, &m.SenderUserID, &m.Body, &m.MessageType, &m.CreatedAt, &m.ReadAt, &metadataJSON, &m.SenderName,
			&attID, &fileURL, &mimeType, &sizeBytes, &attCreated,
		)
		if err != nil {
			return nil, err
		}

		if attID.Valid {
			m.Attachment = &models.SupportAttachment{
				ID:        uuid.MustParse(attID.String),
				MessageID: m.ID,
				FileURL:   fileURL.String,
				MimeType:  mimeType.String,
				SizeBytes: sizeBytes.Int64,
				CreatedAt: attCreated.Time,
			}
		}
		if len(metadataJSON) > 0 {
			_ = json.Unmarshal(metadataJSON, &m.Metadata)
		}

		msgs = append(msgs, m)
	}
	return msgs, nil
}

func (r *Repository) CreateAttachment(att *models.SupportAttachment) error {
	query := `INSERT INTO support_attachments (message_id, file_url, mime_type, size_bytes)
			  VALUES ($1, $2, $3, $4) RETURNING id, created_at`

	return r.db.QueryRow(query, att.MessageID, att.FileURL, att.MimeType, att.SizeBytes).
		Scan(&att.ID, &att.CreatedAt)
}

func (r *Repository) MarkMessagesAsRead(ticketID uuid.UUID, excludeSenderType string) error {
	query := `UPDATE support_messages SET read_at = NOW() WHERE ticket_id = $1 AND sender_type != $2 AND read_at IS NULL`
	_, err := r.db.Exec(query, ticketID, excludeSenderType)
	return err
}

// Hybrid Search for RAG (Fallback to plain ILIKE if no pgvector/tsvector setup)
func (r *Repository) SearchArticles(query string, language string) ([]*models.SupportArticle, error) {
	// Simple ILIKE search for now. Ideally this would be pgvector or websearch_to_tsquery
	dbQuery := `SELECT id, slug, title, content, category, language, is_published, created_at, updated_at 
			  FROM support_articles 
			  WHERE is_published = true AND language = $1 AND (title ILIKE $2 OR content ILIKE $2)
			  LIMIT 3`

	searchStr := "%" + strings.ReplaceAll(query, " ", "%") + "%"
	rows, err := r.db.Query(dbQuery, language, searchStr)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var articles []*models.SupportArticle
	for rows.Next() {
		a := &models.SupportArticle{}
		err := rows.Scan(&a.ID, &a.Slug, &a.Title, &a.Content, &a.Category, &a.Language, &a.IsPublished, &a.CreatedAt, &a.UpdatedAt)
		if err != nil {
			return nil, err
		}
		articles = append(articles, a)
	}
	return articles, nil
}
