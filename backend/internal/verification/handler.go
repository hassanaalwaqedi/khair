package verification

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/pkg/response"
)

// Repository handles verification database operations
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new verification repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// Handler handles verification HTTP requests
type Handler struct {
	repo *Repository
}

// NewHandler creates a new verification handler
func NewHandler(repo *Repository) *Handler {
	return &Handler{repo: repo}
}

// RegisterRoutes registers verification routes
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup, authMw gin.HandlerFunc, adminMw gin.HandlerFunc) {
	verify := rg.Group("/verification")
	verify.Use(authMw)
	{
		verify.POST("/submit", h.Submit)
		verify.GET("/status", h.Status)
	}

	// Admin review
	adminVerify := rg.Group("/admin/verification")
	adminVerify.Use(authMw, adminMw)
	{
		adminVerify.GET("/pending", h.ListPending)
		adminVerify.POST("/:id/review", h.Review)
	}
}

// SubmitRequest is the request body for submitting a verification
type SubmitRequest struct {
	ProfileImagePath string `json:"profile_image_path" binding:"required"`
	DocumentPath     string `json:"document_path" binding:"required"`
	DocumentType     string `json:"document_type"`
	Notes            string `json:"notes"`
}

// Submit creates a new verification request
// POST /api/v1/verification/submit
func (h *Handler) Submit(c *gin.Context) {
	uid, exists := c.Get("user_id")
	if !exists {
		response.Error(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	userID := uid.(uuid.UUID)

	var req SubmitRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "Invalid request: "+err.Error())
		return
	}

	docType := req.DocumentType
	if docType == "" {
		docType = "general"
	}

	// Check if user already has a pending request
	existing, _ := h.repo.GetByUserID(userID)
	if existing != nil && existing.Status == models.VerificationPendingReview {
		response.Error(c, http.StatusConflict, "You already have a pending verification request")
		return
	}

	vr := &models.VerificationRequest{
		ID:               uuid.New(),
		UserID:           userID,
		ProfileImagePath: &req.ProfileImagePath,
		DocumentPath:     &req.DocumentPath,
		DocumentType:     docType,
		Status:           models.VerificationPendingReview,
		CreatedAt:        time.Now(),
		UpdatedAt:        time.Now(),
	}
	if req.Notes != "" {
		vr.Notes = &req.Notes
	}

	if err := h.repo.Create(vr); err != nil {
		response.Error(c, http.StatusInternalServerError, "Failed to submit verification")
		return
	}

	// Update user's verification_status
	h.repo.UpdateUserVerificationStatus(userID, models.VerificationPendingReview)

	response.Success(c, vr)
}

// Status returns the current verification status for the authenticated user
// GET /api/v1/verification/status
func (h *Handler) Status(c *gin.Context) {
	uid, exists := c.Get("user_id")
	if !exists {
		response.Error(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	userID := uid.(uuid.UUID)

	vr, err := h.repo.GetByUserID(userID)
	if err != nil {
		response.Success(c, gin.H{"status": models.VerificationNone, "has_request": false})
		return
	}

	response.Success(c, gin.H{
		"status":      vr.Status,
		"has_request": true,
		"request":     vr,
	})
}

// ReviewRequest is the request body for admin review
type ReviewRequest struct {
	Status      string `json:"status" binding:"required"` // approved, rejected, more_info_needed
	ReviewNotes string `json:"review_notes"`
}

// Review lets an admin approve or reject a verification request
// POST /api/v1/admin/verification/:id/review
func (h *Handler) Review(c *gin.Context) {
	auid, exists := c.Get("user_id")
	if !exists {
		response.Error(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	adminID := auid.(uuid.UUID)
	requestID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.Error(c, http.StatusBadRequest, "Invalid request ID")
		return
	}

	var req ReviewRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "Invalid request: "+err.Error())
		return
	}

	// Validate status
	validStatuses := map[string]bool{
		"approved":         true,
		"rejected":         true,
		"more_info_needed": true,
	}
	if !validStatuses[req.Status] {
		response.Error(c, http.StatusBadRequest, "Invalid status. Must be: approved, rejected, or more_info_needed")
		return
	}

	vr, err := h.repo.GetByID(requestID)
	if err != nil {
		response.NotFound(c, "Verification request not found")
		return
	}

	// Update the request
	now := time.Now()
	vr.Status = req.Status
	vr.ReviewedBy = &adminID
	vr.ReviewedAt = &now
	if req.ReviewNotes != "" {
		vr.ReviewNotes = &req.ReviewNotes
	}

	if err := h.repo.Update(vr); err != nil {
		response.Error(c, http.StatusInternalServerError, "Failed to update verification")
		return
	}

	// Update user's verification_status
	userStatus := models.VerificationNone
	switch req.Status {
	case "approved":
		userStatus = models.VerificationVerified
	case "rejected":
		userStatus = models.VerificationRejected
	case "more_info_needed":
		userStatus = models.VerificationPendingReview
	}
	h.repo.UpdateUserVerificationStatus(vr.UserID, userStatus)

	response.Success(c, vr)
}

// ListPending returns all pending verification requests (admin only)
// GET /api/v1/admin/verification/pending
func (h *Handler) ListPending(c *gin.Context) {
	requests, err := h.repo.ListByStatus(models.VerificationPendingReview)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, "Failed to load requests")
		return
	}
	response.Success(c, requests)
}

