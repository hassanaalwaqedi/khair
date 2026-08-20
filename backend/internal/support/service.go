package support

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"mime/multipart"
	"time"

	"github.com/google/uuid"
	"github.com/khair/backend/internal/ai"
	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/internal/notification"
	"github.com/khair/backend/internal/ws"
	"github.com/khair/backend/pkg/fcm"
	"github.com/khair/backend/pkg/storage"
)

type Service struct {
	repo           *Repository
	aiClient       *ai.Client
	wsHub          *ws.Hub
	fcmClient      *fcm.Client
	db             *sql.DB
	notifSvc       *notification.Service
	privateR2Store *storage.PrivateR2Store
}

func NewService(repo *Repository, aiClient *ai.Client, wsHub *ws.Hub, fcmClient *fcm.Client, db *sql.DB, notificationServices ...*notification.Service) *Service {
	privateStore, _ := storage.NewPrivateR2StoreFromEnv()
	service := &Service{
		repo:           repo,
		aiClient:       aiClient,
		wsHub:          wsHub,
		fcmClient:      fcmClient,
		db:             db,
		privateR2Store: privateStore,
	}
	if len(notificationServices) > 0 {
		service.notifSvc = notificationServices[0]
	}
	return service
}

// StartSession creates a new ticket and immediately answers with AI
func (s *Service) StartSession(ctx context.Context, userID uuid.UUID, req models.CreateSupportTicketRequest) (*models.SupportTicket, *models.SupportMessage, error) {
	ticket := &models.SupportTicket{
		UserID:   userID,
		Category: req.Category,
		Subject:  req.Subject,
		Status:   "ai_active",
		Priority: "normal",
	}

	if err := s.repo.CreateTicket(ticket); err != nil {
		return nil, nil, err
	}

	// Fetch knowledge base articles for RAG
	articles, err := s.repo.SearchArticles(req.Subject, "en") // simplified
	var kbContext string
	if err == nil && len(articles) > 0 {
		for _, a := range articles {
			kbContext += fmt.Sprintf("Title: %s\nContent: %s\n\n", a.Title, a.Content)
		}
	}

	prompt := fmt.Sprintf(`You are "Khair AI", the customer support assistant for Khair, an Islamic events platform.
A user has asked a question: "%s"

Here is some knowledge base context you can use to answer:
%s

Rules:
1. Be helpful, concise, and polite.
2. If the context doesn't answer the question, or if it's an account/payment issue requiring admin action, say: "I'm not completely sure about this. I can connect you with Khair Support."
3. Do not invent answers.
4. Keep the answer plain text.`, req.Subject, kbContext)

	var aiReply string
	if s.aiClient != nil && s.aiClient.IsEnabled() {
		aiReply, err = s.aiClient.Generate(ctx, prompt, 0.2)
		if err != nil {
			aiReply = "I am currently experiencing technical difficulties. I can connect you with Khair Support."
		}
	} else {
		aiReply = "Khair AI is temporarily unavailable. You can escalate this to Khair Support."
	}

	// Create user's initial message
	userMsg := &models.SupportMessage{
		TicketID:     ticket.ID,
		SenderType:   "user",
		SenderUserID: &userID,
		Body:         req.Subject,
		MessageType:  "text",
	}
	_ = s.repo.CreateMessage(userMsg)

	// Create AI's message
	aiMsg := &models.SupportMessage{
		TicketID:    ticket.ID,
		SenderType:  "ai",
		Body:        aiReply,
		MessageType: "text",
	}
	if err := s.repo.CreateMessage(aiMsg); err != nil {
		return nil, nil, err
	}

	// Update ticket with AI summary
	aiSummary := "User asked: " + req.Subject + " | AI replied."
	ticket.AISummary = &aiSummary
	s.repo.UpdateTicket(ticket)

	return ticket, aiMsg, nil
}

// EscalateTicket hands off the ticket to human support
func (s *Service) GetTicketMessages(ticketID uuid.UUID, isSupport bool) ([]*models.SupportMessage, error) {
	msgs, err := s.repo.GetTicketMessages(ticketID, isSupport)
	if err != nil {
		return nil, err
	}

	if s.privateR2Store != nil {
		for _, msg := range msgs {
			if msg.Attachment != nil && msg.Attachment.FileURL != "" {
				signed, err := s.privateR2Store.SignedURL(msg.Attachment.FileURL, 24*time.Hour) // 24 hr TTL
				if err == nil {
					msg.Attachment.FileURL = signed
				}
			}
		}
	}

	return msgs, nil
}

func (s *Service) EscalateTicket(ticketID uuid.UUID) error {
	ticket, err := s.repo.GetTicketByID(ticketID)
	if err != nil {
		return err
	}

	if ticket.Status != "ai_active" {
		return fmt.Errorf("ticket already escalated or resolved")
	}

	ticket.Status = "waiting_for_support"
	if err := s.repo.UpdateTicket(ticket); err != nil {
		return err
	}

	// Create a system message
	sysMsg := &models.SupportMessage{
		TicketID:    ticket.ID,
		SenderType:  "system",
		Body:        "Your request has been sent to Khair Support.",
		MessageType: "text",
	}
	s.repo.CreateMessage(sysMsg)

	s.broadcastEvent(ticket.UserID, "support.ticket_updated", ticket)
	return nil
}

