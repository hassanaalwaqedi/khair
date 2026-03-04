package attendee

import (
	"bytes"
	"database/sql"
	"encoding/csv"
	"fmt"
	"strconv"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
)

// Repository handles database operations for attendee management
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new attendee repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// ListByEvent retrieves paginated attendees for an event with search/filter
func (r *Repository) ListByEvent(eventID uuid.UUID, search *string, status *string, page, pageSize int) ([]models.AttendeeInfo, int64, error) {
	args := []interface{}{eventID}
	where := "WHERE er.event_id = $1"
	argN := 2

	if status != nil && *status != "" {
		where += fmt.Sprintf(" AND er.status = $%d", argN)
		args = append(args, *status)
		argN++
	}

	if search != nil && *search != "" {
		where += fmt.Sprintf(" AND (u.email ILIKE $%d OR u.display_name ILIKE $%d)", argN, argN+1)
		args = append(args, "%"+*search+"%", "%"+*search+"%")
		argN += 2
	}

	// Count
	var count int64
	countQ := fmt.Sprintf(`
		SELECT COUNT(*)
		FROM event_registrations er
		JOIN users u ON u.id = er.user_id
		%s
	`, where)
	if err := r.db.QueryRow(countQ, args...).Scan(&count); err != nil {
		return nil, 0, fmt.Errorf("failed to count attendees: %w", err)
	}

	// List
	query := fmt.Sprintf(`
		SELECT er.id, er.user_id, u.email, u.display_name, u.gender, u.age,
			er.status, er.attended, er.reserved_until, er.created_at
		FROM event_registrations er
		JOIN users u ON u.id = er.user_id
		%s
		ORDER BY er.created_at DESC
		LIMIT $%d OFFSET $%d
	`, where, argN, argN+1)
	args = append(args, pageSize, (page-1)*pageSize)

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to list attendees: %w", err)
	}
	defer rows.Close()

	var attendees []models.AttendeeInfo
	for rows.Next() {
		var a models.AttendeeInfo
		if err := rows.Scan(
			&a.RegistrationID, &a.UserID, &a.Email, &a.DisplayName, &a.Gender, &a.Age,
			&a.Status, &a.Attended, &a.ReservedUntil, &a.RegisteredAt,
		); err != nil {
			return nil, 0, err
		}
		attendees = append(attendees, a)
	}
	return attendees, count, rows.Err()
}

// MarkAttendance toggles attendance for a registration
func (r *Repository) MarkAttendance(regID uuid.UUID, attended bool) error {
	result, err := r.db.Exec(`
		UPDATE event_registrations SET attended = $2 WHERE id = $1
	`, regID, attended)
	if err != nil {
		return fmt.Errorf("failed to mark attendance: %w", err)
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("registration not found")
	}
	return nil
}

// RemoveAttendee cancels a registration
func (r *Repository) RemoveAttendee(regID uuid.UUID) error {
	// Cancel and decrement reserved_count atomically
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var eventID uuid.UUID
	var status string
	err = tx.QueryRow(
		`SELECT event_id, status FROM event_registrations WHERE id = $1`, regID,
	).Scan(&eventID, &status)
	if err != nil {
		return fmt.Errorf("registration not found: %w", err)
	}

	if status == "cancelled" {
		return fmt.Errorf("registration already cancelled")
	}

	_, err = tx.Exec(`UPDATE event_registrations SET status = 'cancelled' WHERE id = $1`, regID)
	if err != nil {
		return err
	}

	if status == "confirmed" || status == "pending" {
		_, err = tx.Exec(`UPDATE events SET reserved_count = GREATEST(reserved_count - 1, 0) WHERE id = $1`, eventID)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

// GetRegistrationEventID returns the event_id for a registration (for authorization check)
func (r *Repository) GetRegistrationEventID(regID uuid.UUID) (uuid.UUID, error) {
	var eventID uuid.UUID
	err := r.db.QueryRow(`SELECT event_id FROM event_registrations WHERE id = $1`, regID).Scan(&eventID)
	return eventID, err
}

// GetEventOrgID returns the organizer_id for an event (for authorization check)
func (r *Repository) GetEventOrgID(eventID uuid.UUID) (uuid.UUID, error) {
	var orgID uuid.UUID
	err := r.db.QueryRow(`SELECT organizer_id FROM events WHERE id = $1`, eventID).Scan(&orgID)
	return orgID, err
}

// ExportCSV generates CSV data for all attendees of an event
func (r *Repository) ExportCSV(eventID uuid.UUID) ([]byte, error) {
	rows, err := r.db.Query(`
		SELECT u.email, COALESCE(u.display_name, ''), COALESCE(u.gender, ''),
			COALESCE(u.age::text, ''), er.status,
			CASE WHEN er.attended THEN 'Yes' ELSE 'No' END,
			er.created_at::text
		FROM event_registrations er
		JOIN users u ON u.id = er.user_id
		WHERE er.event_id = $1
		ORDER BY er.created_at ASC
	`, eventID)
	if err != nil {
		return nil, fmt.Errorf("failed to export attendees: %w", err)
	}
	defer rows.Close()

	var buf bytes.Buffer
	writer := csv.NewWriter(&buf)

	// Header
	_ = writer.Write([]string{"Email", "Name", "Gender", "Age", "Status", "Attended", "Registered At"})

	for rows.Next() {
		var email, name, gender, age, status, attended, registeredAt string
		if err := rows.Scan(&email, &name, &gender, &age, &status, &attended, &registeredAt); err != nil {
			return nil, err
		}
		_ = writer.Write([]string{email, name, gender, age, status, attended, registeredAt})
	}

	writer.Flush()
	return buf.Bytes(), rows.Err()
}

// Unused import guard
var _ = strconv.Itoa
