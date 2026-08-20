package support

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log"
	"mime/multipart"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/khair/backend/internal/ai"
	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/internal/notification"
	"github.com/khair/backend/internal/push"
	"github.com/khair/backend/internal/ws"
	"github.com/khair/backend/pkg/fcm"
	"github.com/khair/backend/pkg/storage"
)

type Service struct {
	repo           *Repository
	aiClient       *ai.Client
	wsHub          *ws.Hub
	fcmClient      *fcm.Client
	pushSvc        *push.Service
	db             *sql.DB
	notifSvc       *notification.Service
	privateR2Store *storage.PrivateR2Store
}

const (
	statusAIActive        = "ai_active"
	statusWaitingForAgent = "waiting_for_agent"
	statusHumanActive     = "human_active"
	statusResolved        = "resolved"
)

var supportedContextTypes = map[string]struct{}{
	"event": {}, "event_registration": {}, "organizer_application": {},
	"account": {}, "notification": {},
}

// SetPushService connects support replies to the shared device-token and FCM
// lifecycle. It is kept as a setter to preserve the existing constructor used
// by tests and by older service wiring.
func (s *Service) SetPushService(pushSvc *push.Service) {
	s.pushSvc = pushSvc
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

// StartConversation returns the current active conversation when one exists,
// otherwise creates it with a localized Khair AI welcome. The returned record
// is the same record later handed to a human agent.
func (s *Service) StartConversation(ctx context.Context, userID uuid.UUID, req models.CreateSupportConversationRequest) (*models.SupportTicket, *models.SupportMessage, bool, error) {
	if ticket, err := s.repo.GetActiveTicket(userID); err == nil {
		return ticket, nil, false, nil
	} else if !errors.Is(err, sql.ErrNoRows) {
		return nil, nil, false, err
	}

	profileLanguage, _, _, err := s.repo.GetUserSupportContext(userID)
	if err != nil {
		return nil, nil, false, err
	}
	language := normalizeLanguage(req.Language)
	if req.Language == "" {
		language = normalizeLanguage(profileLanguage)
	}

	var contextID *uuid.UUID
	if req.ContextType != nil || req.ContextID != nil {
		if req.ContextType == nil || req.ContextID == nil {
			return nil, nil, false, fmt.Errorf("context_type and context_id must be provided together")
		}
		contextType := strings.TrimSpace(*req.ContextType)
		if _, ok := supportedContextTypes[contextType]; !ok {
			return nil, nil, false, fmt.Errorf("unsupported support context")
		}
		parsedID, err := uuid.Parse(strings.TrimSpace(*req.ContextID))
		if err != nil {
			return nil, nil, false, fmt.Errorf("invalid support context")
		}
		req.ContextType = &contextType
		contextID = &parsedID
	}

	ticket := &models.SupportTicket{
		UserID:      userID,
		Category:    conversationCategory(req.ContextType),
		Subject:     localizedConversationSubject(language),
		Status:      statusAIActive,
		Priority:    "normal",
		Language:    language,
		ContextType: req.ContextType,
		ContextID:   contextID,
	}

	if err := s.repo.CreateTicket(ticket); err != nil {
		return nil, nil, false, err
	}
	welcome := &models.SupportMessage{
		TicketID:    ticket.ID,
		SenderType:  "ai",
		Body:        localizedWelcome(language),
		MessageType: "text",
		Metadata: map[string]interface{}{
			"quick_actions": quickActions(language),
		},
	}
	if err := s.repo.CreateMessage(welcome); err != nil {
		return nil, nil, false, err
	}

	return ticket, welcome, true, nil
}

// StartSession keeps the legacy route working while routing it through the
// conversation lifecycle. New clients use StartConversation + SendUserMessage.
func (s *Service) StartSession(ctx context.Context, userID uuid.UUID, req models.CreateSupportTicketRequest) (*models.SupportTicket, *models.SupportMessage, error) {
	ticket, _, _, err := s.StartConversation(ctx, userID, models.CreateSupportConversationRequest{Language: "en"})
	if err != nil {
		return nil, nil, err
	}
	messages, err := s.SendUserMessage(ctx, ticket.ID, userID, req.Subject)
	if err != nil {
		return nil, nil, err
	}
	for index := len(messages) - 1; index >= 0; index-- {
		if messages[index].SenderType == "ai" {
			return ticket, messages[index], nil
		}
	}
	return ticket, messages[len(messages)-1], nil
}

// SendUserMessage persists the user's text first and only then asks Khair AI
// while the conversation remains in AI mode. Human and waiting conversations
// never invoke an AI provider.
func (s *Service) SendUserMessage(ctx context.Context, ticketID, userID uuid.UUID, body string) ([]*models.SupportMessage, error) {
	body = strings.TrimSpace(body)
	if body == "" || len([]rune(body)) > 4000 {
		return nil, fmt.Errorf("message must contain between 1 and 4000 characters")
	}
	ticket, err := s.repo.GetTicketByID(ticketID)
	if err != nil {
		return nil, err
	}
	if ticket.UserID != userID {
		return nil, fmt.Errorf("access denied")
	}

	userMsg := &models.SupportMessage{
		TicketID: ticketID, SenderType: "user", SenderUserID: &userID,
		Body: body, MessageType: "text",
	}
	if err := s.repo.CreateMessage(userMsg); err != nil {
		return nil, err
	}
	if ticket.Subject == localizedConversationSubject(ticket.Language) {
		_ = s.repo.UpdateSubject(ticket.ID, truncateSubject(body))
		ticket.Subject = truncateSubject(body)
	}

	if ticket.Status == statusResolved {
		ticket.Status = statusAIActive
		ticket.ResolvedAt = nil
		if err := s.repo.UpdateTicket(ticket); err != nil {
			return nil, err
		}
	}

	if ticket.Status != statusAIActive {
		s.broadcastEvent(ticket.UserID, "support.message_created", userMsg)
		return []*models.SupportMessage{userMsg}, nil
	}

	if requestsHuman(body) {
		// Publish the user's request before the escalation system message so a
		// second connected client receives the conversation in chronological
		// order as well as the database does.
		s.broadcastEvent(ticket.UserID, "support.message_created", userMsg)
		systemMessage, err := s.EscalateTicketWithSummary(ctx, ticketID, userID, "user_requested_human")
		if err != nil {
			return nil, err
		}
		return []*models.SupportMessage{userMsg, systemMessage}, nil
	}

	aiReply, metadata := s.generateAIReply(ctx, userID, ticket, body)
	aiMsg := &models.SupportMessage{
		TicketID: ticketID, SenderType: "ai", Body: aiReply,
		MessageType: "text", Metadata: metadata,
	}
	if err := s.repo.CreateMessage(aiMsg); err != nil {
		return nil, err
	}
	s.broadcastEvent(ticket.UserID, "support.message_created", userMsg)
	s.broadcastEvent(ticket.UserID, "support.message_created", aiMsg)
	return []*models.SupportMessage{userMsg, aiMsg}, nil
}

func (s *Service) generateAIReply(ctx context.Context, userID uuid.UUID, ticket *models.SupportTicket, body string) (string, map[string]interface{}) {
	profileLanguage, role, organizerStatus, err := s.repo.GetUserSupportContext(userID)
	language := normalizeLanguage(ticket.Language)
	if err != nil {
		role, organizerStatus = "user", ""
	}
	if ticket.Language == "" {
		language = normalizeLanguage(profileLanguage)
	}
	articles, err := s.repo.SearchArticles(body, language)
	if err == nil && len(articles) == 0 && language != "en" {
		articles, _ = s.repo.SearchArticles(body, "en")
	}
	var kbContext string
	if len(articles) > 0 {
		for _, a := range articles {
			kbContext += fmt.Sprintf("Title: %s\nContent: %s\n\n", a.Title, a.Content)
		}
	}

	prompt := fmt.Sprintf(`You are Khair AI, the clearly-labelled AI support assistant for Khair, an Islamic events platform.
Reply in %s unless the user writes in another language. A user said: "%s"

Safe user context: role=%s, organizer_status=%s, support_context=%s.

Here is some knowledge base context you can use to answer:
%s

Rules:
1. Be helpful, concise, and polite.
2. Only state Khair capabilities or policies supplied in the context or safe user context.
3. If you do not know, say so and offer Khair Support; never invent an answer.
4. Do not claim to be human, reveal internal data, give arbitrary URLs, or expose implementation details.
5. Keep the answer plain text.`, language, body, role, organizerStatus, dereferenceContext(ticket.ContextType), kbContext)

	aiReply := localizedAIFailure(language)
	aiFailed := true
	if s.aiClient != nil && s.aiClient.IsEnabled() {
		if reply, err := s.aiClient.Generate(ctx, prompt, 0.2); err == nil && strings.TrimSpace(reply) != "" {
			aiReply = strings.TrimSpace(reply)
			aiFailed = false
		}
	}
	metadata := map[string]interface{}{}
	if aiFailed {
		metadata["actions"] = []models.SupportAction{{
			Type: "talk_to_support", Label: localizedActionLabel("talk_to_support", language),
		}}
	} else if actions := supportActionsFor(body, language); len(actions) > 0 {
		metadata["actions"] = actions
	}
	return aiReply, metadata
}

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

// EscalateTicket retains the legacy service API. New requests should use
// EscalateTicketWithSummary so the support inbox receives the whole context.
func (s *Service) EscalateTicket(ticketID uuid.UUID) error {
	_, err := s.escalateTicket(context.Background(), ticketID, false)
	return err
}

func (s *Service) EscalateTicketWithSummary(ctx context.Context, ticketID, userID uuid.UUID, reason string) (*models.SupportMessage, error) {
	ticket, err := s.repo.GetTicketByID(ticketID)
	if err != nil {
		return nil, err
	}
	if ticket.UserID != userID {
		return nil, fmt.Errorf("access denied")
	}
	return s.escalateTicket(ctx, ticketID, true)
}

func (s *Service) escalateTicket(ctx context.Context, ticketID uuid.UUID, includeSummary bool) (*models.SupportMessage, error) {
	ticket, err := s.repo.GetTicketByID(ticketID)
	if err != nil {
		return nil, err
	}

	// Repeating the handoff action after a network retry must be safe. The
	// conversation is already visible to human support in either of these
	// states, so report success instead of sending the user back to the AI.
	if ticket.Status == statusWaitingForAgent || ticket.Status == statusHumanActive {
		return nil, nil
	}
	if ticket.Status != statusAIActive {
		return nil, fmt.Errorf("conversation is already escalated or resolved")
	}

	if includeSummary {
		if messages, err := s.repo.GetTicketMessages(ticketID, true); err == nil {
			summary := buildHandoffSummary(ticket, messages)
			ticket.AISummary = &summary
		}
	}
	ticket.Status = statusWaitingForAgent
	if err := s.repo.UpdateTicket(ticket); err != nil {
		return nil, err
	}

	sysMsg := &models.SupportMessage{
		TicketID:    ticket.ID,
		SenderType:  "system",
		Body:        localizedQueuedForSupport(ticket.Language),
		MessageType: "text",
	}
	if err := s.repo.CreateMessage(sysMsg); err != nil {
		return nil, err
	}

	s.broadcastEvent(ticket.UserID, "support.ticket_updated", ticket)
	s.broadcastEvent(ticket.UserID, "support.message_created", sysMsg)
	return sysMsg, nil
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

	// Inform user via a persisted system message in their selected language.
	sysMsg := &models.SupportMessage{
		TicketID:    ticket.ID,
		SenderType:  "system",
		Body:        localizedAgentJoined(ticket.Language),
		MessageType: "text",
	}
	s.repo.CreateMessage(sysMsg)
	s.broadcastEvent(ticket.UserID, "support.message_created", sysMsg)

	return nil
}

// SendMessage handles messages from both users and agents
func (s *Service) SendMessage(ticketID, senderID uuid.UUID, senderType, body, messageType string) (*models.SupportMessage, error) {
	body = strings.TrimSpace(body)
	if body == "" || len([]rune(body)) > 4000 {
		return nil, fmt.Errorf("message must contain between 1 and 4000 characters")
	}
	if messageType != "text" && messageType != "internal_note" {
		return nil, fmt.Errorf("unsupported message type")
	}

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
		if ticket.Status == statusWaitingForAgent {
			ticket.Status = statusHumanActive
		}
		if ticket.FirstHumanResponseAt == nil {
			now := time.Now()
			ticket.FirstHumanResponseAt = &now
			_ = s.repo.UpdateTicket(ticket)
		}

		// Send FCM to user
		if messageType != "internal_note" {
			s.sendFCMToUser(ticket.UserID, "support_reply", map[string]string{
				"type":       "support_reply",
				"ticket_id":  ticket.ID.String(),
				"message_id": msg.ID.String(),
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
			_ = s.repo.UpdateTicket(ticket)
		}

		s.sendFCMToUser(ticket.UserID, "support_attachment", map[string]string{
			"type":       "support_attachment",
			"ticket_id":  ticket.ID.String(),
			"message_id": msg.ID.String(),
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
	ticket.Status = statusResolved
	if err := s.repo.UpdateTicket(ticket); err != nil {
		return err
	}

	sysMsg := &models.SupportMessage{
		TicketID:    ticket.ID,
		SenderType:  "system",
		Body:        localizedResolved(ticket.Language),
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
	// The WebSocket hub already supplies the typed envelope. Passing the
	// payload directly keeps support events consistent with every other
	// realtime consumer and avoids a JSON string nested inside JSON.
	s.wsHub.BroadcastToUser(userID.String(), eventType, payload)
	// The support inbox receives the same typed event through a role-scoped
	// channel. The WebSocket hub checks JWT roles before delivery, preventing
	// normal users from observing any other support conversation.
	s.wsHub.BroadcastToRoles(
		[]string{"support_agent", "admin", "super_admin"},
		eventType,
		payload,
	)
}

func (s *Service) sendFCMToUser(userID uuid.UUID, notificationType string, data map[string]string) {
	if s.notifSvc == nil {
		log.Printf("[SUPPORT] push skipped: notification service unavailable")
		return
	}
	data["entity_type"] = "support_ticket"
	data["entity_id"] = data["ticket_id"]
	dedupeKey := notificationType + ":" + data["message_id"]
	copy, notificationID, created, err := s.notifSvc.CreateLocalizedOnce(userID, notificationType, data, dedupeKey)
	if err != nil {
		log.Printf("[SUPPORT] notification create failed: %v", err)
		return
	}
	if !created || s.pushSvc == nil {
		return
	}
	data["notification_id"] = notificationID.String()
	go s.pushSvc.SendToUser(userID, copy.Title, copy.Message, data)
}

func normalizeLanguage(language string) string {
	language = strings.ToLower(strings.TrimSpace(language))
	if strings.HasPrefix(language, "ar") {
		return "ar"
	}
	if strings.HasPrefix(language, "tr") {
		return "tr"
	}
	return "en"
}

func dereferenceContext(value *string) string {
	if value == nil {
		return "none"
	}
	return *value
}

func conversationCategory(contextType *string) string {
	if contextType == nil {
		return "general"
	}
	return *contextType
}

func localizedConversationSubject(language string) string {
	switch normalizeLanguage(language) {
	case "ar":
		return "محادثة دعم خير"
	case "tr":
		return "Khair destek konuşması"
	default:
		return "Khair support conversation"
	}
}

func localizedWelcome(language string) string {
	switch normalizeLanguage(language) {
	case "ar":
		return "السلام عليكم 👋\nأنا ذكاء خير الاصطناعي. يمكنني المساعدة في الفعاليات والحسابات وطلبات التنظيم والإشعارات واستخدام خير. كيف يمكنني مساعدتك؟"
	case "tr":
		return "Selamün aleyküm 👋\nBen Khair AI. Etkinlikler, hesaplar, organizatör başvuruları, bildirimler ve Khair kullanımıyla ilgili yardımcı olabilirim. Size nasıl yardımcı olabilirim?"
	default:
		return "Assalamu Alaikum 👋\nI'm Khair AI. I can help with events, accounts, organizer applications, notifications, and using Khair. How can I help?"
	}
}

func localizedAIFailure(language string) string {
	switch normalizeLanguage(language) {
	case "ar":
		return "أواجه صعوبة في الرد الآن. يمكنك المحاولة مرة أخرى أو التواصل مع دعم خير."
	case "tr":
		return "Şu anda yanıt vermekte zorlanıyorum. Tekrar deneyebilir veya Khair Desteğe bağlanabilirsiniz."
	default:
		return "I'm having trouble responding right now. You can try again or contact Khair Support."
	}
}

func localizedQueuedForSupport(language string) string {
	switch normalizeLanguage(language) {
	case "ar":
		return "تم إرسال محادثتك إلى دعم خير. سنُعلمك عندما يرد أحد أعضاء الفريق."
	case "tr":
		return "Konuşmanız Khair Desteğe gönderildi. Bir ekip üyesi yanıt verdiğinde size haber vereceğiz."
	default:
		return "Your conversation has been sent to Khair Support. We'll notify you when someone replies."
	}
}

func localizedAgentJoined(language string) string {
	switch normalizeLanguage(language) {
	case "ar":
		return "انضم أحد أعضاء فريق دعم خير إلى المحادثة."
	case "tr":
		return "Khair Destek ekibinden bir üye konuşmaya katıldı."
	default:
		return "A member of Khair Support joined the conversation."
	}
}

func localizedResolved(language string) string {
	switch normalizeLanguage(language) {
	case "ar":
		return "تم حل هذه المحادثة. إذا كنت لا تزال بحاجة للمساعدة، أرسل رسالة للمتابعة."
	case "tr":
		return "Bu konuşma çözüldü. Hâlâ yardıma ihtiyacınız varsa devam etmek için mesaj gönderin."
	default:
		return "This conversation has been resolved. Send a message if you still need help."
	}
}

func quickActions(language string) []map[string]string {
	switch normalizeLanguage(language) {
	case "ar":
		return []map[string]string{{"type": "event_issue", "label": "مشكلة في فعالية"}, {"type": "account", "label": "الحساب وتسجيل الدخول"}, {"type": "organizer_application", "label": "طلب التنظيم"}, {"type": "notifications", "label": "الإشعارات"}, {"type": "report_problem", "label": "الإبلاغ عن مشكلة"}, {"type": "other", "label": "شيء آخر"}}
	case "tr":
		return []map[string]string{{"type": "event_issue", "label": "Etkinlik sorunu"}, {"type": "account", "label": "Hesap ve giriş"}, {"type": "organizer_application", "label": "Organizatör başvurusu"}, {"type": "notifications", "label": "Bildirimler"}, {"type": "report_problem", "label": "Sorun bildir"}, {"type": "other", "label": "Başka bir konu"}}
	default:
		return []map[string]string{{"type": "event_issue", "label": "Event issue"}, {"type": "account", "label": "Account & login"}, {"type": "organizer_application", "label": "Organizer application"}, {"type": "notifications", "label": "Notifications"}, {"type": "report_problem", "label": "Report a problem"}, {"type": "other", "label": "Something else"}}
	}
}

func supportActionsFor(message, language string) []models.SupportAction {
	text := strings.ToLower(message)
	if containsAny(text, "meeting link", "meeting", "zoom", "link", "رابط", "زوم", "toplantı") {
		return []models.SupportAction{{Type: "open_my_events", Label: localizedActionLabel("open_my_events", language)}}
	}
	if containsAny(text, "organizer", "application", "organizat", "منظم", "طلب", "başvuru") {
		return []models.SupportAction{{Type: "view_organizer_application", Label: localizedActionLabel("view_organizer_application", language)}}
	}
	if containsAny(text, "notification", "bildirim", "إشعار") {
		return []models.SupportAction{{Type: "open_notification_settings", Label: localizedActionLabel("open_notification_settings", language)}}
	}
	return nil
}

func localizedActionLabel(action, language string) string {
	switch normalizeLanguage(language) {
	case "ar":
		switch action {
		case "open_my_events":
			return "فتح فعالياتي"
		case "view_organizer_application":
			return "عرض طلب التنظيم"
		case "talk_to_support":
			return "التواصل مع دعم خير"
		default:
			return "فتح إعدادات الإشعارات"
		}
	case "tr":
		switch action {
		case "open_my_events":
			return "Etkinliklerimi aç"
		case "view_organizer_application":
			return "Organizatör başvurumu görüntüle"
		case "talk_to_support":
			return "Khair Desteğe bağlan"
		default:
			return "Bildirim ayarlarını aç"
		}
	default:
		switch action {
		case "open_my_events":
			return "Open My Events"
		case "view_organizer_application":
			return "View Application"
		case "talk_to_support":
			return "Talk to Khair Support"
		default:
			return "Open Notification Settings"
		}
	}
}

func requestsHuman(message string) bool {
	return containsAny(strings.ToLower(message), "talk to human", "talk to a human", "real person", "support agent", "human agent", "موظف", "اريد التحدث مع شخص", "أريد التحدث مع شخص", "أريد الدعم", "destek temsilcisi", "gerçek kişi")
}

func containsAny(text string, phrases ...string) bool {
	for _, phrase := range phrases {
		if strings.Contains(text, strings.ToLower(phrase)) {
			return true
		}
	}
	return false
}

func truncateSubject(value string) string {
	runes := []rune(strings.TrimSpace(value))
	if len(runes) <= 120 {
		return string(runes)
	}
	return string(runes[:117]) + "..."
}

func buildHandoffSummary(ticket *models.SupportTicket, messages []*models.SupportMessage) string {
	var userIssue string
	var actions []string
	for _, message := range messages {
		switch message.SenderType {
		case "user":
			if userIssue == "" {
				userIssue = truncateSubject(message.Body)
			}
		case "ai":
			actions = append(actions, truncateSubject(message.Body))
		}
	}
	if userIssue == "" {
		userIssue = ticket.Subject
	}
	parts := []string{fmt.Sprintf("Issue: %s", userIssue)}
	if ticket.ContextType != nil {
		parts = append(parts, fmt.Sprintf("Context: %s", *ticket.ContextType))
	}
	parts = append(parts, fmt.Sprintf("Language: %s", normalizeLanguage(ticket.Language)))
	if len(actions) > 0 {
		parts = append(parts, "AI responses: "+strings.Join(actions[:min(2, len(actions))], " | "))
	}
	return strings.Join(parts, "\n")
}

func min(left, right int) int {
	if left < right {
		return left
	}
	return right
}
