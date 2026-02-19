package audit

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"

	"github.com/khair/backend/internal/models"
)

// Service provides audit logging functionality
type Service struct {
	db *sqlx.DB
}

// NewService creates a new audit service
func NewService(db *sqlx.DB) *Service {
	return &Service{db: db}
}

// Log creates an immutable audit log entry
func (s *Service) Log(ctx context.Context, entry *models.AuditLog) error {
	query := `
		INSERT INTO audit_logs (
			actor_type, actor_id, action, target_type, target_id,
			old_value, new_value, reason, ip_address, user_agent
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING id, created_at`

	return s.db.QueryRowContext(ctx, query,
		entry.ActorType,
		entry.ActorID,
		entry.Action,
		entry.TargetType,
		entry.TargetID,
		entry.OldValue,
		entry.NewValue,
		entry.Reason,
		entry.IPAddress,
		entry.UserAgent,
	).Scan(&entry.ID, &entry.CreatedAt)
}

// LogAdminAction logs an action performed by an admin
func (s *Service) LogAdminAction(ctx context.Context, adminID uuid.UUID, action models.AuditAction, targetType string, targetID uuid.UUID, reason string, oldValue, newValue interface{}, ipAddress, userAgent string) error {
	var oldJSON, newJSON *string

	if oldValue != nil {
		data, _ := json.Marshal(oldValue)
		str := string(data)
		oldJSON = &str
	}
	if newValue != nil {
		data, _ := json.Marshal(newValue)
		str := string(data)
		newJSON = &str
	}

	entry := &models.AuditLog{
		ActorType:  models.ActorAdmin,
		ActorID:    &adminID,
		Action:     action,
		TargetType: targetType,
		TargetID:   targetID,
		OldValue:   oldJSON,
		NewValue:   newJSON,
		Reason:     &reason,
		IPAddress:  &ipAddress,
		UserAgent:  &userAgent,
	}

	return s.Log(ctx, entry)
}

// LogSystemAction logs an automated system action
func (s *Service) LogSystemAction(ctx context.Context, action models.AuditAction, targetType string, targetID uuid.UUID, reason string, oldValue, newValue interface{}) error {
	var oldJSON, newJSON *string

	if oldValue != nil {
		data, _ := json.Marshal(oldValue)
		str := string(data)
		oldJSON = &str
	}
	if newValue != nil {
		data, _ := json.Marshal(newValue)
		str := string(data)
		newJSON = &str
	}

	entry := &models.AuditLog{
		ActorType:  models.ActorSystem,
		ActorID:    nil,
		Action:     action,
		TargetType: targetType,
		TargetID:   targetID,
		OldValue:   oldJSON,
		NewValue:   newJSON,
		Reason:     &reason,
	}

	return s.Log(ctx, entry)
}

// Query retrieves audit logs based on filters
func (s *Service) Query(ctx context.Context, query models.AuditLogQuery) ([]models.AuditLog, int, error) {
	// Set defaults
	if query.Limit <= 0 || query.Limit > 100 {
		query.Limit = 50
	}

	baseQuery := `FROM audit_logs WHERE 1=1`
	args := []interface{}{}
	argIndex := 1

	if query.ActorType != nil {
		baseQuery += ` AND actor_type = $` + string(rune('0'+argIndex))
		args = append(args, *query.ActorType)
		argIndex++
	}
	if query.ActorID != nil {
		baseQuery += ` AND actor_id = $` + string(rune('0'+argIndex))
		args = append(args, *query.ActorID)
		argIndex++
	}
	if query.Action != nil {
		baseQuery += ` AND action = $` + string(rune('0'+argIndex))
		args = append(args, *query.Action)
		argIndex++
	}
	if query.TargetType != nil {
		baseQuery += ` AND target_type = $` + string(rune('0'+argIndex))
		args = append(args, *query.TargetType)
		argIndex++
	}
	if query.TargetID != nil {
		baseQuery += ` AND target_id = $` + string(rune('0'+argIndex))
		args = append(args, *query.TargetID)
		argIndex++
	}
	if query.StartDate != nil {
		baseQuery += ` AND created_at >= $` + string(rune('0'+argIndex))
		args = append(args, *query.StartDate)
		argIndex++
	}
	if query.EndDate != nil {
		baseQuery += ` AND created_at <= $` + string(rune('0'+argIndex))
		args = append(args, *query.EndDate)
		argIndex++
	}

	// Get total count
	var total int
	countQuery := `SELECT COUNT(*) ` + baseQuery
	err := s.db.GetContext(ctx, &total, countQuery, args...)
	if err != nil {
		return nil, 0, err
	}

	// Get logs with pagination
	selectQuery := `SELECT id, actor_type, actor_id, action, target_type, target_id, 
		old_value, new_value, reason, ip_address, user_agent, created_at ` + baseQuery +
		` ORDER BY created_at DESC LIMIT $` + string(rune('0'+argIndex)) +
		` OFFSET $` + string(rune('0'+argIndex+1))
	args = append(args, query.Limit, query.Offset)

	var logs []models.AuditLog
	err = s.db.SelectContext(ctx, &logs, selectQuery, args...)
	if err != nil {
		return nil, 0, err
	}

	return logs, total, nil
}

// GetByTarget retrieves all audit logs for a specific target
func (s *Service) GetByTarget(ctx context.Context, targetType string, targetID uuid.UUID) ([]models.AuditLog, error) {
	query := `
		SELECT id, actor_type, actor_id, action, target_type, target_id,
			old_value, new_value, reason, ip_address, user_agent, created_at
		FROM audit_logs
		WHERE target_type = $1 AND target_id = $2
		ORDER BY created_at DESC`

	var logs []models.AuditLog
	err := s.db.SelectContext(ctx, &logs, query, targetType, targetID)
	return logs, err
}

// GetRecent retrieves recent audit logs
func (s *Service) GetRecent(ctx context.Context, since time.Duration, limit int) ([]models.AuditLog, error) {
	query := `
		SELECT id, actor_type, actor_id, action, target_type, target_id,
			old_value, new_value, reason, ip_address, user_agent, created_at
		FROM audit_logs
		WHERE created_at >= $1
		ORDER BY created_at DESC
		LIMIT $2`

	var logs []models.AuditLog
	err := s.db.SelectContext(ctx, &logs, query, time.Now().Add(-since), limit)
	return logs, err
}
