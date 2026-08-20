package support

import (
	"errors"
	"io"
	"mime/multipart"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/khair/backend/internal/models"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc, adminMiddleware gin.HandlerFunc, rateLimitMiddleware ...gin.HandlerFunc) {
	supportGroup := r.Group("/support")
	supportGroup.Use(authMiddleware)
	if len(rateLimitMiddleware) > 0 && rateLimitMiddleware[0] != nil {
		supportGroup.Use(rateLimitMiddleware[0])
	}
	{
		supportGroup.POST("/conversations", h.OpenConversation)
		supportGroup.POST("/sessions", h.StartSession)
		supportGroup.GET("/tickets", h.GetUserTickets)
		supportGroup.GET("/tickets/:id/messages", h.GetTicketMessages)
		supportGroup.POST("/tickets/:id/messages", h.SendMessage)
		supportGroup.POST("/tickets/:id/attachments", h.UploadAttachment)
		supportGroup.POST("/tickets/:id/escalate", h.EscalateTicket)
		supportGroup.POST("/tickets/:id/resolve", h.ResolveTicket)
	}

	adminSupportGroup := r.Group("/admin/support")
	adminSupportGroup.Use(authMiddleware)
	// We check for support_agent inside the handlers, so we don't apply adminMiddleware (which might only allow super_admin).
	{
		adminSupportGroup.GET("/tickets", h.AdminGetTickets)
		adminSupportGroup.POST("/tickets/:id/assign", h.AdminAssignTicket)
	}
}

// OpenConversation starts the AI-first messenger without requiring the user to
// categorize their issue. It resumes the same active record after refresh.
func (h *Handler) OpenConversation(c *gin.Context) {
	userID, ok := h.requestUserID(c)
	if !ok {
		return
	}

	var req models.CreateSupportConversationRequest
	if c.Request.ContentLength > 0 {
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid conversation context"})
			return
		}
	}
	ticket, welcome, created, err := h.service.StartConversation(c.Request.Context(), userID, req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "unable to open support conversation"})
		return
	}
	messages, err := h.service.GetTicketMessages(ticket.ID, false)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "unable to load support conversation"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"conversation": ticket,
		"ticket":       ticket, // compatibility for pre-messenger clients
		"messages":     messages,
		"created":      created,
		"welcome":      welcome,
	})
}

func (h *Handler) StartSession(c *gin.Context) {
	userID, ok := h.requestUserID(c)
	if !ok {
		return
	}

	var req models.CreateSupportTicketRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ticket, aiMsg, err := h.service.StartSession(c.Request.Context(), userID, req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start support session"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"ticket":  ticket,
		"message": aiMsg,
	})
}

func (h *Handler) GetUserTickets(c *gin.Context) {
	userID, ok := h.requestUserID(c)
	if !ok {
		return
	}

	tickets, err := h.service.repo.GetUserTickets(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch tickets"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"tickets": tickets})
}

func (h *Handler) GetTicketMessages(c *gin.Context) {
	userID, ok := h.requestUserID(c)
	if !ok {
		return
	}
	ticketIDStr := c.Param("id")
	ticketID, err := uuid.Parse(ticketIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid ticket ID"})
		return
	}

	ticket, err := h.service.repo.GetTicketByID(ticketID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "ticket not found"})
		return
	}

	isSupport := h.isSupportAgent(c)
	if ticket.UserID != userID && !isSupport {
		c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
		return
	}

	msgs, err := h.service.GetTicketMessages(ticketID, isSupport)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch messages"})
		return
	}

	excludeSenderType := "user"
	if isSupport {
		excludeSenderType = "support_agent"
	}
	h.service.repo.MarkMessagesAsRead(ticketID, excludeSenderType)

	c.JSON(http.StatusOK, gin.H{"messages": msgs})
}

func (h *Handler) EscalateTicket(c *gin.Context) {
	userID, ok := h.requestUserID(c)
	if !ok {
		return
	}
	ticketIDStr := c.Param("id")
	ticketID, err := uuid.Parse(ticketIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid conversation ID"})
		return
	}

	ticket, err := h.service.repo.GetTicketByID(ticketID)
	if err != nil || ticket.UserID != userID {
		c.JSON(http.StatusNotFound, gin.H{"error": "ticket not found"})
		return
	}

	if _, err := h.service.EscalateTicketWithSummary(c.Request.Context(), ticketID, userID, "user_requested_human"); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "escalated"})
}

