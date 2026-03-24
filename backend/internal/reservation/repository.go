package reservation

import (
	"database/sql"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/khair/backend/internal/models"
)

// Repository handles database operations for event seat reservations
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new reservation repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// ReserveSeat atomically reserves a seat using SELECT FOR UPDATE
func (r *Repository) ReserveSeat(userID, eventID uuid.UUID, holdMinutes int) (*models.EventRegistration, error) {
	tx, err := r.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	// First, expire any stale pending reservations for this event
	tx.Exec(`
		UPDATE event_registrations SET status = 'expired', updated_at = NOW()
		WHERE event_id = $1 AND status = 'pending' AND reserved_until < NOW()`, eventID)

	// Recalculate reserved_count based on active reservations
	tx.Exec(`
		UPDATE events SET reserved_count = (
			SELECT COUNT(*) FROM event_registrations
			WHERE event_id = $1 AND status IN ('pending', 'confirmed')
			AND (reserved_until IS NULL OR reserved_until > NOW() OR status = 'confirmed')
		), updated_at = NOW()
		WHERE id = $1`, eventID)

	// Lock the event row and check capacity, status, and dates
	var capacity sql.NullInt64
	var reservedCount int
	var status string
	var startDate time.Time
	var endDate sql.NullTime
	err = tx.QueryRow(`
		SELECT capacity, reserved_count, status, start_date, end_date FROM events WHERE id = $1 FOR UPDATE`,
		eventID,
	).Scan(&capacity, &reservedCount, &status, &startDate, &endDate)
	if err != nil {
		return nil, errors.New("event not found")
	}

	// Check event status — only approved events can be joined
	if status != "approved" {
		return nil, errors.New("this event is not accepting registrations")
	}

	// Check if event has already ended
	now := time.Now()
	if endDate.Valid {
		if endDate.Time.Before(now) {
			return nil, errors.New("this event has already ended")
		}
	} else if startDate.Before(now) {
		return nil, errors.New("this event has already ended")
	}

	// Check capacity
	if capacity.Valid && reservedCount >= int(capacity.Int64) {
		return nil, errors.New("this event is fully booked")
	}

	// Check for existing registration by this user
	var existingStatus string
	err = tx.QueryRow(`
		SELECT status FROM event_registrations WHERE user_id = $1 AND event_id = $2`,
		userID, eventID,
	).Scan(&existingStatus)
	if err == nil {
		switch existingStatus {
		case "confirmed":
			return nil, errors.New("you are already registered for this event")
		case "pending":
			return nil, errors.New("you already have a pending reservation for this event")
		case "expired", "cancelled":
			// Allow re-registration: update existing record
			reservedUntil := time.Now().Add(time.Duration(holdMinutes) * time.Minute)
			reg := &models.EventRegistration{
				UserID:        userID,
				EventID:       eventID,
				Status:        "pending",
				ReservedUntil: &reservedUntil,
			}
			_, err = tx.Exec(`
				UPDATE event_registrations SET status = 'pending', reserved_until = $1, updated_at = NOW()
				WHERE user_id = $2 AND event_id = $3`,
				reservedUntil, userID, eventID)
			if err != nil {
				return nil, errors.New("failed to reserve seat")
			}
			tx.Exec(`UPDATE events SET reserved_count = reserved_count + 1, updated_at = NOW() WHERE id = $1`, eventID)
			if err := tx.Commit(); err != nil {
				return nil, err
			}
			err = r.db.QueryRow(`SELECT id, created_at, updated_at FROM event_registrations WHERE user_id = $1 AND event_id = $2`,
				userID, eventID).Scan(&reg.ID, &reg.CreatedAt, &reg.UpdatedAt)
			return reg, nil
		}
	}

	// Create new reservation
	reservedUntil := time.Now().Add(time.Duration(holdMinutes) * time.Minute)
	reg := &models.EventRegistration{
		ID:            uuid.New(),
		UserID:        userID,
		EventID:       eventID,
		Status:        "pending",
		ReservedUntil: &reservedUntil,
		CreatedAt:     time.Now(),
		UpdatedAt:     time.Now(),
	}

	_, err = tx.Exec(`
		INSERT INTO event_registrations (id, user_id, event_id, status, reserved_until, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		reg.ID, reg.UserID, reg.EventID, reg.Status, reg.ReservedUntil, reg.CreatedAt, reg.UpdatedAt,
	)
	if err != nil {
		return nil, errors.New("failed to reserve seat")
	}

	// Increment reserved_count
	_, err = tx.Exec(`UPDATE events SET reserved_count = reserved_count + 1, updated_at = NOW() WHERE id = $1`, eventID)
	if err != nil {
		return nil, errors.New("failed to update seat count")
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return reg, nil
}

// CancelReservation cancels a user's reservation
func (r *Repository) CancelReservation(userID, eventID uuid.UUID) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var status string
	err = tx.QueryRow(`
		SELECT status FROM event_registrations WHERE user_id = $1 AND event_id = $2 FOR UPDATE`,
		userID, eventID,
	).Scan(&status)
	if err != nil {
		return errors.New("reservation not found")
	}
	if status == "cancelled" || status == "expired" {
		return errors.New("reservation is already cancelled or expired")
	}

	_, err = tx.Exec(`
		UPDATE event_registrations SET status = 'cancelled', updated_at = NOW()
		WHERE user_id = $1 AND event_id = $2`,
		userID, eventID)
	if err != nil {
		return errors.New("failed to cancel reservation")
	}

	tx.Exec(`UPDATE events SET reserved_count = GREATEST(reserved_count - 1, 0), updated_at = NOW() WHERE id = $1`, eventID)

	return tx.Commit()
}

// GetUserReservations gets all reservations for a user
func (r *Repository) GetUserReservations(userID uuid.UUID) ([]EventReservationWithDetails, error) {
	rows, err := r.db.Query(`
		SELECT er.id, er.user_id, er.event_id, er.status, er.reserved_until, er.created_at,
			e.title, e.start_date, e.city, e.image_url
		FROM event_registrations er
		JOIN events e ON e.id = er.event_id
		WHERE er.user_id = $1
		ORDER BY er.created_at DESC`,
		userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []EventReservationWithDetails
	for rows.Next() {
		var r EventReservationWithDetails
		err := rows.Scan(&r.ID, &r.UserID, &r.EventID, &r.Status, &r.ReservedUntil, &r.CreatedAt,
			&r.EventTitle, &r.EventStartDate, &r.EventCity, &r.EventImageURL)
		if err != nil {
			continue
		}
		results = append(results, r)
	}
	return results, nil
}

// GetEventAvailability checks remaining seats
func (r *Repository) GetEventAvailability(eventID uuid.UUID) (*EventAvailability, error) {
	// First expire stale reservations
	r.db.Exec(`
		UPDATE event_registrations SET status = 'expired', updated_at = NOW()
		WHERE event_id = $1 AND status = 'pending' AND reserved_until < NOW()`, eventID)

	// Recalculate reserved_count after expiring stale reservations
	r.db.Exec(`
		UPDATE events SET reserved_count = (
			SELECT COUNT(*) FROM event_registrations
			WHERE event_id = $1 AND status IN ('pending', 'confirmed')
			AND (reserved_until IS NULL OR reserved_until > NOW() OR status = 'confirmed')
		), updated_at = NOW()
		WHERE id = $1`, eventID)

	var capacity sql.NullInt64
	var reservedCount int
	var title string
	err := r.db.QueryRow(`
		SELECT title, capacity, reserved_count FROM events WHERE id = $1 AND status = 'approved'`,
		eventID,
	).Scan(&title, &capacity, &reservedCount)
	if err != nil {
		return nil, errors.New("event not found")
	}

	avail := &EventAvailability{
		EventID:       eventID.String(),
		EventTitle:    title,
		ReservedCount: reservedCount,
		Available:     true,
	}

	if capacity.Valid {
		cap := int(capacity.Int64)
		avail.Capacity = &cap
		remaining := cap - reservedCount
		if remaining < 0 {
			remaining = 0
		}
		avail.Remaining = &remaining
		avail.Available = remaining > 0
	}

	return avail, nil
}

// EventReservationWithDetails includes event info alongside the reservation
type EventReservationWithDetails struct {
	ID             uuid.UUID  `json:"id"`
	UserID         uuid.UUID  `json:"user_id"`
	EventID        uuid.UUID  `json:"event_id"`
	Status         string     `json:"status"`
	ReservedUntil  *time.Time `json:"reserved_until,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
	EventTitle     string     `json:"event_title"`
	EventStartDate time.Time  `json:"event_start_date"`
	EventCity      *string    `json:"event_city,omitempty"`
	EventImageURL  *string    `json:"event_image_url,omitempty"`
}

// EventAvailability represents seat availability info
type EventAvailability struct {
	EventID       string `json:"event_id"`
	EventTitle    string `json:"event_title"`
	Capacity      *int   `json:"capacity,omitempty"`
	ReservedCount int    `json:"reserved_count"`
	Remaining     *int   `json:"remaining,omitempty"`
	Available     bool   `json:"available"`
}

// GetEventAttendeeUserIDs returns user IDs of all confirmed attendees for an event
func (r *Repository) GetEventAttendeeUserIDs(eventID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := r.db.Query(
		`SELECT user_id FROM event_registrations WHERE event_id = $1 AND status = 'confirmed'`,
		eventID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var userIDs []uuid.UUID
	for rows.Next() {
		var uid uuid.UUID
		if err := rows.Scan(&uid); err != nil {
			return nil, err
		}
		userIDs = append(userIDs, uid)
	}
	return userIDs, nil
}
