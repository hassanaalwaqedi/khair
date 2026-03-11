package sheikh

import (
	"database/sql"
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"
)

// SheikhProfile represents a public-facing sheikh profile
type SheikhProfile struct {
	ID                 uuid.UUID      `json:"id"`
	UserID             uuid.UUID      `json:"user_id"`
	DisplayName        *string        `json:"display_name,omitempty"`
	Email              string         `json:"email"`
	AvatarURL          *string        `json:"avatar_url,omitempty"`
	Bio                *string        `json:"bio,omitempty"`
	City               *string        `json:"city,omitempty"`
	Country            *string        `json:"country,omitempty"`
	Specialization     *string        `json:"specialization,omitempty"`
	IjazahInfo         *string        `json:"ijazah_info,omitempty"`
	Certifications     pq.StringArray `json:"certifications"`
	YearsOfExperience  *int           `json:"years_of_experience,omitempty"`
	VerificationStatus string         `json:"verification_status"`
	CreatedAt          time.Time      `json:"created_at"`
}

// Repository handles database operations for sheikh listings
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new sheikh repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// ListPublicSheikhs returns all active sheikhs with their profile info
func (r *Repository) ListPublicSheikhs() ([]SheikhProfile, error) {
	rows, err := r.db.Query(`
		SELECT s.id, s.user_id, u.display_name, u.email,
			   p.avatar_url, p.bio, p.city, p.country,
			   s.specialization, s.ijazah_info, s.certifications,
			   s.years_of_experience, s.verification_status, s.created_at
		FROM sheikhs s
		JOIN users u ON u.id = s.user_id
		LEFT JOIN profiles p ON p.user_id = s.user_id
		WHERE u.status = 'active'
		ORDER BY
			CASE WHEN s.verification_status = 'verified' THEN 0 ELSE 1 END,
			s.created_at DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sheikhs []SheikhProfile
	for rows.Next() {
		var s SheikhProfile
		err := rows.Scan(
			&s.ID, &s.UserID, &s.DisplayName, &s.Email,
			&s.AvatarURL, &s.Bio, &s.City, &s.Country,
			&s.Specialization, &s.IjazahInfo, &s.Certifications,
			&s.YearsOfExperience, &s.VerificationStatus, &s.CreatedAt,
		)
		if err != nil {
			continue
		}
		sheikhs = append(sheikhs, s)
	}
	return sheikhs, nil
}
