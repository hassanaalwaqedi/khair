package spiritualquote

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/google/uuid"
)

// Repository handles DB operations for spiritual quotes.
type Repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) GetRandomByLocation(ctx context.Context, location Location) (*Quote, error) {
	filterColumn, err := location.filterColumn()
	if err != nil {
		return nil, err
	}

	query := fmt.Sprintf(`
		SELECT
			id, type, text_ar, source, reference,
			is_active, show_on_dashboard, show_on_home, show_on_login, created_at
		FROM spiritual_quotes
		WHERE is_active = TRUE
		  AND %s = TRUE
		ORDER BY RANDOM()
		LIMIT 1
	`, filterColumn)

	var quote Quote
	if err := r.db.QueryRowContext(ctx, query).Scan(
		&quote.ID,
		&quote.Type,
		&quote.TextAR,
		&quote.Source,
		&quote.Reference,
		&quote.IsActive,
		&quote.ShowOnDashboard,
		&quote.ShowOnHome,
		&quote.ShowOnLogin,
		&quote.CreatedAt,
	); err != nil {
		return nil, err
	}

	return &quote, nil
}

// ListByLocation returns all active quotes for a given location.
func (r *Repository) ListByLocation(ctx context.Context, location Location) ([]Quote, error) {
	filterColumn, err := location.filterColumn()
	if err != nil {
		return nil, err
	}

	query := fmt.Sprintf(`
		SELECT id, type, text_ar, source, reference,
		       is_active, show_on_dashboard, show_on_home, show_on_login, created_at
		FROM spiritual_quotes
		WHERE is_active = TRUE AND %s = TRUE
		ORDER BY created_at DESC
	`, filterColumn)

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var quotes []Quote
	for rows.Next() {
		var q Quote
		if err := rows.Scan(
			&q.ID, &q.Type, &q.TextAR, &q.Source, &q.Reference,
			&q.IsActive, &q.ShowOnDashboard, &q.ShowOnHome, &q.ShowOnLogin, &q.CreatedAt,
		); err != nil {
			return nil, err
		}
		quotes = append(quotes, q)
	}
	if quotes == nil {
		quotes = []Quote{}
	}
	return quotes, nil
}

// ListAll returns all quotes (admin view).
func (r *Repository) ListAll(ctx context.Context) ([]Quote, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, type, text_ar, source, reference,
		       is_active, show_on_dashboard, show_on_home, show_on_login, created_at
		FROM spiritual_quotes
		ORDER BY created_at DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var quotes []Quote
	for rows.Next() {
		var q Quote
		if err := rows.Scan(
			&q.ID, &q.Type, &q.TextAR, &q.Source, &q.Reference,
			&q.IsActive, &q.ShowOnDashboard, &q.ShowOnHome, &q.ShowOnLogin, &q.CreatedAt,
		); err != nil {
			return nil, err
		}
		quotes = append(quotes, q)
	}
	if quotes == nil {
		quotes = []Quote{}
	}
	return quotes, nil
}

// Create inserts a new quote.
func (r *Repository) Create(ctx context.Context, q *Quote) error {
	q.ID = uuid.New()
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO spiritual_quotes (id, type, text_ar, source, reference, is_active, show_on_dashboard, show_on_home, show_on_login)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`, q.ID, q.Type, q.TextAR, q.Source, q.Reference, q.IsActive, q.ShowOnDashboard, q.ShowOnHome, q.ShowOnLogin)
	return err
}

// Update modifies an existing quote.
func (r *Repository) Update(ctx context.Context, q *Quote) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE spiritual_quotes
		SET type = $1, text_ar = $2, source = $3, reference = $4,
		    is_active = $5, show_on_dashboard = $6, show_on_home = $7, show_on_login = $8
		WHERE id = $9
	`, q.Type, q.TextAR, q.Source, q.Reference, q.IsActive, q.ShowOnDashboard, q.ShowOnHome, q.ShowOnLogin, q.ID)
	return err
}

// Delete removes a quote by ID.
func (r *Repository) Delete(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM spiritual_quotes WHERE id = $1`, id)
	return err
}