// AssignTicket atomically assigns a ticket to an agent
func (s *Service) AssignTicket(ticketID, agentID uuid.UUID) error {
	success, err := s.repo.AssignTicket(ticketID, agentID)
	if err != nil {
		return err
	}
	if !success {
		return fmt.Errorf("ticket already assigned to another agent")
	}

	ticket, _ := s.repo.GetTicketByID(ticketID)
	s.broadcastEvent(ticket.UserID, "support.ticket_assigned", ticket)

	// Inform user via system message
	sysMsg := &models.SupportMessage{
		TicketID:    ticket.ID,
		SenderType:  "system",
		Body:        "Khair Support joined the conversation.",
		MessageType: "text",
	}
	s.repo.CreateMessage(sysMsg)
	s.broadcastEvent(ticket.UserID, "support.message_created", sysMsg)

	return nil
}

// SendMessage handles messages from both users and agents
func (s *Service) SendMessage(ticketID, senderID uuid.UUID, senderType, body, messageType string) (*models.SupportMessage, error) {
	msg := &models.SupportMessage{
		TicketID:     ticketID,
		SenderType:   senderType,
		SenderUserID: &senderID,
		Body:         body,
		MessageType:  messageType,
	}

	if err := s.repo.CreateMessage(msg); err != nil {
		return nil, err
	}

	ticket, err := s.repo.GetTicketByID(ticketID)
	if err != nil {
		return nil, err
	}

	if senderType == "support_agent" {
		if ticket.FirstHumanResponseAt == nil {
			now := time.Now()
			ticket.FirstHumanResponseAt = &now
			s.repo.UpdateTicket(ticket)
		}

		// Send FCM to user
		if messageType != "internal_note" {
			s.sendFCMToUser(ticket.UserID, "support_reply", map[string]string{
				"type":      "support_message",
				"ticket_id": ticket.ID.String(),
			})
		}
	}

	if messageType != "internal_note" {
		s.broadcastEvent(ticket.UserID, "support.message_created", msg)
	}

	return msg, nil
}

func (s *Service) UploadAttachment(ctx context.Context, ticketID, senderID uuid.UUID, senderType string, file multipart.File, header *multipart.FileHeader) (*models.SupportMessage, error) {
	if s.privateR2Store == nil {
		return nil, fmt.Errorf("attachment storage is not configured")
	}

	ticket, err := s.repo.GetTicketByID(ticketID)
	if err != nil {
		return nil, err
	}

	url, err := s.privateR2Store.Upload(ctx, file, fmt.Sprintf("support/%s", ticketID.String()))
	if err != nil {
		return nil, fmt.Errorf("failed to upload attachment: %w", err)
	}

	// Create message first
	msg := &models.SupportMessage{
		TicketID:     ticketID,
		SenderType:   senderType,
		SenderUserID: &senderID,
		Body:         "Sent an attachment",
		MessageType:  "attachment",
	}

	if err := s.repo.CreateMessage(msg); err != nil {
		return nil, err
	}

	// Create attachment record
	att := &models.SupportAttachment{
		MessageID: msg.ID,
		FileURL:   url,
		MimeType:  header.Header.Get("Content-Type"),
		SizeBytes: header.Size,
	}

	if err := s.repo.CreateAttachment(att); err != nil {
		return nil, err
	}
	msg.Attachment = att

	if senderType == "support_agent" {
		if ticket.FirstHumanResponseAt == nil {
			now := time.Now()
			ticket.FirstHumanResponseAt = &now
			s.repo.UpdateTicket(ticket)
		}

		s.sendFCMToUser(ticket.UserID, "support_attachment", map[string]string{
			"type":      "support_message",
			"ticket_id": ticket.ID.String(),
		})
	}

	s.broadcastEvent(ticket.UserID, "support.message_created", msg)

	return msg, nil
}

func (s *Service) ResolveTicket(ticketID uuid.UUID) error {
	ticket, err := s.repo.GetTicketByID(ticketID)
	if err != nil {
		return err
	}

	now := time.Now()
	ticket.ResolvedAt = &now
	ticket.Status = "resolved"
	if err := s.repo.UpdateTicket(ticket); err != nil {
		return err
	}

	sysMsg := &models.SupportMessage{
		TicketID:    ticket.ID,
		SenderType:  "system",
		Body:        "This ticket has been resolved. If you still need help, you can reopen it.",
		MessageType: "text",
	}
	s.repo.CreateMessage(sysMsg)
	s.broadcastEvent(ticket.UserID, "support.ticket_updated", ticket)
	s.broadcastEvent(ticket.UserID, "support.message_created", sysMsg)

	return nil
}

func (s *Service) broadcastEvent(userID uuid.UUID, eventType string, payload interface{}) {
	if s.wsHub == nil {
		return
	}
	dataBytes, _ := json.Marshal(map[string]interface{}{
		"event":   eventType,
		"payload": payload,
	})
	s.wsHub.BroadcastToUser(userID.String(), eventType, string(dataBytes))
}

func (s *Service) sendFCMToUser(userID uuid.UUID, notificationType string, data map[string]string) {
	if s.fcmClient == nil || !s.fcmClient.IsEnabled() {
		return
	}

	title, body := "Khair Support", "Khair Support replied to your ticket."
	if notificationType == "support_attachment" {
		body = "Khair Support sent an attachment to your ticket."
	}
	if s.notifSvc != nil {
		localized, err := s.notifSvc.LocalizeForUser(userID, notificationType, data)
		if err == nil {
			title, body = localized.Title, localized.Message
		}
	}

	query := `SELECT token FROM device_tokens WHERE user_id = $1`
	rows, err := s.db.Query(query, userID)
	if err != nil {
		return
	}
	defer rows.Close()

	var tokens []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err == nil {
			tokens = append(tokens, t)
		}
	}

	if len(tokens) > 0 {
		go s.fcmClient.SendToMultiple(tokens, title, body, data)
	}
}
