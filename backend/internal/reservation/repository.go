package reservation

import (
	"database/sql"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/eligibility"
	"github.com/khair/backend/internal/models"
)

// Repository handles database operations for event seat reservations
type Repository struct {
	db *sql.DB
}

func externalRegistrationStatus(registrationType string) string {
	if registrationType == "external" || registrationType == "both" {
		return "pending_external_registration"
	}
	return "not_required"
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
	var registrationDeadline sql.NullTime
	var registrationType sql.NullString
	var attendancePolicy string
	var userGender sql.NullString
	err = tx.QueryRow(`
		SELECT e.capacity, e.reserved_count, e.status, e.start_date, e.end_date,
		       e.registration_deadline, e.registration_type,
		       COALESCE(NULLIF(e.attendance_policy, ''), NULLIF(e.gender_restriction, ''), 'EVERYONE'),
		       u.gender
		FROM events e
		JOIN users u ON u.id = $2
		WHERE e.id = $1
		FOR UPDATE OF e`,
		eventID, userID,
	).Scan(&capacity, &reservedCount, &status, &startDate, &endDate,
		&registrationDeadline, &registrationType, &attendancePolicy, &userGender)
	if err != nil {
		return nil, errors.New("event not found")
	}

	// Check event status — only approved events can be joined
	if status != "approved" {
		return nil, errors.New("this event is not accepting registrations")
	}

	// Eligibility is evaluated from the locked event row and the authenticated
	// user's persisted profile. No client-supplied gender is accepted here.
	if eligibilityErr := eligibility.Evaluate(attendancePolicy, userGender.String); eligibilityErr != nil {
		// The reservation transaction must not be kept open while recording the
		// aggregate audit event. The audit entry deliberately omits gender.
		_ = tx.Rollback()
		r.recordEligibilityRejection(userID, eventID, eligibilityErr)
		return nil, eligibilityErr
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

	// Enforce the organizer's registration deadline in the transaction. The
	// frontend state is only a presentation hint; this check is authoritative.
	if registrationDeadline.Valid && !now.Before(registrationDeadline.Time) {
		return nil, errors.New("registration for this event is closed")
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
			externalStatus := externalRegistrationStatus(registrationType.String)
			reg := &models.EventRegistration{
				UserID:                     userID,
				EventID:                    eventID,
				Status:                     "confirmed",
				ReservedUntil:              &reservedUntil,
				ExternalRegistrationStatus: externalStatus,
			}
			_, err = tx.Exec(`
				UPDATE event_registrations SET status = 'confirmed', reserved_until = $1,
					external_registration_status = $4,
					external_registration_reminder_dismissed_at = NULL,
				external_registration_link_opened_at = NULL,
				external_registration_self_reported_completed_at = NULL,
				updated_at = NOW()
				WHERE user_id = $2 AND event_id = $3`,
				reservedUntil, userID, eventID, externalStatus)
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
		ID:                         uuid.New(),
		UserID:                     userID,
		EventID:                    eventID,
		Status:                     "confirmed",
		ReservedUntil:              &reservedUntil,
		ExternalRegistrationStatus: externalRegistrationStatus(registrationType.String),
		CreatedAt:                  time.Now(),
		UpdatedAt:                  time.Now(),
	}

	_, err = tx.Exec(`
		INSERT INTO event_registrations (id, user_id, event_id, status, reserved_until, external_registration_status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		reg.ID, reg.UserID, reg.EventID, reg.Status, reg.ReservedUntil, reg.ExternalRegistrationStatus, reg.CreatedAt, reg.UpdatedAt,
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

func (r *Repository) recordEligibilityRejection(userID, eventID uuid.UUID, eligibilityErr error) {
	code := "event_eligibility_rejected"
	if typed, ok := eligibilityErr.(*eligibility.Error); ok && typed.Code == eligibility.CodeProfileEligibilityRequired {
		code = "event_eligibility_profile_required"
	}
	_, _ = r.db.Exec(`
		INSERT INTO audit_logs (id, actor_type, actor_id, action, target_type, target_id, reason)
		VALUES ($1, 'system', $2, $3, 'event', $4, $5)
	`, uuid.New(), userID, code, eventID, "Attendance eligibility evaluation")
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
			er.external_registration_status, er.external_registration_reminder_dismissed_at,
			er.external_registration_link_opened_at, er.external_registration_self_reported_completed_at,
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

	results := make([]EventReservationWithDetails, 0)
	for rows.Next() {
		var r EventReservationWithDetails
		err := rows.Scan(&r.ID, &r.UserID, &r.EventID, &r.Status, &r.ReservedUntil, &r.CreatedAt,
			&r.ExternalRegistrationStatus, &r.ExternalRegistrationReminderDismissedAt,
			&r.ExternalRegistrationLinkOpenedAt, &r.ExternalRegistrationSelfReportedCompletedAt,
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
	ID                                          uuid.UUID  `json:"id"`
	UserID                                      uuid.UUID  `json:"user_id"`
	EventID                                     uuid.UUID  `json:"event_id"`
	Status                                      string     `json:"status"`
	ReservedUntil                               *time.Time `json:"reserved_until,omitempty"`
	CreatedAt                                   time.Time  `json:"created_at"`
	ExternalRegistrationStatus                  string     `json:"external_registration_status"`
	ExternalRegistrationReminderDismissedAt     *time.Time `json:"external_registration_reminder_dismissed_at,omitempty"`
	ExternalRegistrationLinkOpenedAt            *time.Time `json:"external_registration_link_opened_at,omitempty"`
	ExternalRegistrationSelfReportedCompletedAt *time.Time `json:"external_registration_self_reported_completed_at,omitempty"`
	EventTitle                                  string     `json:"event_title"`
	EventStartDate                              time.Time  `json:"event_start_date"`
	EventCity                                   *string    `json:"event_city,omitempty"`
	EventImageURL                               *string    `json:"event_image_url,omitempty"`
}

// ExternalRegistrationProgress is the server-authoritative handoff state for
// an attendee's third-party registration. The external URL itself is never
// stored in this record.
type ExternalRegistrationProgress struct {
	Status                  string     `json:"external_registration_status"`
	ReminderDismissedAt     *time.Time `json:"external_registration_reminder_dismissed_at,omitempty"`
	LinkOpenedAt            *time.Time `json:"external_registration_link_opened_at,omitempty"`
	SelfReportedCompletedAt *time.Time `json:"external_registration_self_reported_completed_at,omitempty"`
}

func (r *Repository) GetExternalRegistrationProgress(userID, eventID uuid.UUID) (ExternalRegistrationProgress, error) {
	var progress ExternalRegistrationProgress
	err := r.db.QueryRow(`
		SELECT COALESCE(er.external_registration_status,
			CASE WHEN e.registration_type IN ('external', 'both')
				THEN 'pending_external_registration' ELSE 'not_required' END),
			er.external_registration_reminder_dismissed_at,
			er.external_registration_link_opened_at,
			er.external_registration_self_reported_completed_at
		FROM event_registrations er JOIN events e ON e.id = er.event_id
		WHERE er.user_id = $1 AND er.event_id = $2`, userID, eventID).Scan(
		&progress.Status, &progress.ReminderDismissedAt, &progress.LinkOpenedAt,
		&progress.SelfReportedCompletedAt)
	return progress, err
}

func (r *Repository) UpdateExternalRegistrationProgress(userID, eventID uuid.UUID, status string, dismissed bool) (ExternalRegistrationProgress, error) {
	if status != "pending_external_registration" && status != "external_link_opened" && status != "self_reported_completed" {
		return ExternalRegistrationProgress{}, errors.New("invalid external registration status")
	}
	var progress ExternalRegistrationProgress
	err := r.db.QueryRow(`
		UPDATE event_registrations er
		SET external_registration_status = $3,
			external_registration_reminder_dismissed_at = CASE WHEN $4 THEN COALESCE(er.external_registration_reminder_dismissed_at, NOW()) ELSE er.external_registration_reminder_dismissed_at END,
			external_registration_link_opened_at = CASE WHEN $3 = 'external_link_opened' AND er.external_registration_link_opened_at IS NULL THEN NOW() ELSE er.external_registration_link_opened_at END,
			external_registration_self_reported_completed_at = CASE WHEN $3 = 'self_reported_completed' AND er.external_registration_self_reported_completed_at IS NULL THEN NOW() ELSE er.external_registration_self_reported_completed_at END,
			updated_at = NOW()
		FROM events e
		WHERE er.event_id = e.id AND e.registration_type IN ('external', 'both')
		  AND er.user_id = $1 AND er.event_id = $2
		RETURNING er.external_registration_status, er.external_registration_reminder_dismissed_at,
			er.external_registration_link_opened_at, er.external_registration_self_reported_completed_at`,
		userID, eventID, status, dismissed).Scan(&progress.Status, &progress.ReminderDismissedAt,
		&progress.LinkOpenedAt, &progress.SelfReportedCompletedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return progress, errors.New("registration not found")
		}
		return progress, err
	}
	_, _ = r.db.Exec(`
		INSERT INTO audit_logs (id, actor_type, actor_id, action, target_type, target_id, reason)
		VALUES ($1, 'user', $2, 'external_registration_status_changed', 'event', $3, $4)
	`, uuid.New(), userID, eventID, status)
	return progress, nil
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

// StoreAnnouncement persists organizer communication before it is delivered.
func (r *Repository) StoreAnnouncement(eventID, organizerUserID uuid.UUID, title, announcementType, message string, includeLink bool) (uuid.UUID, error) {
	var id uuid.UUID
	err := r.db.QueryRow(`
		INSERT INTO event_announcements (event_id, organizer_user_id, title, announcement_type, message, include_link)
		VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
		eventID, organizerUserID, title, announcementType, message, includeLink,
	).Scan(&id)
	return id, err
}

func (r *Repository) QueueAnnouncementDelivery(announcementID, userID uuid.UUID) error {
	_, err := r.db.Exec(`INSERT INTO event_announcement_deliveries (announcement_id, user_id)
		VALUES ($1, $2) ON CONFLICT (announcement_id, user_id) DO NOTHING`, announcementID, userID)
	return err
}

// "dispatched" means the message was handed to the push service; it is not a
// fabricated device receipt.
func (r *Repository) UpdateAnnouncementDelivery(announcementID, userID uuid.UUID, inAppStatus, pushStatus string) error {
	_, err := r.db.Exec(`UPDATE event_announcement_deliveries
		SET in_app_status=$3, push_status=$4,
			delivered_at=CASE WHEN $3='delivered' THEN NOW() ELSE delivered_at END,
			updated_at=NOW()
		WHERE announcement_id=$1 AND user_id=$2`, announcementID, userID, inAppStatus, pushStatus)
	return err
}
