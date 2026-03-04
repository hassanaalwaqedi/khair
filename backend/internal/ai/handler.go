package ai

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/response"
)

// Handler handles AI-related HTTP requests
type Handler struct {
	ranking     *RankingService
	description *DescriptionService
	repo        *InteractionRepository
	client      *Client
}

// NewHandler creates a new AI handler
func NewHandler(ranking *RankingService, description *DescriptionService, repo *InteractionRepository, client *Client) *Handler {
	return &Handler{
		ranking:     ranking,
		description: description,
		repo:        repo,
		client:      client,
	}
}

// RegisterRoutes registers AI routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	ai := r.Group("/ai")
	ai.Use(authMiddleware)
	{
		ai.POST("/interactions", h.LogInteraction)
		ai.GET("/recommendations", h.GetRecommendations)
		ai.POST("/smart-search", h.SmartSearch)
		ai.POST("/enhance-description", h.EnhanceDescription)
		ai.POST("/detect-category", h.DetectCategory)
		ai.GET("/status", h.GetStatus)
	}
}

// ---------- Request/Response types ----------

// LogInteractionRequest is the request body for logging an interaction
type LogInteractionRequest struct {
	EventID         *string         `json:"event_id"`
	InteractionType string          `json:"interaction_type" binding:"required"`
	Metadata        json.RawMessage `json:"metadata,omitempty"`
}

// SmartSearchRequest is the request body for smart search
type SmartSearchRequest struct {
	Query string `json:"query" binding:"required"`
}

// EnhanceDescriptionRequest is the request body for description enhancement
type EnhanceDescriptionRequest struct {
	Title       string   `json:"title" binding:"required"`
	Description string   `json:"description" binding:"required"`
	Tags        []string `json:"tags"`
}

// DetectCategoryRequest is the request body for category detection
type DetectCategoryRequest struct {
	Title       string `json:"title" binding:"required"`
	Description string `json:"description" binding:"required"`
}

// ---------- Handlers ----------

// LogInteraction logs a user interaction signal
// @Summary Log user interaction
// @Tags ai
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body LogInteractionRequest true "Interaction details"
// @Success 201 {object} response.Response
// @Router /ai/interactions [post]
func (h *Handler) LogInteraction(c *gin.Context) {
	var req LogInteractionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	// Validate interaction type
	validTypes := map[string]bool{
		"view": true, "join": true, "save": true,
		"search": true, "filter": true, "click": true,
	}
	if !validTypes[req.InteractionType] {
		response.BadRequest(c, "Invalid interaction type. Must be: view, join, save, search, filter, click")
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		response.Unauthorized(c, "Not authenticated")
		return
	}

	uid, ok := userID.(uuid.UUID)
	if !ok {
		response.Unauthorized(c, "Invalid user ID")
		return
	}

	interaction := &UserInteraction{
		UserID:          uid,
		InteractionType: InteractionType(req.InteractionType),
		Metadata:        req.Metadata,
	}

	if req.EventID != nil {
		eid, err := uuid.Parse(*req.EventID)
		if err != nil {
			response.BadRequest(c, "Invalid event ID")
			return
		}
		interaction.EventID = &eid
	}

	if err := h.repo.LogInteraction(interaction); err != nil {
		response.Error(c, http.StatusInternalServerError, "Failed to log interaction")
		return
	}

	response.Created(c, gin.H{"status": "logged", "id": interaction.ID})
}

// GetRecommendations returns AI-ranked event recommendations
// @Summary Get AI recommendations
// @Tags ai
// @Produce json
// @Security BearerAuth
// @Param limit query int false "Number of recommendations" default(10)
// @Success 200 {object} response.Response
// @Router /ai/recommendations [get]
func (h *Handler) GetRecommendations(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		response.Unauthorized(c, "Not authenticated")
		return
	}

	uid, ok := userID.(uuid.UUID)
	if !ok {
		response.Unauthorized(c, "Invalid user ID")
		return
	}

	limit := 10
	if l := c.Query("limit"); l != "" {
		if parsed, err := parsePositiveInt(l); err == nil && parsed <= 50 {
			limit = parsed
		}
	}

	scores, err := h.ranking.GetRecommendedEvents(c.Request.Context(), uid, limit)
	if err != nil || scores == nil {
		// Graceful fallback — return empty recommendations
		response.Success(c, gin.H{
			"recommendations": []interface{}{},
			"ai_available":    h.client.IsEnabled(),
			"message":         "No personalized recommendations yet. Keep exploring events!",
		})
		return
	}

	response.Success(c, gin.H{
		"recommendations": scores,
		"ai_available":    true,
	})
}

