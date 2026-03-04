package trust

import (
	"database/sql"
	"time"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
)

type Repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) GetOrCreate(userID, organizerID uuid.UUID) (*models.OrganizerTrustScoreV2, error) {
	var ts models.OrganizerTrustScoreV2

	query := `
		SELECT id, user_id, organizer_id, trust_score, violations_count,
			approved_events_count, rejected_events_count, high_risk_count,
			last_updated, created_at
		FROM organizer_trust_scores
		WHERE organizer_id = $1
	`
	err := r.db.QueryRow(query, organizerID).Scan(
		&ts.ID, &ts.UserID, &ts.OrganizerID, &ts.TrustScore, &ts.ViolationsCount,
		&ts.ApprovedEventsCount, &ts.RejectedEventsCount, &ts.HighRiskCount,
		&ts.LastUpdated, &ts.CreatedAt,
	)
	if err == sql.ErrNoRows {
		ts = models.OrganizerTrustScoreV2{
			ID:          uuid.New(),
			UserID:      userID,
			OrganizerID: organizerID,
			TrustScore:  75,
			LastUpdated: time.Now(),
			CreatedAt:   time.Now(),
		}
		insertQuery := `
			INSERT INTO organizer_trust_scores (id, user_id, organizer_id, trust_score, last_updated, created_at)
			VALUES ($1, $2, $3, $4, $5, $6)
			ON CONFLICT (organizer_id) DO NOTHING
		`
		_, err = r.db.Exec(insertQuery, ts.ID, ts.UserID, ts.OrganizerID, ts.TrustScore, ts.LastUpdated, ts.CreatedAt)
		if err != nil {
			return nil, err
		}
		return &ts, nil
	}
	if err != nil {
		return nil, err
	}
	return &ts, nil
}

func (r *Repository) GetByOrganizerID(organizerID uuid.UUID) (*models.OrganizerTrustScoreV2, error) {
	var ts models.OrganizerTrustScoreV2
	query := `
		SELECT id, user_id, organizer_id, trust_score, violations_count,
			approved_events_count, rejected_events_count, high_risk_count,
			last_updated, created_at
		FROM organizer_trust_scores
		WHERE organizer_id = $1
	`
	err := r.db.QueryRow(query, organizerID).Scan(
		&ts.ID, &ts.UserID, &ts.OrganizerID, &ts.TrustScore, &ts.ViolationsCount,
		&ts.ApprovedEventsCount, &ts.RejectedEventsCount, &ts.HighRiskCount,
		&ts.LastUpdated, &ts.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &ts, nil
}

func (r *Repository) Update(ts *models.OrganizerTrustScoreV2) error {
	ts.LastUpdated = time.Now()
	query := `
		UPDATE organizer_trust_scores
		SET trust_score = $2, violations_count = $3, approved_events_count = $4,
			rejected_events_count = $5, high_risk_count = $6, last_updated = $7
		WHERE id = $1
	`
	_, err := r.db.Exec(query,
		ts.ID, ts.TrustScore, ts.ViolationsCount, ts.ApprovedEventsCount,
		ts.RejectedEventsCount, ts.HighRiskCount, ts.LastUpdated,
	)
	return err
}

func (r *Repository) GetEventCountByOrganizer(organizerID uuid.UUID) (int, error) {
	var count int
	err := r.db.QueryRow(`SELECT COUNT(*) FROM events WHERE organizer_id = $1`, organizerID).Scan(&count)
	return count, err
}
