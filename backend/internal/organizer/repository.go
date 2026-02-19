package organizer

import (
	"database/sql"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
)

// Repository handles database operations for organizers
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new organizer repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// GetByID retrieves an organizer by ID
func (r *Repository) GetByID(id uuid.UUID) (*models.Organizer, error) {
	query := `
		SELECT id, user_id, name, description, website, phone, logo_url, status, rejection_reason, created_at, updated_at
		FROM organizers WHERE id = $1
	`
	org := &models.Organizer{}
	err := r.db.QueryRow(query, id).Scan(
		&org.ID, &org.UserID, &org.Name, &org.Description, &org.Website,
		&org.Phone, &org.LogoURL, &org.Status, &org.RejectionReason, &org.CreatedAt, &org.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return org, nil
}

// GetByUserID retrieves an organizer by user ID
func (r *Repository) GetByUserID(userID uuid.UUID) (*models.Organizer, error) {
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

// Update updates an organizer profile
func (r *Repository) Update(org *models.Organizer) error {
	query := `
		UPDATE organizers SET
			name = $2, description = $3, website = $4, phone = $5, logo_url = $6
		WHERE id = $1
	`
	_, err := r.db.Exec(query, org.ID, org.Name, org.Description, org.Website, org.Phone, org.LogoURL)
	return err
}

// UpdateStatus updates the status of an organizer
func (r *Repository) UpdateStatus(id uuid.UUID, status string, rejectionReason *string) error {
	query := `UPDATE organizers SET status = $2, rejection_reason = $3 WHERE id = $1`
	_, err := r.db.Exec(query, id, status, rejectionReason)
	return err
}

// ListPending retrieves pending organizers for admin review
func (r *Repository) ListPending() ([]models.Organizer, error) {
	query := `
		SELECT id, user_id, name, description, website, phone, logo_url, status, rejection_reason, created_at, updated_at
		FROM organizers
		WHERE status = 'pending'
		ORDER BY created_at ASC
	`
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var organizers []models.Organizer
	for rows.Next() {
		var org models.Organizer
		err := rows.Scan(
			&org.ID, &org.UserID, &org.Name, &org.Description, &org.Website,
			&org.Phone, &org.LogoURL, &org.Status, &org.RejectionReason, &org.CreatedAt, &org.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		organizers = append(organizers, org)
	}

	return organizers, nil
}

// ListAll retrieves all organizers
func (r *Repository) ListAll() ([]models.Organizer, error) {
	query := `
		SELECT id, user_id, name, description, website, phone, logo_url, status, rejection_reason, created_at, updated_at
		FROM organizers
		ORDER BY created_at DESC
	`
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var organizers []models.Organizer
	for rows.Next() {
		var org models.Organizer
		err := rows.Scan(
			&org.ID, &org.UserID, &org.Name, &org.Description, &org.Website,
			&org.Phone, &org.LogoURL, &org.Status, &org.RejectionReason, &org.CreatedAt, &org.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		organizers = append(organizers, org)
	}

	return organizers, nil
}
