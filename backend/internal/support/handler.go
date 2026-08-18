package support

import (
	"net/http"

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

func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc, adminMiddleware gin.HandlerFunc) {
	supportGroup := r.Group("/support")
	supportGroup.Use(authMiddleware)
	{
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

func (h *Handler) StartSession(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
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
	userIDStr := c.GetString("user_id")
	userID, _ := uuid.Parse(userIDStr)

	tickets, err := h.service.repo.GetUserTickets(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch tickets"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"tickets": tickets})
}

func (h *Handler) GetTicketMessages(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, _ := uuid.Parse(userIDStr)
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
	userIDStr := c.GetString("user_id")
	userID, _ := uuid.Parse(userIDStr)
	ticketIDStr := c.Param("id")
	ticketID, _ := uuid.Parse(ticketIDStr)

	ticket, err := h.service.repo.GetTicketByID(ticketID)
	if err != nil || ticket.UserID != userID {
		c.JSON(http.StatusNotFound, gin.H{"error": "ticket not found"})
		return
	}

	if err := h.service.EscalateTicket(ticketID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "escalated"})
}

func (h *Handler) SendMessage(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, _ := uuid.Parse(userIDStr)
	ticketIDStr := c.Param("id")
	ticketID, _ := uuid.Parse(ticketIDStr)

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

	senderType := "user"
	if isSupport {
		senderType = "support_agent"
	}
	
	msgType := req.MessageType
	if msgType == "" {
		msgType = "text"
	}
	if !isSupport && msgType == "internal_note" {
		msgType = "text"
	}

	msg, err := h.service.SendMessage(ticketID, userID, senderType, req.Body, msgType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send message"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": msg})
}

func (h *Handler) UploadAttachment(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, _ := uuid.Parse(userIDStr)
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

	if header.Size > 10*1024*1024 { // 10MB limit
		c.JSON(http.StatusBadRequest, gin.H{"error": "file too large"})
		return
	}

	senderType := "user"
	if isSupport {
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
	ticketIDStr := c.Param("id")
	ticketID, _ := uuid.Parse(ticketIDStr)
	
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

	userIDStr := c.GetString("user_id")
	agentID, _ := uuid.Parse(userIDStr)
	ticketIDStr := c.Param("id")
	ticketID, _ := uuid.Parse(ticketIDStr)

	if err := h.service.AssignTicket(ticketID, agentID); err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "assigned"})
}

func (h *Handler) isSupportAgent(c *gin.Context) bool {
	rolesRaw, exists := c.Get("roles")
	if !exists {
		return false
	}
	roles, ok := rolesRaw.([]string)
	if !ok {
		return false
	}
	for _, role := range roles {
		if role == "support_agent" || role == "admin" || role == "super_admin" {
			return true
		}
	}
	return false
}
