package profile

import (
	"database/sql"
	"encoding/base64"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/internal/ai"
	"github.com/khair/backend/pkg/response"
)

// ─── Request / Response types ─────────────────────

type UpdateProfileRequest struct {
	DisplayName       *string `json:"display_name"`
	Bio               *string `json:"bio"`
	City              *string `json:"city"`
	Country           *string `json:"country"`
	Location          *string `json:"location"`
	PreferredLanguage *string `json:"preferred_language"`
	AvatarURL         *string `json:"avatar_url"`
}

type ProfileResponse struct {
	ID                uuid.UUID `json:"id"`
	UserID            uuid.UUID `json:"user_id"`
	DisplayName       *string   `json:"display_name,omitempty"`
	Email             string    `json:"email"`
	Bio               *string   `json:"bio,omitempty"`
	City              *string   `json:"city,omitempty"`
	Country           *string   `json:"country,omitempty"`
	Location          *string   `json:"location,omitempty"`
	AvatarURL         *string   `json:"avatar_url,omitempty"`
	PreferredLanguage string    `json:"preferred_language"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
}

// ─── Handler ──────────────────────────────────────

type Handler struct {
	db       *sql.DB
	aiClient *ai.Client
}

func NewHandler(db *sql.DB, aiClient *ai.Client) *Handler {
	return &Handler{db: db, aiClient: aiClient}
}

func (h *Handler) RegisterRoutes(v1 *gin.RouterGroup, engine *gin.Engine, authMiddleware gin.HandlerFunc) {
	profile := v1.Group("/profile")
	profile.Use(authMiddleware)
	{
		profile.GET("", h.GetProfile)
		profile.PUT("", h.UpdateProfile)
		profile.POST("/moderate-text", h.ModerateText)
		profile.POST("/moderate-image", h.ModerateImage)
		profile.POST("/upload-avatar", h.UploadAvatar)
	}

	// Serve uploaded files
	os.MkdirAll("/app/uploads/avatars", 0755)
	engine.Static("/uploads", "/app/uploads")
}

// ─── GET /profile ─────────────────────────────────

func (h *Handler) GetProfile(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := userID.(uuid.UUID)

	var p ProfileResponse
	err := h.db.QueryRow(`
		SELECT p.id, p.user_id, u.display_name, u.email, p.bio, p.city, p.country,
		       p.location, p.avatar_url, p.preferred_language, p.created_at, p.updated_at
		FROM profiles p
		JOIN users u ON u.id = p.user_id
		WHERE p.user_id = $1`, uid,
	).Scan(
		&p.ID, &p.UserID, &p.DisplayName, &p.Email, &p.Bio, &p.City, &p.Country,
		&p.Location, &p.AvatarURL, &p.PreferredLanguage, &p.CreatedAt, &p.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		response.NotFound(c, "Profile not found")
		return
	}
	if err != nil {
		response.InternalServerError(c, "Failed to fetch profile")
		return
	}

	response.Success(c, p)
}

// ─── PUT /profile ─────────────────────────────────

func (h *Handler) UpdateProfile(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := userID.(uuid.UUID)

	var req UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request body")
		return
	}

	// ── AI Text Moderation (fail-open) ──
	textsToCheck := []string{}
	if req.DisplayName != nil && *req.DisplayName != "" {
		textsToCheck = append(textsToCheck, *req.DisplayName)
	}
	if req.Bio != nil && *req.Bio != "" {
		textsToCheck = append(textsToCheck, *req.Bio)
	}

	if len(textsToCheck) > 0 && h.aiClient != nil {
		combined := strings.Join(textsToCheck, " | ")
		result, err := h.aiClient.ModerateText(c.Request.Context(), combined)
		if err != nil {
			log.Printf("[WARN] AI moderation error (skipping): %v", err)
		} else if !result.Passed {
			c.JSON(http.StatusUnprocessableEntity, gin.H{
				"error":   "content_moderation_failed",
				"warning": result.Warning,
			})
			return
		}
	}

	now := time.Now()

	// Check if profile exists
	var exists bool
	err := h.db.QueryRow("SELECT EXISTS(SELECT 1 FROM profiles WHERE user_id = $1)", uid).Scan(&exists)
	if err != nil {
		log.Printf("[ERROR] Failed to check profile existence for %s: %v", uid, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("db check failed: %v", err)})
		return
	}

	if exists {
		// Build dynamic UPDATE
		setClauses := []string{"updated_at = $1"}
		args := []interface{}{now}
		argIdx := 2

		if req.Bio != nil {
			setClauses = append(setClauses, fmt.Sprintf("bio = $%d", argIdx))
			args = append(args, *req.Bio)
			argIdx++
		}
		if req.City != nil {
			setClauses = append(setClauses, fmt.Sprintf("city = $%d", argIdx))
			args = append(args, *req.City)
			argIdx++
		}
		if req.Country != nil {
			setClauses = append(setClauses, fmt.Sprintf("country = $%d", argIdx))
			args = append(args, *req.Country)
			argIdx++
		}
		if req.Location != nil {
			setClauses = append(setClauses, fmt.Sprintf("location = $%d", argIdx))
			args = append(args, *req.Location)
			argIdx++
		}
		if req.PreferredLanguage != nil {
			setClauses = append(setClauses, fmt.Sprintf("preferred_language = $%d", argIdx))
			args = append(args, *req.PreferredLanguage)
			argIdx++
		}
		if req.AvatarURL != nil {
			setClauses = append(setClauses, fmt.Sprintf("avatar_url = $%d", argIdx))
			args = append(args, *req.AvatarURL)
			argIdx++
		}

		args = append(args, uid)
		query := fmt.Sprintf(
			"UPDATE profiles SET %s WHERE user_id = $%d",
			strings.Join(setClauses, ", "), argIdx,
		)

		_, err = h.db.Exec(query, args...)
		if err != nil {
			log.Printf("[ERROR] Failed to update profile for %s: %v", uid, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("update failed: %v", err)})
			return
		}
	} else {
		// INSERT new profile
		bio, city, country, loc, lang, avatar := "", "", "", "", "en", ""
		if req.Bio != nil {
			bio = *req.Bio
		}
		if req.City != nil {
			city = *req.City
		}
		if req.Country != nil {
			country = *req.Country
		}
		if req.Location != nil {
			loc = *req.Location
		}
		if req.PreferredLanguage != nil {
			lang = *req.PreferredLanguage
		}
		if req.AvatarURL != nil {
			avatar = *req.AvatarURL
		}

		_, err = h.db.Exec(`
			INSERT INTO profiles (user_id, bio, city, country, location, preferred_language, avatar_url, created_at, updated_at)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $8)`,
			uid, bio, city, country, loc, lang, avatar, now,
		)
		if err != nil {
			log.Printf("[ERROR] Failed to insert profile for %s: %v", uid, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("insert failed: %v", err)})
			return
		}
	}

	// Update display_name on users table
	if req.DisplayName != nil {
		_, err := h.db.Exec(
			"UPDATE users SET display_name = $1, updated_at = $2 WHERE id = $3",
			*req.DisplayName, now, uid,
		)
		if err != nil {
			log.Printf("[WARN] Failed to update display_name for %s: %v", uid, err)
		}
	}

	// Return updated profile
	h.GetProfile(c)
}

// ─── POST /profile/moderate-text ──────────────────

type ModerateTextRequest struct {
	Text string `json:"text" binding:"required"`
}

func (h *Handler) ModerateText(c *gin.Context) {
	var req ModerateTextRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Text is required")
		return
	}

	result, err := h.aiClient.ModerateText(c.Request.Context(), req.Text)
	if err != nil {
		response.Success(c, gin.H{"passed": true, "warning": ""})
		return
	}

	response.Success(c, result)
}

// ─── POST /profile/moderate-image ─────────────────

func (h *Handler) ModerateImage(c *gin.Context) {
	file, header, err := c.Request.FormFile("image")
	if err != nil {
		response.BadRequest(c, "Image file is required")
		return
	}
	defer file.Close()

	// Limit to 5 MB
	if header.Size > 5*1024*1024 {
		response.BadRequest(c, "Image must be under 5 MB")
		return
	}

	// Read file bytes
	data, err := io.ReadAll(file)
	if err != nil {
		response.InternalServerError(c, "Failed to read image")
		return
	}

	// Determine MIME type
	mimeType := http.DetectContentType(data)
	if !strings.HasPrefix(mimeType, "image/") {
		response.BadRequest(c, "File must be an image")
		return
	}

	// Base64 encode
	b64 := base64.StdEncoding.EncodeToString(data)

	result, err := h.aiClient.ModerateImage(c.Request.Context(), b64, mimeType)
	if err != nil {
		response.Success(c, gin.H{"passed": true, "warning": ""})
		return
	}

	response.Success(c, result)
}

// ─── POST /profile/upload-avatar ──────────────────

func (h *Handler) UploadAvatar(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := userID.(uuid.UUID)

	file, header, err := c.Request.FormFile("image")
	if err != nil {
		response.BadRequest(c, "Image file is required")
		return
	}
	defer file.Close()

	// Limit to 5 MB
	if header.Size > 5*1024*1024 {
		response.BadRequest(c, "Image must be under 5 MB")
		return
	}

	// Read file bytes
	data, err := io.ReadAll(file)
	if err != nil {
		response.InternalServerError(c, "Failed to read image")
		return
	}

	// Validate image
	mimeType := http.DetectContentType(data)
	if !strings.HasPrefix(mimeType, "image/") {
		response.BadRequest(c, "File must be an image")
		return
	}

	// Determine file extension
	ext := ".jpg"
	if strings.Contains(mimeType, "png") {
		ext = ".png"
	} else if strings.Contains(mimeType, "gif") {
		ext = ".gif"
	} else if strings.Contains(mimeType, "webp") {
		ext = ".webp"
	}

	// Save to disk
	filename := fmt.Sprintf("%s%s", uuid.New().String(), ext)
	savePath := filepath.Join("/app/uploads/avatars", filename)
	if err := os.WriteFile(savePath, data, 0644); err != nil {
		log.Printf("[ERROR] Failed to save avatar for %s: %v", uid, err)
		response.InternalServerError(c, "Failed to save image")
		return
	}

	// Build URL
	avatarURL := fmt.Sprintf("/uploads/avatars/%s", filename)

	// Update profile
	_, err = h.db.Exec(`
		INSERT INTO profiles (user_id, avatar_url, created_at, updated_at)
		VALUES ($1, $2, NOW(), NOW())
		ON CONFLICT (user_id) DO UPDATE SET avatar_url = $2, updated_at = NOW()`,
		uid, avatarURL,
	)
	if err != nil {
		log.Printf("[ERROR] Failed to update avatar_url for %s: %v", uid, err)
	}

	response.Success(c, gin.H{
		"avatar_url": avatarURL,
	})
}
