package booking

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
)

const queryTimeout = 5 * time.Second

// ── Models ──

type AvailabilityRule struct {
	ID                  uuid.UUID `json:"id"`
	SheikhID            uuid.UUID `json:"sheikh_id"`
	DayOfWeek           int       `json:"day_of_week"` // 0=Sun..6=Sat
	StartTime           string    `json:"start_time"`   // "HH:MM"
	EndTime             string    `json:"end_time"`     // "HH:MM"
	SlotDurationMinutes int       `json:"slot_duration_minutes"`
	BreakMinutes        int       `json:"break_minutes"`
	IsActive            bool      `json:"is_active"`
	CreatedAt           time.Time `json:"created_at"`
}

type BookingSettings struct {
	SheikhID           uuid.UUID  `json:"sheikh_id"`
	Timezone           string     `json:"timezone"`
	AutoApprove        bool       `json:"auto_approve"`
	PrayerBlocking     bool       `json:"prayer_blocking"`
	DefaultMeetingLink *string    `json:"default_meeting_link"`
	DefaultPlatform    *string    `json:"default_platform"`
	Latitude           *float64   `json:"latitude"`
	Longitude          *float64   `json:"longitude"`
	UpdatedAt          time.Time  `json:"updated_at"`
}

type Booking struct {
	ID              uuid.UUID  `json:"id"`
	StudentID       uuid.UUID  `json:"student_id"`
	SheikhID        uuid.UUID  `json:"sheikh_id"`
	StartTime       time.Time  `json:"start_time"`
	EndTime         time.Time  `json:"end_time"`
	Status          string     `json:"status"`
	MeetingLink     *string    `json:"meeting_link"`
	MeetingPlatform *string    `json:"meeting_platform"`
	Notes           *string    `json:"notes"`
	StudentName     *string    `json:"student_name,omitempty"`
	SheikhName      *string    `json:"sheikh_name,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

type BlockedTime struct {
	ID        uuid.UUID `json:"id"`
	SheikhID  uuid.UUID `json:"sheikh_id"`
	StartTime time.Time `json:"start_time"`
	EndTime   time.Time `json:"end_time"`
	Reason    string    `json:"reason"`
	Note      *string   `json:"note"`
	CreatedAt time.Time `json:"created_at"`
}

// Repository handles database operations for the booking system.
type Repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// ── Availability Rules ──

func (r *Repository) UpsertAvailabilityRule(rule *AvailabilityRule) error {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	_, err := r.db.ExecContext(ctx, `
		INSERT INTO availability_rules (sheikh_id, day_of_week, start_time, end_time,
			slot_duration_minutes, break_minutes, is_active)
		VALUES ($1, $2, $3::time, $4::time, $5, $6, $7)
		ON CONFLICT (sheikh_id, day_of_week) DO UPDATE SET
			start_time = $3::time, end_time = $4::time,
			slot_duration_minutes = $5, break_minutes = $6, is_active = $7`,
		rule.SheikhID, rule.DayOfWeek, rule.StartTime, rule.EndTime,
		rule.SlotDurationMinutes, rule.BreakMinutes, rule.IsActive,
	)
	return err
}

func (r *Repository) GetAvailabilityRules(sheikhID uuid.UUID) ([]AvailabilityRule, error) {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	rows, err := r.db.QueryContext(ctx, `
		SELECT id, sheikh_id, day_of_week, start_time::text, end_time::text,
			slot_duration_minutes, break_minutes, is_active, created_at
		FROM availability_rules WHERE sheikh_id = $1 ORDER BY day_of_week`, sheikhID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var rules []AvailabilityRule
	for rows.Next() {
		var r AvailabilityRule
		if err := rows.Scan(&r.ID, &r.SheikhID, &r.DayOfWeek, &r.StartTime, &r.EndTime,
			&r.SlotDurationMinutes, &r.BreakMinutes, &r.IsActive, &r.CreatedAt); err != nil {
			return nil, err
		}
		rules = append(rules, r)
	}
	if rules == nil {
		rules = []AvailabilityRule{}
	}
	return rules, nil
}

func (r *Repository) DeleteAvailabilityRule(sheikhID uuid.UUID, dayOfWeek int) error {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()
	_, err := r.db.ExecContext(ctx, `DELETE FROM availability_rules WHERE sheikh_id = $1 AND day_of_week = $2`,
		sheikhID, dayOfWeek)
	return err
}

// ── Booking Settings ──

func (r *Repository) GetBookingSettings(sheikhID uuid.UUID) (*BookingSettings, error) {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	var s BookingSettings
	err := r.db.QueryRowContext(ctx, `
		SELECT sheikh_id, timezone, auto_approve, prayer_blocking, default_meeting_link,
			default_platform, latitude, longitude, updated_at
		FROM booking_settings WHERE sheikh_id = $1`, sheikhID).
		Scan(&s.SheikhID, &s.Timezone, &s.AutoApprove, &s.PrayerBlocking, &s.DefaultMeetingLink,
			&s.DefaultPlatform, &s.Latitude, &s.Longitude, &s.UpdatedAt)
	if err == sql.ErrNoRows {
		// Return defaults
		return &BookingSettings{
			SheikhID:       sheikhID,
			Timezone:       "UTC",
			PrayerBlocking: true,
		}, nil
	}
	return &s, err
}

func (r *Repository) UpsertBookingSettings(s *BookingSettings) error {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	_, err := r.db.ExecContext(ctx, `
		INSERT INTO booking_settings (sheikh_id, timezone, auto_approve, prayer_blocking,
			default_meeting_link, default_platform, latitude, longitude, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
		ON CONFLICT (sheikh_id) DO UPDATE SET
			timezone = $2, auto_approve = $3, prayer_blocking = $4,
			default_meeting_link = $5, default_platform = $6,
			latitude = $7, longitude = $8, updated_at = NOW()`,
		s.SheikhID, s.Timezone, s.AutoApprove, s.PrayerBlocking,
		s.DefaultMeetingLink, s.DefaultPlatform, s.Latitude, s.Longitude,
	)
	return err
}

// ── Bookings ──

func (r *Repository) CreateBookingTx(b *Booking) error {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Lock and check for conflicts
	var count int
	err = tx.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM bookings
		WHERE sheikh_id = $1
		  AND start_time = $2
		  AND status NOT IN ('cancelled', 'rejected')
		FOR UPDATE`, b.SheikhID, b.StartTime).Scan(&count)
	if err != nil {
		return err
	}
	if count > 0 {
		return fmt.Errorf("slot already booked")
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO bookings (id, student_id, sheikh_id, start_time, end_time, status,
			meeting_link, meeting_platform, notes)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
		b.ID, b.StudentID, b.SheikhID, b.StartTime, b.EndTime, b.Status,
		b.MeetingLink, b.MeetingPlatform, b.Notes,
	)
	if err != nil {
		return err
	}

	return tx.Commit()
}

