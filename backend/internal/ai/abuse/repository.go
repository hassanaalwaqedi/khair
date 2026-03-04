package abuse

import (
	"database/sql"
	"encoding/json"
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

func (r *Repository) Create(log *models.AbuseLog) error {
	log.ID = uuid.New()
	log.CreatedAt = time.Now()

	detailsJSON, err := json.Marshal(log.Details)
	if err != nil {
		detailsJSON = []byte("{}")
	}

	query := `
		INSERT INTO abuse_logs (id, user_id, action_type, risk_score, details, ip_address, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err = r.db.Exec(query, log.ID, log.UserID, log.ActionType, log.RiskScore, detailsJSON, log.IPAddress, log.CreatedAt)
	return err
}

func (r *Repository) CountByUserSince(userID uuid.UUID, since time.Time) (int, error) {
	var count int
	err := r.db.QueryRow(
		`SELECT COUNT(*) FROM abuse_logs WHERE user_id = $1 AND created_at >= $2`,
		userID, since,
	).Scan(&count)
	return count, err
}

func (r *Repository) CountHighRiskByUserSince(userID uuid.UUID, since time.Time, minRisk float64) (int, error) {
	var count int
	err := r.db.QueryRow(
		`SELECT COUNT(*) FROM abuse_logs WHERE user_id = $1 AND created_at >= $2 AND risk_score >= $3`,
		userID, since, minRisk,
	).Scan(&count)
	return count, err
}

func (r *Repository) CountEventsByUserToday(userID uuid.UUID) (int, error) {
	var count int
	today := time.Now().Truncate(24 * time.Hour)
	err := r.db.QueryRow(
		`SELECT COUNT(*) FROM events e
		 JOIN organizers o ON e.organizer_id = o.id
		 WHERE o.user_id = $1 AND e.created_at >= $2`,
		userID, today,
	).Scan(&count)
	return count, err
}
