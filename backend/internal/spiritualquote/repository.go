package spiritualquote

import (
	"context"
	"database/sql"
	"fmt"
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
			id,
			type,
			text_ar,
			source,
			reference,
			is_active,
			show_on_dashboard,
			show_on_home,
			show_on_login,
			created_at
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
