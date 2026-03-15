package legal

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/response"
)

// Text represents a legal text document
type Text struct {
	ID        uuid.UUID `json:"id" db:"id"`
	Key       string    `json:"key" db:"key"`
	Title     string    `json:"title" db:"title"`
	Content   string    `json:"content" db:"content"`
	UpdatedBy *string   `json:"updated_by,omitempty" db:"updated_by"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}

// Service manages legal text
type Service struct {
	db *sql.DB
}

// NewService creates a new legal service
func NewService(db *sql.DB) *Service {
	return &Service{db: db}
}

// Get retrieves a legal text by key
func (s *Service) Get(key string) (*Text, error) {
	query := `SELECT id, key, title, content, updated_by, created_at, updated_at
	           FROM legal_texts WHERE key = $1`

	var text Text
	err := s.db.QueryRow(query, key).Scan(
		&text.ID, &text.Key, &text.Title, &text.Content,
		&text.UpdatedBy, &text.CreatedAt, &text.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return s.defaultText(key), nil
	}
	if err != nil {
		return nil, err
	}
	return &text, nil
}

// Upsert creates or updates a legal text
func (s *Service) Upsert(key, title, content, updatedBy string) error {
	query := `
		INSERT INTO legal_texts (id, key, title, content, updated_by, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
		ON CONFLICT (key) DO UPDATE SET
			title = EXCLUDED.title,
			content = EXCLUDED.content,
			updated_by = EXCLUDED.updated_by,
			updated_at = NOW()`

	_, err := s.db.Exec(query, uuid.New(), key, title, content, updatedBy)
	return err
}

func (s *Service) defaultText(key string) *Text {
	switch key {
	case "terms":
		return &Text{Key: "terms", Title: "Terms of Service", Content: "Terms of Service for Khair will be available soon. Please contact support for details."}
	case "privacy":
		return &Text{Key: "privacy", Title: "Privacy Policy", Content: "Privacy Policy for Khair will be available soon. Please contact support for details."}
	default:
		return &Text{Key: key, Title: key, Content: "Content not available."}
	}
}

// Handler handles legal text HTTP endpoints
type Handler struct {
	service *Service
}

// NewHandler creates a new legal handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers legal routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware, adminMiddleware gin.HandlerFunc) {
	// Public endpoints
	r.GET("/legal/terms", h.GetTerms)
	r.GET("/legal/privacy", h.GetPrivacy)

	// Admin endpoints
	admin := r.Group("/admin/legal")
	admin.Use(authMiddleware, adminMiddleware)
	{
		admin.PUT("/:key", h.UpdateLegalText)
	}
}

// GetTerms returns terms of service
func (h *Handler) GetTerms(c *gin.Context) {
	text, err := h.service.Get("terms")
	if err != nil {
		response.InternalServerError(c, "Failed to load terms")
		return
	}
	response.Success(c, text)
}

// GetPrivacy returns privacy policy
func (h *Handler) GetPrivacy(c *gin.Context) {
	text, err := h.service.Get("privacy")
	if err != nil {
		response.InternalServerError(c, "Failed to load privacy policy")
		return
	}
	response.Success(c, text)
}

// UpdateLegalText updates a legal text document (admin only)
func (h *Handler) UpdateLegalText(c *gin.Context) {
	key := c.Param("key")
	if key != "terms" && key != "privacy" {
		response.BadRequest(c, "Invalid legal text key, must be 'terms' or 'privacy'")
		return
	}

	var req struct {
		Title   string `json:"title" binding:"required"`
		Content string `json:"content" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	adminID := c.GetString("user_id")

	if err := h.service.Upsert(key, req.Title, req.Content, adminID); err != nil {
		response.Error(c, http.StatusInternalServerError, "Failed to update legal text")
		return
	}

	response.Success(c, gin.H{"message": "Legal text updated successfully"})
}
