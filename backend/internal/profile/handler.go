package profile

import (
	"database/sql"
	"encoding/base64"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/internal/ai"
	"github.com/khair/backend/internal/eligibility"
	"github.com/khair/backend/pkg/response"
	"github.com/khair/backend/pkg/storage"
)

// ─── Request / Response types ─────────────────────

type UpdateProfileRequest struct {
	DisplayName              *string `json:"display_name"`
	Bio                      *string `json:"bio"`
	City                     *string `json:"city"`
	Country                  *string `json:"country"`
	Location                 *string `json:"location"`
	PreferredLanguage        *string `json:"preferred_language"`
	AvatarURL                *string `json:"avatar_url"`
	PushNotifications        *bool   `json:"push_notifications"`
	EmailNotifications       *bool   `json:"email_notifications"`
	ProfileVisibility        *string `json:"profile_visibility"`
	Gender                   *string `json:"gender"`
	ConfirmEligibilityImpact *bool   `json:"confirm_eligibility_impact"`
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
	Gender            string    `json:"gender"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
}

// ─── Handler ──────────────────────────────────────

type Handler struct {
	db       *sql.DB
	aiClient *ai.Client
	storage  storage.Provider
}

func NewHandler(db *sql.DB, aiClient *ai.Client, mediaStorage storage.Provider) *Handler {
	return &Handler{db: db, aiClient: aiClient, storage: mediaStorage}
}

func (h *Handler) RegisterRoutes(v1 *gin.RouterGroup, engine *gin.Engine, authMiddleware gin.HandlerFunc) {
	profile := v1.Group("/profile")
	profile.Use(authMiddleware)
	{
		profile.GET("", h.GetProfile)
		profile.PUT("", h.UpdateProfile)
		profile.DELETE("", h.DeleteAccount)
		profile.POST("/moderate-text", h.ModerateText)
		profile.POST("/moderate-image", h.ModerateImage)
		profile.POST("/upload-avatar", h.UploadAvatar)
	}
	me := v1.Group("/me")
	me.Use(authMiddleware)
	me.GET("/profile-overview", h.GetOverview)
}

// ─── GET /profile ─────────────────────────────────

func (h *Handler) GetProfile(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := userID.(uuid.UUID)
	// Email registrations created before profile setup still receive a safe,
	// empty profile rather than a 404 on their first edit.
	if _, err := h.db.Exec(`INSERT INTO profiles (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING`, uid); err != nil {
		response.InternalServerError(c, "Failed to load profile")
		return
	}

	var p ProfileResponse
	err := h.db.QueryRow(`
		SELECT p.id, p.user_id, u.display_name, u.email, p.bio, p.city, p.country,
		       p.location, p.avatar_url, p.preferred_language, COALESCE(u.gender, 'NOT_SET'),
		       p.created_at, p.updated_at
		FROM profiles p
		JOIN users u ON u.id = p.user_id
		WHERE p.user_id = $1`, uid,
	).Scan(
		&p.ID, &p.UserID, &p.DisplayName, &p.Email, &p.Bio, &p.City, &p.Country,
		&p.Location, &p.AvatarURL, &p.PreferredLanguage, &p.Gender, &p.CreatedAt, &p.UpdatedAt,
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

// ─── DELETE /profile ──────────────────────────────
// DeleteAccount permanently deletes the authenticated user's account and all
// associated data. This action is irreversible. The client must clear its
// local session after receiving 200 OK.
func (h *Handler) DeleteAccount(c *gin.Context) {
	uid := c.MustGet("user_id").(uuid.UUID)

	tx, err := h.db.Begin()
	if err != nil {
		response.InternalServerError(c, "Failed to begin transaction")
		return
	}
	defer tx.Rollback() //nolint:errcheck

	// Cascade delete: profiles, event registrations, saved events, device tokens,
	// notifications, and finally the user row itself (which foreign keys cascade).
	steps := []struct {
		query string
		name  string
	}{
		{`DELETE FROM device_tokens WHERE user_id = $1`, "device_tokens"},
		{`DELETE FROM notifications WHERE user_id = $1`, "notifications"},
		{`DELETE FROM saved_events WHERE user_id = $1`, "saved_events"},
		{`DELETE FROM event_registrations WHERE user_id = $1`, "event_registrations"},
		{`DELETE FROM profiles WHERE user_id = $1`, "profiles"},
		{`DELETE FROM users WHERE id = $1`, "users"},
	}
	for _, step := range steps {
		if _, err := tx.Exec(step.query, uid); err != nil {
			log.Printf("DeleteAccount: failed to delete %s for user %s: %v", step.name, uid, err)
			response.InternalServerError(c, "Failed to delete account")
			return
		}
	}

	if err := tx.Commit(); err != nil {
		response.InternalServerError(c, "Failed to commit account deletion")
		return
	}

	log.Printf("Account deleted: user_id=%s", uid)
	response.Success(c, gin.H{"message": "Account deleted successfully"})
}

// GetOverview returns the authenticated member's profile in one inexpensive
// payload. Counts and upcoming events are derived from persisted saves and
// confirmed reservations; callers never supply a user ID.
func (h *Handler) GetOverview(c *gin.Context) {
	uid := c.MustGet("user_id").(uuid.UUID)
	var overview struct {
		User struct {
			ID                uuid.UUID `json:"id"`
			DisplayName       *string   `json:"display_name,omitempty"`
			Email             string    `json:"email"`
			AvatarURL         *string   `json:"avatar_url,omitempty"`
			AccountType       string    `json:"account_type"`
			CreatedAt         time.Time `json:"created_at"`
			Country           *string   `json:"country,omitempty"`
			City              *string   `json:"city,omitempty"`
			PreferredLanguage string    `json:"preferred_language"`
		} `json:"user"`
		Stats struct {
			SavedEvents       int `json:"saved_events"`
			JoinedEvents      int `json:"joined_events"`
			UpcomingEvents    int `json:"upcoming_events"`
			ProfileCompletion int `json:"profile_completion"`
		} `json:"stats"`
		Organizer struct {
			Status          string  `json:"status"`
			RejectionReason *string `json:"rejection_reason,omitempty"`
		} `json:"organizer"`
		Preferences struct {
			PushNotifications  bool   `json:"push_notifications"`
			EmailNotifications bool   `json:"email_notifications"`
			ProfileVisibility  string `json:"profile_visibility"`
			Language           string `json:"language"`
			LocationLabel      string `json:"location_label"`
		} `json:"preferences"`
		Upcoming []struct {
			EventID          uuid.UUID `json:"event_id"`
			Title            string    `json:"title"`
			StartDate        time.Time `json:"start_date"`
			ImageURL         *string   `json:"image_url,omitempty"`
			Location         string    `json:"location"`
			AttendanceStatus string    `json:"attendance_status"`
			IsOnline         bool      `json:"is_online"`
		} `json:"upcoming_events"`
	}

	err := h.db.QueryRow(`
		SELECT u.id, u.display_name, u.email, u.role, u.created_at,
		       p.avatar_url, p.country, p.city, COALESCE(p.preferred_language, 'en')
		FROM users u LEFT JOIN profiles p ON p.user_id = u.id WHERE u.id = $1`, uid,
	).Scan(&overview.User.ID, &overview.User.DisplayName, &overview.User.Email,
		&overview.User.AccountType, &overview.User.CreatedAt, &overview.User.AvatarURL,
		&overview.User.Country, &overview.User.City, &overview.User.PreferredLanguage)
	if err != nil {
		response.InternalServerError(c, "Failed to load profile")
		return
	}
	overview.User.AccountType = accountTypeLabel(overview.User.AccountType)

	if err := h.db.QueryRow(`SELECT COUNT(*) FROM saved_events WHERE user_id = $1`, uid).Scan(&overview.Stats.SavedEvents); err != nil {
		response.InternalServerError(c, "Failed to load profile statistics")
		return
	}
	if err := h.db.QueryRow(`SELECT COUNT(*) FROM event_registrations WHERE user_id = $1 AND status = 'confirmed'`, uid).Scan(&overview.Stats.JoinedEvents); err != nil {
		response.InternalServerError(c, "Failed to load profile statistics")
		return
	}
	if err := h.db.QueryRow(`SELECT COUNT(*) FROM event_registrations er JOIN events e ON e.id = er.event_id WHERE er.user_id = $1 AND er.status = 'confirmed' AND e.start_date >= NOW()`, uid).Scan(&overview.Stats.UpcomingEvents); err != nil {
		response.InternalServerError(c, "Failed to load profile statistics")
		return
	}
	overview.Stats.ProfileCompletion = profileCompletion(overview.User.DisplayName, overview.User.AvatarURL, overview.User.Country, overview.User.City, overview.User.PreferredLanguage)

	overview.Organizer.Status = "none"
	_ = h.db.QueryRow(`SELECT status, rejection_reason FROM organizers WHERE user_id = $1`, uid).Scan(&overview.Organizer.Status, &overview.Organizer.RejectionReason)
	if overview.Organizer.Status == "" {
		overview.Organizer.Status = "none"
	}

	overview.Preferences.PushNotifications = true
	overview.Preferences.EmailNotifications = true
	overview.Preferences.ProfileVisibility = "private"
	_ = h.db.QueryRow(`SELECT push_notifications, email_notifications, profile_visibility FROM user_profile_preferences WHERE user_id = $1`, uid).Scan(&overview.Preferences.PushNotifications, &overview.Preferences.EmailNotifications, &overview.Preferences.ProfileVisibility)
	overview.Preferences.Language = overview.User.PreferredLanguage
	overview.Preferences.LocationLabel = locationLabel(overview.User.City, overview.User.Country)

	rows, err := h.db.Query(`
		SELECT e.id, e.title, e.start_date, e.image_url,
		       COALESCE(NULLIF(e.city, ''), NULLIF(e.country, ''), CASE WHEN e.is_online THEN 'Online event' ELSE 'Location to be announced' END),
		       er.status, e.is_online
		FROM event_registrations er JOIN events e ON e.id = er.event_id
		WHERE er.user_id = $1 AND er.status = 'confirmed' AND e.start_date >= NOW()
		ORDER BY e.start_date ASC LIMIT 3`, uid)
	if err != nil {
		response.InternalServerError(c, "Failed to load upcoming events")
		return
	}
	defer rows.Close()
	for rows.Next() {
		var item struct {
			EventID          uuid.UUID `json:"event_id"`
			Title            string    `json:"title"`
			StartDate        time.Time `json:"start_date"`
			ImageURL         *string   `json:"image_url,omitempty"`
			Location         string    `json:"location"`
			AttendanceStatus string    `json:"attendance_status"`
			IsOnline         bool      `json:"is_online"`
		}
		if err := rows.Scan(&item.EventID, &item.Title, &item.StartDate, &item.ImageURL, &item.Location, &item.AttendanceStatus, &item.IsOnline); err == nil {
			overview.Upcoming = append(overview.Upcoming, item)
		}
	}
	response.Success(c, overview)
}

func profileCompletion(name, avatar, country, city *string, language string) int {
	completed := 0
	if name != nil && strings.TrimSpace(*name) != "" {
		completed++
	}
	if avatar != nil && strings.TrimSpace(*avatar) != "" {
		completed++
	}
	if country != nil && strings.TrimSpace(*country) != "" {
		completed++
	}
	if city != nil && strings.TrimSpace(*city) != "" {
		completed++
	}
	if strings.TrimSpace(language) != "" {
		completed++
	}
	return completed * 20
}

func accountTypeLabel(role string) string {
	switch role {
	case "organizer":
		return "Organizer"
	case "admin":
		return "Administrator"
	default:
		return "Member"
	}
}

func locationLabel(city, country *string) string {
	parts := []string{}
	if city != nil && strings.TrimSpace(*city) != "" {
		parts = append(parts, strings.TrimSpace(*city))
	}
	if country != nil && strings.TrimSpace(*country) != "" {
		parts = append(parts, strings.TrimSpace(*country))
	}
	if len(parts) == 0 {
		return "Not set"
	}
	return strings.Join(parts, ", ")
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
	if req.DisplayName != nil && len([]rune(strings.TrimSpace(*req.DisplayName))) > 80 {
		response.BadRequest(c, "Display name must be 80 characters or fewer")
		return
	}
	if req.Bio != nil && len([]rune(strings.TrimSpace(*req.Bio))) > 500 {
		response.BadRequest(c, "Bio must be 500 characters or fewer")
		return
	}
	if req.City != nil && len([]rune(strings.TrimSpace(*req.City))) > 100 {
		response.BadRequest(c, "City name must be 100 characters or fewer")
		return
	}
	if req.Country != nil && len([]rune(strings.TrimSpace(*req.Country))) > 100 {
		response.BadRequest(c, "Country name must be 100 characters or fewer")
		return
	}
	if req.Location != nil && len([]rune(strings.TrimSpace(*req.Location))) > 100 {
		response.BadRequest(c, "Location must be 100 characters or fewer")
		return
	}
	if req.AvatarURL != nil && len([]rune(strings.TrimSpace(*req.AvatarURL))) > 1024 {
		response.BadRequest(c, "Avatar URL must be 1024 characters or fewer")
		return
	}
	if req.PreferredLanguage != nil && *req.PreferredLanguage != "en" && *req.PreferredLanguage != "ar" && *req.PreferredLanguage != "tr" {
		response.BadRequest(c, "Unsupported preferred language")
		return
	}
	if req.ProfileVisibility != nil && *req.ProfileVisibility != "private" && *req.ProfileVisibility != "event_attendees" {
		response.BadRequest(c, "Unsupported profile visibility")
		return
	}

	var requestedGender string
	previousGender := eligibility.GenderNotSet
	genderChanged := false
	if req.Gender != nil {
		requestedGender = eligibility.NormalizeGender(*req.Gender)
		var currentGender sql.NullString
		if err := h.db.QueryRow(`SELECT gender FROM users WHERE id = $1`, uid).Scan(&currentGender); err != nil {
			response.InternalServerError(c, "Failed to load profile eligibility")
			return
		}
		previousGender = eligibility.NormalizeGender(currentGender.String)
		genderChanged = requestedGender != eligibility.NormalizeGender(currentGender.String)
		if genderChanged {
			var affected bool
			if err := h.db.QueryRow(`
				SELECT EXISTS(
					SELECT 1
					FROM event_registrations er
					JOIN events e ON e.id = er.event_id
					WHERE er.user_id = $1
					  AND er.status IN ('pending', 'confirmed', 'reserved')
					  AND COALESCE(e.end_date, e.start_date) > NOW()
					  AND COALESCE(e.attendance_policy, 'EVERYONE') <> 'EVERYONE'
					  AND ((e.attendance_policy = 'WOMEN_ONLY' AND $2::varchar <> 'WOMAN')
					    OR (e.attendance_policy = 'MEN_ONLY' AND $2::varchar <> 'MAN'))
				)`, uid, requestedGender).Scan(&affected); err != nil {
				response.InternalServerError(c, "Failed to check affected registrations")
				return
			}
			if affected && (req.ConfirmEligibilityImpact == nil || !*req.ConfirmEligibilityImpact) {
				response.ErrorWithCode(c, http.StatusConflict,
					"ELIGIBILITY_CHANGE_CONFIRMATION_REQUIRED",
					"Changing this profile detail may affect upcoming event registrations. Please confirm to continue.")
				return
			}
		}
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
	if req.Gender != nil {
		if _, err := h.db.Exec(`
			UPDATE users
			SET gender = $1, gender_updated_at = CASE WHEN $1::varchar = COALESCE(gender, 'NOT_SET') THEN gender_updated_at ELSE $2 END, updated_at = $2
			WHERE id = $3`, requestedGender, now, uid); err != nil {
			log.Printf("[WARN] Failed to update gender for %s: %v", uid, err)
			response.InternalServerError(c, "Failed to update profile eligibility")
			return
		}
		if genderChanged && req.ConfirmEligibilityImpact != nil && *req.ConfirmEligibilityImpact {
			if _, err := h.db.Exec(`
				UPDATE event_registrations er
				SET eligibility_review_required = true, updated_at = NOW()
				FROM events e
				WHERE er.event_id = e.id
				  AND er.user_id = $1
				  AND er.status IN ('pending', 'confirmed', 'reserved')
				  AND COALESCE(e.end_date, e.start_date) > NOW()
				  AND COALESCE(e.attendance_policy, 'EVERYONE') <> 'EVERYONE'
				  AND ((e.attendance_policy = 'WOMEN_ONLY' AND $2::varchar <> 'WOMAN')
				    OR (e.attendance_policy = 'MEN_ONLY' AND $2::varchar <> 'MAN'))`, uid, requestedGender); err != nil {
				log.Printf("[WARN] Failed to flag affected registrations for %s: %v", uid, err)
				response.InternalServerError(c, "Failed to flag affected registrations")
				return
			}
		}
		if genderChanged {
			if _, err := h.db.Exec(`
				INSERT INTO audit_logs
					(id, actor_type, actor_id, action, target_type, target_id, old_value, new_value, reason, ip_address, user_agent)
				VALUES (gen_random_uuid(), 'system', $1, 'profile_gender_changed', 'user', $1, $2::jsonb, $3::jsonb, $4, $5, $6)`,
				uid,
				fmt.Sprintf(`{"gender":"%s"}`, previousGender),
				fmt.Sprintf(`{"gender":"%s"}`, requestedGender),
				"User updated private eligibility information",
				c.ClientIP(),
				c.GetHeader("User-Agent")); err != nil {
				log.Printf("[WARN] Failed to write profile eligibility audit for %s: %v", uid, err)
			}
		}
	}
	if req.PushNotifications != nil || req.EmailNotifications != nil || req.ProfileVisibility != nil {
		push, email, visibility := true, true, "private"
		_ = h.db.QueryRow(`SELECT push_notifications, email_notifications, profile_visibility FROM user_profile_preferences WHERE user_id = $1`, uid).Scan(&push, &email, &visibility)
		if req.PushNotifications != nil {
			push = *req.PushNotifications
		}
		if req.EmailNotifications != nil {
			email = *req.EmailNotifications
		}
		if req.ProfileVisibility != nil {
			visibility = *req.ProfileVisibility
		}
		if _, err := h.db.Exec(`INSERT INTO user_profile_preferences (user_id, push_notifications, email_notifications, profile_visibility) VALUES ($1, $2, $3, $4) ON CONFLICT (user_id) DO UPDATE SET push_notifications = EXCLUDED.push_notifications, email_notifications = EXCLUDED.email_notifications, profile_visibility = EXCLUDED.profile_visibility, updated_at = NOW()`, uid, push, email, visibility); err != nil {
			response.InternalServerError(c, "Failed to update preferences")
			return
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

	if h.aiClient == nil {
		response.Success(c, gin.H{"passed": true, "warning": ""})
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

	if h.aiClient == nil {
		response.Success(c, gin.H{"passed": true, "warning": ""})
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
	if storageErr := storage.UnavailableError(h.storage); storageErr != nil {
		log.Printf("[ERROR] avatar storage unavailable: %v", storageErr)
		response.Error(c, http.StatusServiceUnavailable, "Image storage is temporarily unavailable")
		return
	}

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

	if mimeType != "image/jpeg" && mimeType != "image/png" && mimeType != "image/webp" {
		response.BadRequest(c, "Avatar must be a JPG, PNG, or WebP image")
		return
	}
	if h.storage == nil {
		response.InternalServerError(c, "Image storage is unavailable")
		return
	}
	// The shared storage provider resolves configured cloud storage in production
	// and only uses its local fallback for local development.
	if _, err := file.Seek(0, io.SeekStart); err != nil {
		response.InternalServerError(c, "Failed to prepare image")
		return
	}
	avatarURL, err := h.storage.Upload(file, header, fmt.Sprintf("profiles/%s", uid.String()))
	if err != nil {
		log.Printf("[ERROR] Failed to upload avatar for %s: %v", uid, err)
		response.Error(c, http.StatusServiceUnavailable, "Image storage is temporarily unavailable")
		return
	}

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
