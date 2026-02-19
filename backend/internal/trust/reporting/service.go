package reporting

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"

	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/internal/trust/audit"
)

// Service provides report handling functionality
type Service struct {
	db    *sqlx.DB
	audit *audit.Service
}

// NewService creates a new reporting service
func NewService(db *sqlx.DB, auditService *audit.Service) *Service {
	return &Service{
		db:    db,
		audit: auditService,
	}
}

// CreateReport creates a new report
func (s *Service) CreateReport(ctx context.Context, req models.CreateReportRequest, reporterType models.ReporterType, reporterID *uuid.UUID, reporterIP string) (*models.Report, error) {
	report := &models.Report{
		TargetType:     req.TargetType,
		TargetID:       req.TargetID,
		ReporterType:   reporterType,
		ReporterID:     reporterID,
		ReporterIP:     &reporterIP,
		ReasonCategory: req.ReasonCategory,
		Description:    req.Description,
		Status:         models.ReportStatusPending,
	}

	query := `
		INSERT INTO reports (
			target_type, target_id, reporter_type, reporter_id, reporter_ip,
			reason_category, description, status
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, created_at`

	err := s.db.QueryRowContext(ctx, query,
		report.TargetType,
		report.TargetID,
		report.ReporterType,
		report.ReporterID,
		report.ReporterIP,
		report.ReasonCategory,
		report.Description,
		report.Status,
	).Scan(&report.ID, &report.CreatedAt)

	return report, err
}

// CreateSystemReport creates a report from the system
func (s *Service) CreateSystemReport(ctx context.Context, targetType models.ReportTargetType, targetID uuid.UUID, reason models.ReasonCategory, description string) (*models.Report, error) {
	req := models.CreateReportRequest{
		TargetType:     targetType,
		TargetID:       targetID,
		ReasonCategory: reason,
		Description:    &description,
	}
	return s.CreateReport(ctx, req, models.ReporterSystem, nil, "system")
}

// GetReport retrieves a report by ID
func (s *Service) GetReport(ctx context.Context, id uuid.UUID) (*models.Report, error) {
	query := `
		SELECT id, target_type, target_id, reporter_type, reporter_id, reporter_ip,
			reason_category, description, status, resolution_action, resolution_notes,
			resolved_by, resolved_at, created_at
		FROM reports
		WHERE id = $1`

	var report models.Report
	err := s.db.GetContext(ctx, &report, query, id)
	if err != nil {
		return nil, err
	}
	return &report, nil
}

// ListPendingReports retrieves pending reports
func (s *Service) ListPendingReports(ctx context.Context, limit, offset int) ([]models.Report, int, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	// Get total count
	var total int
	err := s.db.GetContext(ctx, &total, `SELECT COUNT(*) FROM reports WHERE status = 'pending'`)
	if err != nil {
		return nil, 0, err
	}

	query := `
		SELECT id, target_type, target_id, reporter_type, reporter_id, reporter_ip,
			reason_category, description, status, resolution_action, resolution_notes,
			resolved_by, resolved_at, created_at
		FROM reports
		WHERE status = 'pending'
		ORDER BY created_at ASC
		LIMIT $1 OFFSET $2`

	var reports []models.Report
	err = s.db.SelectContext(ctx, &reports, query, limit, offset)
	return reports, total, err
}

// ListReports retrieves reports with optional filters
func (s *Service) ListReports(ctx context.Context, status *models.ReportStatus, targetType *models.ReportTargetType, limit, offset int) ([]models.Report, int, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	baseWhere := `WHERE 1=1`
	args := []interface{}{}
	argIndex := 1

	if status != nil {
		baseWhere += ` AND status = $` + string(rune('0'+argIndex))
		args = append(args, *status)
		argIndex++
	}
	if targetType != nil {
		baseWhere += ` AND target_type = $` + string(rune('0'+argIndex))
		args = append(args, *targetType)
		argIndex++
	}

	// Get total count
	var total int
	countQuery := `SELECT COUNT(*) FROM reports ` + baseWhere
	err := s.db.GetContext(ctx, &total, countQuery, args...)
	if err != nil {
		return nil, 0, err
	}

	selectQuery := `
		SELECT id, target_type, target_id, reporter_type, reporter_id, reporter_ip,
			reason_category, description, status, resolution_action, resolution_notes,
			resolved_by, resolved_at, created_at
		FROM reports ` + baseWhere + `
		ORDER BY created_at DESC
		LIMIT $` + string(rune('0'+argIndex)) + ` OFFSET $` + string(rune('0'+argIndex+1))
	args = append(args, limit, offset)

	var reports []models.Report
	err = s.db.SelectContext(ctx, &reports, selectQuery, args...)
	return reports, total, err
}

// GetReportsForTarget retrieves all reports for a specific target
func (s *Service) GetReportsForTarget(ctx context.Context, targetType models.ReportTargetType, targetID uuid.UUID) ([]models.Report, error) {
	query := `
		SELECT id, target_type, target_id, reporter_type, reporter_id, reporter_ip,
			reason_category, description, status, resolution_action, resolution_notes,
			resolved_by, resolved_at, created_at
		FROM reports
		WHERE target_type = $1 AND target_id = $2
		ORDER BY created_at DESC`

	var reports []models.Report
	err := s.db.SelectContext(ctx, &reports, query, targetType, targetID)
	return reports, err
}

// ResolveReport resolves a report with an action
func (s *Service) ResolveReport(ctx context.Context, reportID uuid.UUID, resolvedBy uuid.UUID, action string, notes *string) error {
	now := time.Now()
	query := `
		UPDATE reports
		SET status = 'resolved', resolution_action = $1, resolution_notes = $2,
			resolved_by = $3, resolved_at = $4
		WHERE id = $5`

	_, err := s.db.ExecContext(ctx, query, action, notes, resolvedBy, now, reportID)
	if err != nil {
		return err
	}

	// Log the action
	report, _ := s.GetReport(ctx, reportID)
	if report != nil {
		s.audit.LogAdminAction(ctx, resolvedBy, models.AuditActionReportResolved,
			"report", reportID, "Resolved with action: "+action,
			map[string]string{"status": string(models.ReportStatusPending)},
			map[string]string{"status": string(models.ReportStatusResolved), "action": action},
			"", "")
	}

	return nil
}

// DismissReport dismisses a report
func (s *Service) DismissReport(ctx context.Context, reportID uuid.UUID, dismissedBy uuid.UUID, notes *string) error {
	now := time.Now()
	query := `
		UPDATE reports
		SET status = 'dismissed', resolution_notes = $1, resolved_by = $2, resolved_at = $3
		WHERE id = $4`

	_, err := s.db.ExecContext(ctx, query, notes, dismissedBy, now, reportID)
	if err != nil {
		return err
	}

	// Log the action
	s.audit.LogAdminAction(ctx, dismissedBy, models.AuditActionReportDismissed,
		"report", reportID, "Report dismissed",
		nil, nil, "", "")

	return nil
}

// GetReportCount returns the count of reports for a target
func (s *Service) GetReportCount(ctx context.Context, targetType models.ReportTargetType, targetID uuid.UUID) (int, error) {
	var count int
	err := s.db.GetContext(ctx, &count,
		`SELECT COUNT(*) FROM reports WHERE target_type = $1 AND target_id = $2`,
		targetType, targetID)
	return count, err
}
