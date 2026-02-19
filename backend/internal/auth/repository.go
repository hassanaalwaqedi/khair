package auth

import (
	"database/sql"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
)

// Repository handles database operations for auth
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new auth repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// CreateUser creates a new user
func (r *Repository) CreateUser(user *models.User) error {
	query := `
		INSERT INTO users (id, email, password_hash, role, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err := r.db.Exec(query, user.ID, user.Email, user.PasswordHash, user.Role, user.CreatedAt, user.UpdatedAt)
	return err
}

// GetUserByEmail retrieves a user by email
func (r *Repository) GetUserByEmail(email string) (*models.User, error) {
	query := `
		SELECT id, email, password_hash, role, created_at, updated_at
		FROM users WHERE email = $1
	`
	user := &models.User{}
	err := r.db.QueryRow(query, email).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.Role, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return user, nil
}

// GetUserByID retrieves a user by ID
func (r *Repository) GetUserByID(id uuid.UUID) (*models.User, error) {
	query := `
		SELECT id, email, password_hash, role, created_at, updated_at
		FROM users WHERE id = $1
	`
	user := &models.User{}
	err := r.db.QueryRow(query, id).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.Role, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return user, nil
}

// CreateOrganizer creates a new organizer profile
func (r *Repository) CreateOrganizer(organizer *models.Organizer) error {
	query := `
		INSERT INTO organizers (id, user_id, name, description, website, phone, logo_url, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`
	_, err := r.db.Exec(query,
		organizer.ID, organizer.UserID, organizer.Name, organizer.Description,
		organizer.Website, organizer.Phone, organizer.LogoURL, organizer.Status,
		organizer.CreatedAt, organizer.UpdatedAt,
	)
	return err
}

// GetOrganizerByUserID retrieves an organizer by user ID
func (r *Repository) GetOrganizerByUserID(userID uuid.UUID) (*models.Organizer, error) {
	query := `
		SELECT id, user_id, name, description, website, phone, logo_url, status, rejection_reason, created_at, updated_at
		FROM organizers WHERE user_id = $1
	`
	org := &models.Organizer{}
	err := r.db.QueryRow(query, userID).Scan(
		&org.ID, &org.UserID, &org.Name, &org.Description, &org.Website,
		&org.Phone, &org.LogoURL, &org.Status, &org.RejectionReason, &org.CreatedAt, &org.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return org, nil
}
