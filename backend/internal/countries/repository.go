package countries

import (
	"database/sql"

	"github.com/khair/backend/internal/models"
)

// Repository handles country database operations
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new countries repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// ListActive returns all active countries ordered by name
func (r *Repository) ListActive() ([]models.Country, error) {
	rows, err := r.db.Query(`
		SELECT id, name, iso_code, iso3_code, phone_code, flag_emoji, region, is_active, created_at
		FROM countries
		WHERE is_active = true
		ORDER BY name ASC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var countries []models.Country
	for rows.Next() {
		var c models.Country
		if err := rows.Scan(&c.ID, &c.Name, &c.ISOCode, &c.ISO3Code, &c.PhoneCode,
			&c.FlagEmoji, &c.Region, &c.IsActive, &c.CreatedAt); err != nil {
			return nil, err
		}
		countries = append(countries, c)
	}
	return countries, rows.Err()
}

// Search returns countries matching a query string (name or ISO code)
func (r *Repository) Search(query string) ([]models.Country, error) {
	rows, err := r.db.Query(`
		SELECT id, name, iso_code, iso3_code, phone_code, flag_emoji, region, is_active, created_at
		FROM countries
		WHERE is_active = true
		  AND (LOWER(name) LIKE LOWER($1) OR LOWER(iso_code) = LOWER($2))
		ORDER BY
		  CASE WHEN LOWER(iso_code) = LOWER($2) THEN 0 ELSE 1 END,
		  name ASC
		LIMIT 20
	`, "%"+query+"%", query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var countries []models.Country
	for rows.Next() {
		var c models.Country
		if err := rows.Scan(&c.ID, &c.Name, &c.ISOCode, &c.ISO3Code, &c.PhoneCode,
			&c.FlagEmoji, &c.Region, &c.IsActive, &c.CreatedAt); err != nil {
			return nil, err
		}
		countries = append(countries, c)
	}
	return countries, rows.Err()
}

// GetByID returns a single country by ID
func (r *Repository) GetByID(id int) (*models.Country, error) {
	var c models.Country
	err := r.db.QueryRow(`
		SELECT id, name, iso_code, iso3_code, phone_code, flag_emoji, region, is_active, created_at
		FROM countries WHERE id = $1
	`, id).Scan(&c.ID, &c.Name, &c.ISOCode, &c.ISO3Code, &c.PhoneCode,
		&c.FlagEmoji, &c.Region, &c.IsActive, &c.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &c, nil
}
