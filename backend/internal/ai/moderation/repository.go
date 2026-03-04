package moderation

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

func (r *Repository) Create(scan *models.ModerationScan) error {
	flagsJSON, err := json.Marshal(scan.DetectedFlags)
	if err != nil {
		return err
	}
	complianceJSON, err := json.Marshal(scan.ComplianceFlags)
	if err != nil {
		return err
	}

	query := `
		INSERT INTO moderation_scans (id, event_id, scanned_text, ai_risk_score, ai_decision,
			detected_flags, compliance_flags, scanned_at, provider)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`

	scan.ID = uuid.New()
	scan.ScannedAt = time.Now()
	scan.CreatedAt = time.Now()

	_, err = r.db.Exec(query,
		scan.ID, scan.EventID, scan.ScannedText, scan.AIRiskScore, scan.AIDecision,
		flagsJSON, complianceJSON, scan.ScannedAt, scan.Provider,
	)
	return err
}

func (r *Repository) GetByEventID(eventID uuid.UUID) ([]models.ModerationScan, error) {
	query := `
		SELECT id, event_id, scanned_text, ai_risk_score, ai_decision,
			detected_flags, compliance_flags, scanned_at, provider, created_at
		FROM moderation_scans
		WHERE event_id = $1
		ORDER BY scanned_at DESC
	`
	rows, err := r.db.Query(query, eventID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var scans []models.ModerationScan
	for rows.Next() {
		var scan models.ModerationScan
		var flagsJSON, complianceJSON []byte
		err := rows.Scan(
			&scan.ID, &scan.EventID, &scan.ScannedText, &scan.AIRiskScore, &scan.AIDecision,
			&flagsJSON, &complianceJSON, &scan.ScannedAt, &scan.Provider, &scan.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		if flagsJSON != nil {
			json.Unmarshal(flagsJSON, &scan.DetectedFlags)
		}
		if complianceJSON != nil {
			scan.ComplianceFlags = &models.ComplianceFlags{}
			json.Unmarshal(complianceJSON, scan.ComplianceFlags)
		}
		scans = append(scans, scan)
	}
	return scans, nil
}

func (r *Repository) GetLatestByEventID(eventID uuid.UUID) (*models.ModerationScan, error) {
	query := `
		SELECT id, event_id, scanned_text, ai_risk_score, ai_decision,
			detected_flags, compliance_flags, scanned_at, provider, created_at
		FROM moderation_scans
		WHERE event_id = $1
		ORDER BY scanned_at DESC
		LIMIT 1
	`
	var scan models.ModerationScan
	var flagsJSON, complianceJSON []byte
	err := r.db.QueryRow(query, eventID).Scan(
		&scan.ID, &scan.EventID, &scan.ScannedText, &scan.AIRiskScore, &scan.AIDecision,
		&flagsJSON, &complianceJSON, &scan.ScannedAt, &scan.Provider, &scan.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	if flagsJSON != nil {
		json.Unmarshal(flagsJSON, &scan.DetectedFlags)
	}
	if complianceJSON != nil {
		scan.ComplianceFlags = &models.ComplianceFlags{}
		json.Unmarshal(complianceJSON, scan.ComplianceFlags)
	}
	return &scan, nil
}

func (r *Repository) ListByDecision(decision models.AIDecision, limit, offset int) ([]models.ModerationScan, int64, error) {
	countQuery := `SELECT COUNT(*) FROM moderation_scans WHERE ai_decision = $1`
	var total int64
	if err := r.db.QueryRow(countQuery, decision).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := `
		SELECT id, event_id, scanned_text, ai_risk_score, ai_decision,
			detected_flags, compliance_flags, scanned_at, provider, created_at
		FROM moderation_scans
		WHERE ai_decision = $1
		ORDER BY ai_risk_score DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.db.Query(query, decision, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var scans []models.ModerationScan
	for rows.Next() {
		var scan models.ModerationScan
		var flagsJSON, complianceJSON []byte
		err := rows.Scan(
			&scan.ID, &scan.EventID, &scan.ScannedText, &scan.AIRiskScore, &scan.AIDecision,
			&flagsJSON, &complianceJSON, &scan.ScannedAt, &scan.Provider, &scan.CreatedAt,
		)
		if err != nil {
			return nil, 0, err
		}
		if flagsJSON != nil {
			json.Unmarshal(flagsJSON, &scan.DetectedFlags)
		}
		if complianceJSON != nil {
			scan.ComplianceFlags = &models.ComplianceFlags{}
			json.Unmarshal(complianceJSON, scan.ComplianceFlags)
		}
		scans = append(scans, scan)
	}
	return scans, total, nil
}

func (r *Repository) GetModerationQueue(limit, offset int) ([]models.ModerationQueueItem, int64, error) {
	countQuery := `
		SELECT COUNT(*)
		FROM events e
		WHERE e.status IN ('pending', 'under_review')
	`
	var total int64
	if err := r.db.QueryRow(countQuery).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := `
		SELECT e.id, e.title, e.organizer_id, o.name,
			e.status, e.ai_risk_score, e.ai_decision,
			ts.trust_score, e.compliance_flags, ts.violations_count,
			e.created_at
		FROM events e
		JOIN organizers o ON e.organizer_id = o.id
		LEFT JOIN organizer_trust_scores ts ON ts.organizer_id = e.organizer_id
		WHERE e.status IN ('pending', 'under_review')
		ORDER BY
			CASE WHEN e.ai_decision = 'high_risk' THEN 0
				WHEN e.ai_decision = 'review_required' THEN 1
				ELSE 2 END,
			COALESCE(e.ai_risk_score, 0) DESC,
			e.created_at ASC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.db.Query(query, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var items []models.ModerationQueueItem
	for rows.Next() {
		var item models.ModerationQueueItem
		var complianceJSON []byte
		err := rows.Scan(
			&item.EventID, &item.Title, &item.OrganizerID, &item.OrganizerName,
			&item.Status, &item.AIRiskScore, &item.AIDecision,
			&item.TrustScore, &complianceJSON, &item.ViolationsCount,
			&item.CreatedAt,
		)
		if err != nil {
			return nil, 0, err
		}
		if complianceJSON != nil {
			item.ComplianceFlags = &models.ComplianceFlags{}
			json.Unmarshal(complianceJSON, item.ComplianceFlags)
		}
		items = append(items, item)
	}
	return items, total, nil
}

func (r *Repository) GetHighRiskEvents(limit, offset int) ([]models.ModerationQueueItem, int64, error) {
	countQuery := `
		SELECT COUNT(*)
		FROM events e
		WHERE e.ai_decision = 'high_risk' OR e.ai_risk_score > 70
	`
	var total int64
	if err := r.db.QueryRow(countQuery).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := `
		SELECT e.id, e.title, e.organizer_id, o.name,
			e.status, e.ai_risk_score, e.ai_decision,
			ts.trust_score, e.compliance_flags, ts.violations_count,
			e.created_at
		FROM events e
		JOIN organizers o ON e.organizer_id = o.id
		LEFT JOIN organizer_trust_scores ts ON ts.organizer_id = e.organizer_id
		WHERE e.ai_decision = 'high_risk' OR e.ai_risk_score > 70
		ORDER BY COALESCE(e.ai_risk_score, 0) DESC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.db.Query(query, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var items []models.ModerationQueueItem
	for rows.Next() {
		var item models.ModerationQueueItem
		var complianceJSON []byte
		err := rows.Scan(
			&item.EventID, &item.Title, &item.OrganizerID, &item.OrganizerName,
			&item.Status, &item.AIRiskScore, &item.AIDecision,
			&item.TrustScore, &complianceJSON, &item.ViolationsCount,
			&item.CreatedAt,
		)
		if err != nil {
			return nil, 0, err
		}
		if complianceJSON != nil {
			item.ComplianceFlags = &models.ComplianceFlags{}
			json.Unmarshal(complianceJSON, item.ComplianceFlags)
		}
		items = append(items, item)
	}
	return items, total, nil
}

func (r *Repository) GetOrganizerRiskRanking(limit, offset int) ([]models.OrganizerRiskRanking, int64, error) {
	countQuery := `SELECT COUNT(*) FROM organizer_trust_scores`
	var total int64
	if err := r.db.QueryRow(countQuery).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := `
		SELECT ts.user_id, ts.organizer_id, o.name,
			ts.trust_score, ts.violations_count, ts.rejected_events_count,
			ts.high_risk_count,
			(SELECT COUNT(*) FROM events e WHERE e.organizer_id = ts.organizer_id) as total_events
		FROM organizer_trust_scores ts
		JOIN organizers o ON ts.organizer_id = o.id
		ORDER BY ts.trust_score ASC, ts.violations_count DESC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.db.Query(query, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var rankings []models.OrganizerRiskRanking
	for rows.Next() {
		var rank models.OrganizerRiskRanking
		err := rows.Scan(
			&rank.UserID, &rank.OrganizerID, &rank.OrganizerName,
			&rank.TrustScore, &rank.ViolationsCount, &rank.RejectedEventsCount,
			&rank.HighRiskCount, &rank.TotalEvents,
		)
		if err != nil {
			return nil, 0, err
		}
		rankings = append(rankings, rank)
	}
	return rankings, total, nil
}

func (r *Repository) UpdateEventAIData(eventID uuid.UUID, riskScore float64, decision string, complianceFlags *models.ComplianceFlags) error {
	complianceJSON, err := json.Marshal(complianceFlags)
	if err != nil {
		return err
	}
	query := `
		UPDATE events
		SET ai_risk_score = $2, ai_decision = $3, compliance_flags = $4
		WHERE id = $1
	`
	_, err = r.db.Exec(query, eventID, riskScore, decision, complianceJSON)
	return err
}