func (r *Repository) GetBooking(id uuid.UUID) (*Booking, error) {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	var b Booking
	err := r.db.QueryRowContext(ctx, `
		SELECT b.id, b.student_id, b.sheikh_id, b.start_time, b.end_time, b.status,
			b.meeting_link, b.meeting_platform, b.notes, b.created_at, b.updated_at,
			u.name as student_name
		FROM bookings b
		JOIN users u ON u.id = b.student_id
		WHERE b.id = $1`, id).
		Scan(&b.ID, &b.StudentID, &b.SheikhID, &b.StartTime, &b.EndTime, &b.Status,
			&b.MeetingLink, &b.MeetingPlatform, &b.Notes, &b.CreatedAt, &b.UpdatedAt,
			&b.StudentName)
	return &b, err
}

func (r *Repository) UpdateBookingStatus(id uuid.UUID, status string) error {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()
	_, err := r.db.ExecContext(ctx,
		`UPDATE bookings SET status = $1, updated_at = NOW() WHERE id = $2`, status, id)
	return err
}

func (r *Repository) UpdateBookingLink(id uuid.UUID, link, platform string) error {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()
	_, err := r.db.ExecContext(ctx,
		`UPDATE bookings SET meeting_link = $1, meeting_platform = $2, updated_at = NOW() WHERE id = $3`,
		link, platform, id)
	return err
}

func (r *Repository) GetBookingsInRange(sheikhID uuid.UUID, start, end time.Time) ([]Booking, error) {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	rows, err := r.db.QueryContext(ctx, `
		SELECT id, student_id, sheikh_id, start_time, end_time, status,
			meeting_link, meeting_platform, notes, created_at, updated_at
		FROM bookings
		WHERE sheikh_id = $1
		  AND start_time >= $2
		  AND start_time < $3
		  AND status NOT IN ('cancelled', 'rejected')
		ORDER BY start_time`, sheikhID, start, end)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var bookings []Booking
	for rows.Next() {
		var b Booking
		if err := rows.Scan(&b.ID, &b.StudentID, &b.SheikhID, &b.StartTime, &b.EndTime,
			&b.Status, &b.MeetingLink, &b.MeetingPlatform, &b.Notes, &b.CreatedAt, &b.UpdatedAt); err != nil {
			return nil, err
		}
		bookings = append(bookings, b)
	}
	if bookings == nil {
		bookings = []Booking{}
	}
	return bookings, nil
}