// SmartSearch performs AI-enhanced semantic search
// @Summary AI-powered search
// @Tags ai
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body SmartSearchRequest true "Search query"
// @Success 200 {object} response.Response
// @Router /ai/smart-search [post]
func (h *Handler) SmartSearch(c *gin.Context) {
	var req SmartSearchRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	if len(req.Query) > 500 {
		response.BadRequest(c, "Search query too long (max 500 characters)")
		return
	}

	userID, exists := c.Get("user_id")
	if !exists {
		response.Unauthorized(c, "Not authenticated")
		return
	}

	uid, ok := userID.(uuid.UUID)
	if !ok {
		response.Unauthorized(c, "Invalid user ID")
		return
	}

	// Log the search interaction
	searchMeta, _ := json.Marshal(map[string]string{"query": req.Query})
	_ = h.repo.LogInteraction(&UserInteraction{
		UserID:          uid,
		InteractionType: InteractionSearch,
		Metadata:        searchMeta,
	})

	// Fetch available events for AI to rank
	events, err := h.ranking.getApprovedEvents(50)
	if err != nil || len(events) == 0 {
		response.Success(c, gin.H{
			"matched_ids": []string{},
			"message":     "No events to search",
		})
		return
	}

	matchedIDs, err := h.ranking.SmartSearch(c.Request.Context(), uid, req.Query, events)
	if err != nil {
		// Fallback to empty — frontend will use basic search
		response.Success(c, gin.H{
			"matched_ids":  []string{},
			"ai_available": false,
			"message":      "AI search unavailable, using basic search",
		})
		return
	}

	response.Success(c, gin.H{
		"matched_ids":  matchedIDs,
		"ai_available": true,
	})
}

// EnhanceDescription optimizes an event description using AI
// @Summary Enhance event description
// @Tags ai
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body EnhanceDescriptionRequest true "Description to enhance"
// @Success 200 {object} EnhancedDescription
// @Router /ai/enhance-description [post]
func (h *Handler) EnhanceDescription(c *gin.Context) {
	var req EnhanceDescriptionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	if len(req.Title) > 200 || len(req.Description) > 5000 {
		response.BadRequest(c, "Input too long (title max 200, description max 5000 characters)")
		return
	}
	if len(req.Tags) > 20 {
		response.BadRequest(c, "Too many tags (max 20)")
		return
	}

	result, err := h.description.EnhanceDescription(c.Request.Context(), req.Title, req.Description, req.Tags)
	if err != nil {
		log.Printf("AI enhance-description error: %v", err)
		response.Error(c, http.StatusServiceUnavailable, "AI description enhancement temporarily unavailable")
		return
	}

	response.Success(c, result)
}

// DetectCategory auto-detects event category from description
// @Summary Detect event category
// @Tags ai
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body DetectCategoryRequest true "Event details"
// @Success 200 {object} CategoryDetection
// @Router /ai/detect-category [post]
func (h *Handler) DetectCategory(c *gin.Context) {
	var req DetectCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	if len(req.Title) > 200 || len(req.Description) > 5000 {
		response.BadRequest(c, "Input too long (title max 200, description max 5000 characters)")
		return
	}

	result, err := h.description.DetectCategory(c.Request.Context(), req.Title, req.Description)
	if err != nil {
		log.Printf("AI detect-category error: %v", err)
		response.Error(c, http.StatusServiceUnavailable, "AI category detection temporarily unavailable")
		return
	}

	response.Success(c, result)
}

// GetStatus returns the AI system status
// @Summary AI system status
// @Tags ai
// @Produce json
// @Security BearerAuth
// @Success 200 {object} response.Response
// @Router /ai/status [get]
func (h *Handler) GetStatus(c *gin.Context) {
	response.Success(c, gin.H{
		"ai_enabled": h.client.IsEnabled(),
		"model":      h.client.model,
		"features": gin.H{
			"recommendations":     h.client.IsEnabled(),
			"smart_search":        h.client.IsEnabled(),
			"description_enhance": h.client.IsEnabled(),
			"category_detection":  h.client.IsEnabled(),
		},
	})
}

// ---------- Helpers ----------

func parsePositiveInt(s string) (int, error) {
	var n int
	for _, ch := range s {
		if ch < '0' || ch > '9' {
			return 0, nil
		}
		n = n*10 + int(ch-'0')
	}
	return n, nil
}
