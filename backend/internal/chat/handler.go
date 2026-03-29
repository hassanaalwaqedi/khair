package chat

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/response"
)

// Handler handles chat HTTP endpoints
type Handler struct {
	service *Service
}

// NewHandler creates a new chat handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers chat routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	protected := r.Group("")
	protected.Use(authMiddleware)
	{
		protected.POST("/conversations", h.CreateOrGetConversation)
		protected.GET("/conversations", h.GetConversations)
		protected.GET("/conversations/:id/messages", h.GetMessages)
		protected.POST("/conversations/:id/messages", h.SendMessage)
		protected.POST("/conversations/:id/read", h.MarkAsRead)
	}
}

// CreateConversationBody is the request body for creating a conversation
type CreateConversationBody struct {
	SheikhID string `json:"sheikh_id" binding:"required"`
}

// CreateOrGetConversation handles POST /conversations
func (h *Handler) CreateOrGetConversation(c *gin.Context) {
	var body CreateConversationBody
	if err := c.ShouldBindJSON(&body); err != nil {
		response.BadRequest(c, "sheikh_id is required")
		return
	}

	sheikhID, err := uuid.Parse(body.SheikhID)
	if err != nil {
		response.BadRequest(c, "Invalid sheikh ID")
		return
	}

	userID := c.MustGet("user_id").(uuid.UUID)
	conv, err := h.service.GetOrCreateConversation(userID, sheikhID)
	if err != nil {
		response.InternalServerError(c, "Failed to create conversation")
		return
	}
	response.Success(c, conv)
}

// GetConversations handles GET /conversations
func (h *Handler) GetConversations(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	convs, err := h.service.GetConversations(userID)
	if err != nil {
		response.InternalServerError(c, "Failed to load conversations")
		return
	}
	if convs == nil {
		convs = []Conversation{}
	}
	response.Success(c, convs)
}

// GetMessages handles GET /conversations/:id/messages
func (h *Handler) GetMessages(c *gin.Context) {
	convID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid conversation ID")
		return
	}

	userID := c.MustGet("user_id").(uuid.UUID)

	page := 1
	pageSize := 50
	if p := c.Query("page"); p != "" {
		if v, e := strconv.Atoi(p); e == nil && v > 0 {
			page = v
		}
	}
	if ps := c.Query("page_size"); ps != "" {
		if v, e := strconv.Atoi(ps); e == nil && v > 0 && v <= 100 {
			pageSize = v
		}
	}

	msgs, err := h.service.GetMessages(userID, convID, page, pageSize)
	if err != nil {
		response.Error(c, http.StatusForbidden, err.Error())
		return
	}
	if msgs == nil {
		msgs = []Message{}
	}
	response.Success(c, msgs)
}

// SendMessageBody is the request body for sending a message
type SendMessageBody struct {
	Message string `json:"message" binding:"required"`
}

// SendMessage handles POST /conversations/:id/messages
func (h *Handler) SendMessage(c *gin.Context) {
	convID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid conversation ID")
		return
	}

	var body SendMessageBody
	if err := c.ShouldBindJSON(&body); err != nil {
		response.BadRequest(c, "Message is required")
		return
	}

	userID := c.MustGet("user_id").(uuid.UUID)

	msg, err := h.service.SendMessage(userID, convID, body.Message)
	if err != nil {
		response.Error(c, http.StatusForbidden, err.Error())
		return
	}

	response.Created(c, msg)
}

// MarkAsRead handles POST /conversations/:id/read
func (h *Handler) MarkAsRead(c *gin.Context) {
	convID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid conversation ID")
		return
	}

	userID := c.MustGet("user_id").(uuid.UUID)

	if err := h.service.MarkAsRead(userID, convID); err != nil {
		response.Error(c, http.StatusForbidden, err.Error())
		return
	}

	response.SuccessWithMessage(c, "Messages marked as read", nil)
}
