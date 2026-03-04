package ownerposts

import (
	"database/sql"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/middleware"
	"github.com/khair/backend/pkg/response"
)

// ── Model ──

type OwnerPost struct {
	ID               uuid.UUID `json:"id"`
	Title            string    `json:"title"`
	ShortDescription string    `json:"short_description"`
	ImageURL         *string   `json:"image_url"`
	ExternalLink     *string   `json:"external_link"`
	Location         *string   `json:"location"`
	PublishedAt      time.Time `json:"published_at"`
	CreatedBy        uuid.UUID `json:"created_by"`
	IsActive         bool      `json:"is_active"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
}

type CreatePostRequest struct {
	Title            string  `json:"title" binding:"required,max=255"`
	ShortDescription string  `json:"short_description" binding:"required"`
	ImageURL         *string `json:"image_url"`
	ExternalLink     *string `json:"external_link"`
	Location         *string `json:"location"`
	IsActive         *bool   `json:"is_active"`
}

type UpdatePostRequest struct {
	Title            *string `json:"title"`
	ShortDescription *string `json:"short_description"`
	ImageURL         *string `json:"image_url"`
	ExternalLink     *string `json:"external_link"`
	Location         *string `json:"location"`
	IsActive         *bool   `json:"is_active"`
}

// ── Repository ──

type Repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) Create(post *OwnerPost) error {
	query := `
		INSERT INTO owner_posts (id, title, short_description, image_url, external_link, location, published_at, created_by, is_active)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING created_at, updated_at
	`
	return r.db.QueryRow(query,
		post.ID, post.Title, post.ShortDescription, post.ImageURL,
		post.ExternalLink, post.Location, post.PublishedAt, post.CreatedBy, post.IsActive,
	).Scan(&post.CreatedAt, &post.UpdatedAt)
}

func (r *Repository) GetByID(id uuid.UUID) (*OwnerPost, error) {
	query := `SELECT id, title, short_description, image_url, external_link, location, published_at, created_by, is_active, created_at, updated_at FROM owner_posts WHERE id = $1`
	p := &OwnerPost{}
	err := r.db.QueryRow(query, id).Scan(
		&p.ID, &p.Title, &p.ShortDescription, &p.ImageURL,
		&p.ExternalLink, &p.Location, &p.PublishedAt, &p.CreatedBy,
		&p.IsActive, &p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return p, nil
}

func (r *Repository) ListAll() ([]OwnerPost, error) {
	query := `SELECT id, title, short_description, image_url, external_link, location, published_at, created_by, is_active, created_at, updated_at FROM owner_posts ORDER BY published_at DESC`
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var posts []OwnerPost
	for rows.Next() {
		var p OwnerPost
		if err := rows.Scan(&p.ID, &p.Title, &p.ShortDescription, &p.ImageURL, &p.ExternalLink, &p.Location, &p.PublishedAt, &p.CreatedBy, &p.IsActive, &p.CreatedAt, &p.UpdatedAt); err != nil {
			return nil, err
		}
		posts = append(posts, p)
	}
	return posts, nil
}

func (r *Repository) ListActive() ([]OwnerPost, error) {
	query := `SELECT id, title, short_description, image_url, external_link, location, published_at, created_by, is_active, created_at, updated_at FROM owner_posts WHERE is_active = true ORDER BY published_at DESC`
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var posts []OwnerPost
	for rows.Next() {
		var p OwnerPost
		if err := rows.Scan(&p.ID, &p.Title, &p.ShortDescription, &p.ImageURL, &p.ExternalLink, &p.Location, &p.PublishedAt, &p.CreatedBy, &p.IsActive, &p.CreatedAt, &p.UpdatedAt); err != nil {
			return nil, err
		}
		posts = append(posts, p)
	}
	return posts, nil
}

func (r *Repository) Update(post *OwnerPost) error {
	query := `
		UPDATE owner_posts SET title=$2, short_description=$3, image_url=$4, external_link=$5, location=$6, is_active=$7, updated_at=NOW()
		WHERE id=$1
		RETURNING updated_at
	`
	return r.db.QueryRow(query, post.ID, post.Title, post.ShortDescription, post.ImageURL, post.ExternalLink, post.Location, post.IsActive).Scan(&post.UpdatedAt)
}

func (r *Repository) Delete(id uuid.UUID) error {
	_, err := r.db.Exec(`DELETE FROM owner_posts WHERE id = $1`, id)
	return err
}

// ── Service ──

type Service struct {
	repo *Repository
}

func NewService(db *sql.DB) *Service {
	return &Service{repo: NewRepository(db)}
}

func (s *Service) Create(req *CreatePostRequest, createdBy uuid.UUID) (*OwnerPost, error) {
	post := &OwnerPost{
		ID:               uuid.New(),
		Title:            req.Title,
		ShortDescription: req.ShortDescription,
		ImageURL:         req.ImageURL,
		ExternalLink:     req.ExternalLink,
		Location:         req.Location,
		PublishedAt:      time.Now(),
		CreatedBy:        createdBy,
		IsActive:         true,
	}
	if req.IsActive != nil {
		post.IsActive = *req.IsActive
	}
	if err := s.repo.Create(post); err != nil {
		return nil, err
	}
	return post, nil
}

func (s *Service) GetByID(id uuid.UUID) (*OwnerPost, error) {
	return s.repo.GetByID(id)
}

func (s *Service) ListAll() ([]OwnerPost, error) {
	return s.repo.ListAll()
}

func (s *Service) ListActive() ([]OwnerPost, error) {
	return s.repo.ListActive()
}

func (s *Service) Update(id uuid.UUID, req *UpdatePostRequest) (*OwnerPost, error) {
	post, err := s.repo.GetByID(id)
	if err != nil {
		return nil, err
	}
	if req.Title != nil {
		post.Title = *req.Title
	}
	if req.ShortDescription != nil {
		post.ShortDescription = *req.ShortDescription
	}
	if req.ImageURL != nil {
		post.ImageURL = req.ImageURL
	}
	if req.ExternalLink != nil {
		post.ExternalLink = req.ExternalLink
	}
	if req.Location != nil {
		post.Location = req.Location
	}
	if req.IsActive != nil {
		post.IsActive = *req.IsActive
	}
	if err := s.repo.Update(post); err != nil {
		return nil, err
	}
	return post, nil
}

func (s *Service) Delete(id uuid.UUID) error {
	return s.repo.Delete(id)
}

// ── Handler ──

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc, adminMiddleware gin.HandlerFunc) {
	// Public: read active posts
	r.GET("/owner-posts", h.ListActive)

	// Admin-only: full CRUD
	admin := r.Group("/owner/posts")
	admin.Use(authMiddleware)
	admin.Use(adminMiddleware)
	{
		admin.GET("", h.ListAll)
		admin.POST("", h.Create)
		admin.GET("/:id", h.GetByID)
		admin.PUT("/:id", h.Update)
		admin.DELETE("/:id", h.Delete)
	}
}

func (h *Handler) Create(c *gin.Context) {
	var req CreatePostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	userID, _ := c.Get("user_id")
	uid, _ := userID.(uuid.UUID)

	post, err := h.service.Create(&req, uid)
	if err != nil {
		response.InternalServerError(c, "Failed to create post")
		return
	}
	response.Created(c, post)
}

func (h *Handler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid post ID")
		return
	}
	post, err := h.service.GetByID(id)
	if err != nil {
		response.NotFound(c, "Post not found")
		return
	}
	response.Success(c, post)
}

func (h *Handler) ListAll(c *gin.Context) {
	posts, err := h.service.ListAll()
	if err != nil {
		response.InternalServerError(c, "Failed to list posts")
		return
	}
	if posts == nil {
		posts = []OwnerPost{}
	}
	response.Success(c, posts)
}

func (h *Handler) ListActive(c *gin.Context) {
	posts, err := h.service.ListActive()
	if err != nil {
		response.InternalServerError(c, "Failed to list posts")
		return
	}
	if posts == nil {
		posts = []OwnerPost{}
	}
	response.Success(c, posts)
}

func (h *Handler) Update(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid post ID")
		return
	}
	var req UpdatePostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}
	post, err := h.service.Update(id, &req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	response.Success(c, post)
}

func (h *Handler) Delete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid post ID")
		return
	}
	if err := h.service.Delete(id); err != nil {
		response.InternalServerError(c, "Failed to delete post")
		return
	}
	response.SuccessWithMessage(c, "Post deleted", nil)
}

// ── Adapter for middleware ──

func AdminOnly() gin.HandlerFunc {
	return middleware.AdminOnly()
}
