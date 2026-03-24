package lesson

import (
	"database/sql"
	"time"

	"github.com/google/uuid"
)

// LessonRequest represents a student's request for a lesson from a sheikh
type LessonRequest struct {
	ID              uuid.UUID  `json:"id"`
	StudentID       uuid.UUID  `json:"student_id"`
	SheikhID        uuid.UUID  `json:"sheikh_id"`
	Message         string     `json:"message"`
	PreferredTime   *time.Time `json:"preferred_time,omitempty"`
	Status          string     `json:"status"`
	StudentName     string     `json:"student_name,omitempty"`
	SheikhName      string     `json:"sheikh_name,omitempty"`
	MeetingLink     *string    `json:"meeting_link,omitempty"`
	MeetingPlatform *string    `json:"meeting_platform,omitempty"`
	ScheduledTime   *time.Time `json:"scheduled_time,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

// Repository handles database operations for lesson requests
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new lesson repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// Create creates a new lesson request
func (r *Repository) Create(req *LessonRequest) error {
	_, err := r.db.Exec(`
		INSERT INTO lesson_requests (id, student_id, sheikh_id, message, preferred_time, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		req.ID, req.StudentID, req.SheikhID, req.Message, req.PreferredTime,
		req.Status, req.CreatedAt, req.UpdatedAt,
	)
	return err
}

// GetByID returns a lesson request by ID
func (r *Repository) GetByID(id uuid.UUID) (*LessonRequest, error) {
	var req LessonRequest
	err := r.db.QueryRow(`
		SELECT lr.id, lr.student_id, lr.sheikh_id, lr.message, lr.preferred_time,
		       lr.status, lr.created_at, lr.updated_at,
		       COALESCE(u.display_name, u.email) as student_name
		FROM lesson_requests lr
		JOIN users u ON u.id = lr.student_id
		WHERE lr.id = $1`, id,
	).Scan(&req.ID, &req.StudentID, &req.SheikhID, &req.Message, &req.PreferredTime,
		&req.Status, &req.CreatedAt, &req.UpdatedAt, &req.StudentName)
	if err != nil {
		return nil, err
	}
	return &req, nil
}

// ListBySheikhUserID returns lesson requests for a sheikh (by user_id)
func (r *Repository) ListBySheikhUserID(userID uuid.UUID) ([]LessonRequest, error) {
	rows, err := r.db.Query(`
		SELECT lr.id, lr.student_id, lr.sheikh_id, lr.message, lr.preferred_time,
		       lr.status, lr.created_at, lr.updated_at,
		       COALESCE(u.display_name, u.email) as student_name
		FROM lesson_requests lr
		JOIN users u ON u.id = lr.student_id
		JOIN sheikhs s ON s.id = lr.sheikh_id
		WHERE s.user_id = $1
		ORDER BY lr.created_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var reqs []LessonRequest
	for rows.Next() {
		var req LessonRequest
		if err := rows.Scan(&req.ID, &req.StudentID, &req.SheikhID, &req.Message,
			&req.PreferredTime, &req.Status, &req.CreatedAt, &req.UpdatedAt,
			&req.StudentName); err != nil {
			continue
		}
		reqs = append(reqs, req)
	}
	return reqs, nil
}

// ListByStudentID returns lesson requests sent by a student
func (r *Repository) ListByStudentID(studentID uuid.UUID) ([]LessonRequest, error) {
	rows, err := r.db.Query(`
		SELECT lr.id, lr.student_id, lr.sheikh_id, lr.message, lr.preferred_time,
		       lr.status, lr.created_at, lr.updated_at,
		       COALESCE(u.display_name, u.email) as sheikh_name
		FROM lesson_requests lr
		JOIN sheikhs s ON s.id = lr.sheikh_id
		JOIN users u ON u.id = s.user_id
		WHERE lr.student_id = $1
		ORDER BY lr.created_at DESC`, studentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var reqs []LessonRequest
	for rows.Next() {
		var req LessonRequest
		if err := rows.Scan(&req.ID, &req.StudentID, &req.SheikhID, &req.Message,
			&req.PreferredTime, &req.Status, &req.CreatedAt, &req.UpdatedAt,
			&req.SheikhName); err != nil {
			continue
		}
		reqs = append(reqs, req)
	}
	return reqs, nil
}

// UpdateStatus updates the status of a lesson request
func (r *Repository) UpdateStatus(id uuid.UUID, status string) error {
	_, err := r.db.Exec(
		`UPDATE lesson_requests SET status = $2, updated_at = NOW() WHERE id = $1`,
		id, status,
	)
	return err
}

// CountPending counts pending requests from a student to a specific sheikh
func (r *Repository) CountPending(studentID, sheikhID uuid.UUID) (int, error) {
	var count int
	err := r.db.QueryRow(
		`SELECT COUNT(*) FROM lesson_requests WHERE student_id = $1 AND sheikh_id = $2 AND status = 'pending'`,
		studentID, sheikhID,
	).Scan(&count)
	return count, err
}

// GetSheikhUserID returns the user_id for a sheikh
func (r *Repository) GetSheikhUserID(sheikhID uuid.UUID) (uuid.UUID, error) {
	var userID uuid.UUID
	err := r.db.QueryRow(`SELECT user_id FROM sheikhs WHERE id = $1`, sheikhID).Scan(&userID)
	return userID, err
}

// IsUserSheikh checks if a user is the owner of a given sheikh profile
func (r *Repository) IsUserSheikh(userID, sheikhID uuid.UUID) bool {
	var exists bool
	r.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM sheikhs WHERE id = $1 AND user_id = $2)`,
		sheikhID, userID).Scan(&exists)
	return exists
}

// Schedule updates a lesson request with meeting details
func (r *Repository) Schedule(id uuid.UUID, meetingLink, meetingPlatform string, scheduledTime time.Time) error {
	_, err := r.db.Exec(`
		UPDATE lesson_requests
		SET meeting_link = $2, meeting_platform = $3, scheduled_time = $4, updated_at = NOW()
		WHERE id = $1`,
		id, meetingLink, meetingPlatform, scheduledTime,
	)
	return err
}