// ─── Repository Methods ───

// Create inserts a new verification request
func (r *Repository) Create(vr *models.VerificationRequest) error {
	_, err := r.db.Exec(`
		INSERT INTO verification_requests
			(id, user_id, profile_image_path, document_path, document_type, notes, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`, vr.ID, vr.UserID, vr.ProfileImagePath, vr.DocumentPath, vr.DocumentType,
		vr.Notes, vr.Status, vr.CreatedAt, vr.UpdatedAt)
	return err
}

// GetByUserID returns the latest verification request for a user
func (r *Repository) GetByUserID(userID uuid.UUID) (*models.VerificationRequest, error) {
	var vr models.VerificationRequest
	err := r.db.QueryRow(`
		SELECT id, user_id, profile_image_path, document_path, document_type, notes,
			   status, reviewed_by, reviewed_at, review_notes, created_at, updated_at
		FROM verification_requests
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT 1
	`, userID).Scan(&vr.ID, &vr.UserID, &vr.ProfileImagePath, &vr.DocumentPath,
		&vr.DocumentType, &vr.Notes, &vr.Status, &vr.ReviewedBy, &vr.ReviewedAt,
		&vr.ReviewNotes, &vr.CreatedAt, &vr.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &vr, nil
}

// GetByID returns a verification request by ID
func (r *Repository) GetByID(id uuid.UUID) (*models.VerificationRequest, error) {
	var vr models.VerificationRequest
	err := r.db.QueryRow(`
		SELECT id, user_id, profile_image_path, document_path, document_type, notes,
			   status, reviewed_by, reviewed_at, review_notes, created_at, updated_at
		FROM verification_requests
		WHERE id = $1
	`, id).Scan(&vr.ID, &vr.UserID, &vr.ProfileImagePath, &vr.DocumentPath,
		&vr.DocumentType, &vr.Notes, &vr.Status, &vr.ReviewedBy, &vr.ReviewedAt,
		&vr.ReviewNotes, &vr.CreatedAt, &vr.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &vr, nil
}

// Update updates a verification request
func (r *Repository) Update(vr *models.VerificationRequest) error {
	_, err := r.db.Exec(`
		UPDATE verification_requests
		SET status = $1, reviewed_by = $2, reviewed_at = $3, review_notes = $4, updated_at = NOW()
		WHERE id = $5
	`, vr.Status, vr.ReviewedBy, vr.ReviewedAt, vr.ReviewNotes, vr.ID)
	return err
}

// ListByStatus returns all verification requests with a given status
func (r *Repository) ListByStatus(status string) ([]models.VerificationRequest, error) {
	rows, err := r.db.Query(`
		SELECT id, user_id, profile_image_path, document_path, document_type, notes,
			   status, reviewed_by, reviewed_at, review_notes, created_at, updated_at
		FROM verification_requests
		WHERE status = $1
		ORDER BY created_at ASC
	`, status)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var requests []models.VerificationRequest
	for rows.Next() {
		var vr models.VerificationRequest
		if err := rows.Scan(&vr.ID, &vr.UserID, &vr.ProfileImagePath, &vr.DocumentPath,
			&vr.DocumentType, &vr.Notes, &vr.Status, &vr.ReviewedBy, &vr.ReviewedAt,
			&vr.ReviewNotes, &vr.CreatedAt, &vr.UpdatedAt); err != nil {
			return nil, err
		}
		requests = append(requests, vr)
	}
	return requests, rows.Err()
}

// UpdateUserVerificationStatus updates the user's verification_status column
func (r *Repository) UpdateUserVerificationStatus(userID uuid.UUID, status string) {
	r.db.Exec(`UPDATE users SET verification_status = $1 WHERE id = $2`, status, userID)
}