func (h *Handler) SendMessage(c *gin.Context) {
	userID, ok := h.requestUserID(c)
	if !ok {
		return
	}
	ticketIDStr := c.Param("id")
	ticketID, err := uuid.Parse(ticketIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid conversation ID"})
		return
	}

	var req models.SupportMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ticket, err := h.service.repo.GetTicketByID(ticketID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "ticket not found"})
		return
	}

	isSupport := h.isSupportAgent(c)
	if ticket.UserID != userID && !isSupport {
		c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
		return
	}

	if isSupport && (ticket.AssignedTo == nil || *ticket.AssignedTo != userID) {
		c.JSON(http.StatusConflict, gin.H{"error": "accept this conversation before replying"})
		return
	}

	msgType := req.MessageType
	if msgType == "" {
		msgType = "text"
	}
	if !isSupport && msgType == "internal_note" {
		msgType = "text"
	}

	if isSupport {
		msg, err := h.service.SendMessage(ticketID, userID, "support_agent", req.Body, msgType)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "unable to send message"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"message": msg, "messages": []*models.SupportMessage{msg}})
		return
	}
	if msgType != "text" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "users can send text or an image attachment"})
		return
	}
	messages, err := h.service.SendUserMessage(c.Request.Context(), ticketID, userID, req.Body)
	if err != nil {
		status := http.StatusInternalServerError
		if strings.Contains(err.Error(), "message must") || strings.Contains(err.Error(), "access denied") {
			status = http.StatusBadRequest
		}
		c.JSON(status, gin.H{"error": "unable to send message"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": messages[len(messages)-1], "messages": messages})
}

func (h *Handler) UploadAttachment(c *gin.Context) {
	userID, ok := h.requestUserID(c)
	if !ok {
		return
	}
	ticketIDStr := c.Param("id")
	ticketID, err := uuid.Parse(ticketIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid ticket ID"})
		return
	}

	ticket, err := h.service.repo.GetTicketByID(ticketID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "ticket not found"})
		return
	}

	isSupport := h.isSupportAgent(c)
	if ticket.UserID != userID && !isSupport {
		c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
		return
	}

	file, header, err := c.Request.FormFile("attachment")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "attachment file is required"})
		return
	}
	defer file.Close()

	if err := validateImageAttachment(file, header); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	senderType := "user"
	if isSupport {
		if ticket.AssignedTo == nil || *ticket.AssignedTo != userID {
			c.JSON(http.StatusConflict, gin.H{"error": "accept this conversation before replying"})
			return
		}
		senderType = "support_agent"
	}

	msg, err := h.service.UploadAttachment(c.Request.Context(), ticketID, userID, senderType, file, header)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload attachment"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": msg})
}

func (h *Handler) ResolveTicket(c *gin.Context) {
	userID, ok := h.requestUserID(c)
	if !ok {
		return
	}
	ticketIDStr := c.Param("id")
	ticketID, err := uuid.Parse(ticketIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid conversation ID"})
		return
	}
	ticket, err := h.service.repo.GetTicketByID(ticketID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "conversation not found"})
		return
	}
	isSupport := h.isSupportAgent(c)
	if ticket.UserID != userID && !isSupport {
		c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
		return
	}
	if isSupport && (ticket.AssignedTo == nil || *ticket.AssignedTo != userID) {
		c.JSON(http.StatusForbidden, gin.H{"error": "accept this conversation before resolving it"})
		return
	}

	if err := h.service.ResolveTicket(ticketID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "resolved"})
}

func (h *Handler) AdminGetTickets(c *gin.Context) {
	if !h.isSupportAgent(c) {
		c.JSON(http.StatusForbidden, gin.H{"error": "requires support_agent role"})
		return
	}

	status := c.Query("status")
	tickets, err := h.service.repo.GetAdminTickets(status)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch admin tickets"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"tickets": tickets})
}

func (h *Handler) AdminAssignTicket(c *gin.Context) {
	if !h.isSupportAgent(c) {
		c.JSON(http.StatusForbidden, gin.H{"error": "requires support_agent role"})
		return
	}

	agentID, ok := h.requestUserID(c)
	if !ok {
		return
	}
	ticketIDStr := c.Param("id")
	ticketID, err := uuid.Parse(ticketIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid conversation ID"})
		return
	}

	if err := h.service.AssignTicket(ticketID, agentID); err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "assigned"})
}

func (h *Handler) isSupportAgent(c *gin.Context) bool {
	rolesRaw, exists := c.Get("roles")
	if exists {
		if roles, ok := rolesRaw.([]string); ok {
			for _, role := range roles {
				if role == "support_agent" || role == "admin" || role == "super_admin" {
					return true
				}
			}
		}
	}
	role, _ := c.Get("role")
	return role == "support_agent" || role == "admin" || role == "super_admin"
}

func (h *Handler) requestUserID(c *gin.Context) (uuid.UUID, bool) {
	userID, err := uuid.Parse(c.GetString("user_id"))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return uuid.Nil, false
	}
	return userID, true
}

func validateImageAttachment(file multipart.File, header *multipart.FileHeader) error {
	if header.Size <= 0 || header.Size > 5*1024*1024 {
		return errors.New("choose a JPG, PNG, or WebP image smaller than 5 MB")
	}
	mimeType := strings.ToLower(strings.TrimSpace(strings.Split(header.Header.Get("Content-Type"), ";")[0]))
	extension := strings.ToLower(filepath.Ext(header.Filename))
	allowed := map[string]string{
		"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp",
	}
	expectedExtension, ok := allowed[mimeType]
	if !ok || (extension != expectedExtension && !(mimeType == "image/jpeg" && extension == ".jpeg")) {
		return errors.New("only JPG, PNG, and WebP image attachments are supported")
	}

	// Multipart headers and file extensions are controlled by the client. Inspect
	// the magic bytes as well, then rewind so the private-storage upload receives
	// the complete original image.
	buffer := make([]byte, 512)
	n, err := file.Read(buffer)
	if err != nil && err != io.EOF {
		return errors.New("unable to read image attachment")
	}
	if _, err := file.Seek(0, io.SeekStart); err != nil {
		return errors.New("unable to process image attachment")
	}
	detected := strings.ToLower(http.DetectContentType(buffer[:n]))
	if detected != mimeType {
		return errors.New("image content does not match its file type")
	}
	return nil
}