func (r *Repository) ListStudentBookings(studentID uuid.UUID) ([]Booking, error) {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	rows, err := r.db.QueryContext(ctx, `
		SELECT b.id, b.student_id, b.sheikh_id, b.start_time, b.end_time, b.status,
			b.meeting_link, b.meeting_platform, b.notes, b.created_at, b.updated_at
		FROM bookings b
		WHERE b.student_id = $1
		ORDER BY b.start_time DESC LIMIT 50`, studentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var bookings []Booking
	for rows.Next() {
		var b Booking
		if err := rows.Scan(&b.ID, &b.StudentID, &b.SheikhID, &b.StartTime, &b.EndTime,
			&b.Status, &b.MeetingLink, &b.MeetingPlatform, &b.Notes, &b.CreatedAt, &b.UpdatedAt); err != nil {
			return nil, err
		}
		bookings = append(bookings, b)
	}
	if bookings == nil {
		bookings = []Booking{}
	}
	return bookings, nil
}

func (r *Repository) ListSheikhBookings(sheikhID uuid.UUID) ([]Booking, error) {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	rows, err := r.db.QueryContext(ctx, `
		SELECT b.id, b.student_id, b.sheikh_id, b.start_time, b.end_time, b.status,
			b.meeting_link, b.meeting_platform, b.notes, b.created_at, b.updated_at,
			u.name as student_name
		FROM bookings b
		JOIN users u ON u.id = b.student_id
		WHERE b.sheikh_id = $1
		ORDER BY b.start_time DESC LIMIT 50`, sheikhID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var bookings []Booking
	for rows.Next() {
		var b Booking
		if err := rows.Scan(&b.ID, &b.StudentID, &b.SheikhID, &b.StartTime, &b.EndTime,
			&b.Status, &b.MeetingLink, &b.MeetingPlatform, &b.Notes, &b.CreatedAt, &b.UpdatedAt,
			&b.StudentName); err != nil {
			return nil, err
		}
		bookings = append(bookings, b)
	}
	if bookings == nil {
		bookings = []Booking{}
	}
	return bookings, nil
}

// ── Blocked Times ──

func (r *Repository) CreateBlockedTime(bt *BlockedTime) error {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO blocked_times (sheikh_id, start_time, end_time, reason, note)
		VALUES ($1, $2, $3, $4, $5)`, bt.SheikhID, bt.StartTime, bt.EndTime, bt.Reason, bt.Note)
	return err
}

func (r *Repository) DeleteBlockedTime(id, sheikhID uuid.UUID) error {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()
	_, err := r.db.ExecContext(ctx,
		`DELETE FROM blocked_times WHERE id = $1 AND sheikh_id = $2`, id, sheikhID)
	return err
}

func (r *Repository) GetBlockedTimesInRange(sheikhID uuid.UUID, start, end time.Time) ([]BlockedTime, error) {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	rows, err := r.db.QueryContext(ctx, `
		SELECT id, sheikh_id, start_time, end_time, reason, note, created_at
		FROM blocked_times
		WHERE sheikh_id = $1
		  AND start_time < $2
		  AND end_time > $3
		ORDER BY start_time`, sheikhID, end, start)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var blocks []BlockedTime
	for rows.Next() {
		var bt BlockedTime
		if err := rows.Scan(&bt.ID, &bt.SheikhID, &bt.StartTime, &bt.EndTime,
			&bt.Reason, &bt.Note, &bt.CreatedAt); err != nil {
			return nil, err
		}
		blocks = append(blocks, bt)
	}
	if blocks == nil {
		blocks = []BlockedTime{}
	}
	return blocks, nil
}

func (r *Repository) ListSheikhBlockedTimes(sheikhID uuid.UUID) ([]BlockedTime, error) {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	rows, err := r.db.QueryContext(ctx, `
		SELECT id, sheikh_id, start_time, end_time, reason, note, created_at
		FROM blocked_times WHERE sheikh_id = $1 AND end_time > NOW()
		ORDER BY start_time`, sheikhID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var blocks []BlockedTime
	for rows.Next() {
		var bt BlockedTime
		if err := rows.Scan(&bt.ID, &bt.SheikhID, &bt.StartTime, &bt.EndTime,
			&bt.Reason, &bt.Note, &bt.CreatedAt); err != nil {
			return nil, err
		}
		blocks = append(blocks, bt)
	}
	if blocks == nil {
		blocks = []BlockedTime{}
	}
	return blocks, nil
}

// GetSheikhUserID returns the user_id for a sheikh.
func (r *Repository) GetSheikhUserID(sheikhID uuid.UUID) (uuid.UUID, error) {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	var userID uuid.UUID
	err := r.db.QueryRowContext(ctx,
		`SELECT user_id FROM sheikhs WHERE id = $1`, sheikhID).Scan(&userID)
	return userID, err
}

// GetSheikhIDByUserID returns the sheikh_id for a user_id.
func (r *Repository) GetSheikhIDByUserID(userID uuid.UUID) (uuid.UUID, error) {
	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	var sheikhID uuid.UUID
	err := r.db.QueryRowContext(ctx,
		`SELECT id FROM sheikhs WHERE user_id = $1`, userID).Scan(&sheikhID)
	return sheikhID, err
}
