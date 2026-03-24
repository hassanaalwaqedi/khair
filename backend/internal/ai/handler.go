package ai

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/khair/backend/pkg/response"
)

// Handler serves AI-powered endpoints (ranking, description, category detection).
type Handler struct {
	ranking     *RankingService
	description *DescriptionService
	repo        *InteractionRepository
	client      *Client
}

// NewHandler creates a new AI handler.
func NewHandler(ranking *RankingService, description *DescriptionService, repo *InteractionRepository, client *Client) *Handler {
	return &Handler{
		ranking:     ranking,
		description: description,
		repo:        repo,
		client:      client,
	}
}

// RegisterRoutes mounts the /ai endpoints.
func (h *Handler) RegisterRoutes(v1 *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	ai := v1.Group("/ai")
	ai.Use(authMiddleware)
	{
		ai.POST("/interactions", h.LogInteraction)
		ai.GET("/recommendations", h.GetRecommendations)
		ai.POST("/smart-search", h.SmartSearch)
		ai.POST("/enhance-description", h.EnhanceDescription)
		ai.POST("/detect-category", h.DetectCategory)
		ai.GET("/status", h.Status)
	}
}

// ── POST /ai/interactions ──

func (h *Handler) LogInteraction(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := userID.(uuid.UUID)

	var req struct {
		EventID         *string `json:"event_id"`
		InteractionType string  `json:"interaction_type" binding:"required"`
		Metadata        map[string]interface{} `json:"metadata"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request")
		return
	}

	interaction := &UserInteraction{
		UserID:          uid,
		InteractionType: InteractionType(req.InteractionType),
	}

	if req.EventID != nil {
		eid, err := uuid.Parse(*req.EventID)
		if err == nil {
			interaction.EventID = &eid
		}
	}

	if err := h.repo.LogInteraction(interaction); err != nil {
		log.Printf("[WARN] Failed to log interaction: %v", err)
	}

	response.Success(c, gin.H{"logged": true})
}

// ── GET /ai/recommendations ──

func (h *Handler) GetRecommendations(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := userID.(uuid.UUID)

	scores, err := h.ranking.GetRecommendedEvents(c.Request.Context(), uid, 10)
	if err != nil || len(scores) == 0 {
		response.Success(c, gin.H{"events": []interface{}{}, "ai_powered": false})
		return
	}

	response.Success(c, gin.H{"events": scores, "ai_powered": true})
}

// ── POST /ai/smart-search ──

func (h *Handler) SmartSearch(c *gin.Context) {
	var req struct {
		Query string `json:"query" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Query required")
		return
	}

	response.Success(c, gin.H{
		"results":           []interface{}{},
		"interpreted_query": req.Query,
	})
}

// ── POST /ai/enhance-description ──

func (h *Handler) EnhanceDescription(c *gin.Context) {
	if !h.client.IsEnabled() {
		response.ServiceUnavailable(c, "AI description enhancement temporarily unavailable")
		return
	}

	var req struct {
		Title       string   `json:"title" binding:"required"`
		Description string   `json:"description"`
		Tags        []string `json:"tags"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Title is required")
		return
	}

	result, err := h.description.EnhanceDescription(c.Request.Context(), req.Title, req.Description, req.Tags)
	if err != nil {
		log.Printf("[ERROR] AI enhance-description failed: %v", err)
		response.ServiceUnavailable(c, "AI description enhancement temporarily unavailable")
		return
	}

	response.Success(c, gin.H{
		"description":    result.Description,
		"suggested_tags": result.SuggestedTags,
	})
}

// ── POST /ai/detect-category ──

func (h *Handler) DetectCategory(c *gin.Context) {
	if !h.client.IsEnabled() {
		response.ServiceUnavailable(c, "AI category detection temporarily unavailable")
		return
	}

	var req struct {
		Title       string `json:"title" binding:"required"`
		Description string `json:"description"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Title is required")
		return
	}

	result, err := h.description.DetectCategory(c.Request.Context(), req.Title, req.Description)
	if err != nil {
		log.Printf("[ERROR] AI detect-category failed: %v", err)
		response.ServiceUnavailable(c, "AI category detection temporarily unavailable")
		return
	}

	response.Success(c, gin.H{"category": result.Category})
}

// ── GET /ai/status ──

func (h *Handler) Status(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"enabled": h.client.IsEnabled(),
		},
	})
}
