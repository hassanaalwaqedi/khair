package event

import (
	"database/sql"
	"strconv"
	"time"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
)

// Repository handles database operations for events
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new event repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// EventFilter represents filters for listing events
type EventFilter struct {
	Country     *string
	City        *string
	EventType   *string
	Language    *string
	StartDate   *time.Time
	EndDate     *time.Time
	Status      *string
	IsPublished *bool
	Search      *string
	Trending    bool
	Page        int
	PageSize    int
}

// ── Column lists used across queries ──

const eventCols = `e.id, e.organizer_id, e.title, e.description, e.event_type, e.language,
       e.country, e.city, e.address, e.latitude, e.longitude, e.start_date, e.end_date,
       e.image_url, e.capacity, e.reserved_count, e.gender_restriction, e.age_min, e.age_max,
       e.ticket_price, e.currency,
       e.status, e.is_published, e.is_online, e.online_link, e.join_instructions,
       e.join_link_visible_before_minutes, e.rejection_reason, e.approved_at,
       e.created_at, e.updated_at`

const eventWithOrgCols = eventCols + `, o.name as organizer_name`

const bareEventCols = `id, organizer_id, title, description, event_type, language,
       country, city, address, latitude, longitude, start_date, end_date,
       image_url, capacity, reserved_count, gender_restriction, age_min, age_max,
       ticket_price, currency,
       status, is_published, is_online, online_link, join_instructions,
       join_link_visible_before_minutes, rejection_reason, approved_at,
       created_at, updated_at`

// scanEvent scans a row into an Event struct
func scanEvent(scanner interface{ Scan(dest ...interface{}) error }, event *models.Event) error {
	return scanner.Scan(
		&event.ID, &event.OrganizerID, &event.Title, &event.Description, &event.EventType,
		&event.Language, &event.Country, &event.City, &event.Address, &event.Latitude,
		&event.Longitude, &event.StartDate, &event.EndDate, &event.ImageURL,
		&event.Capacity, &event.ReservedCount, &event.GenderRestriction, &event.AgeMin, &event.AgeMax,
		&event.TicketPrice, &event.Currency,
		&event.Status, &event.IsPublished, &event.IsOnline, &event.OnlineLink, &event.JoinInstructions,
		&event.JoinLinkVisibleBeforeMinutes, &event.RejectionReason, &event.ApprovedAt,
		&event.CreatedAt, &event.UpdatedAt,
	)
}

// scanEventWithOrg scans a row into an EventWithOrganizer struct
func scanEventWithOrg(scanner interface{ Scan(dest ...interface{}) error }, event *models.EventWithOrganizer) error {
	return scanner.Scan(
		&event.ID, &event.OrganizerID, &event.Title, &event.Description, &event.EventType,
		&event.Language, &event.Country, &event.City, &event.Address, &event.Latitude,
		&event.Longitude, &event.StartDate, &event.EndDate, &event.ImageURL,
		&event.Capacity, &event.ReservedCount, &event.GenderRestriction, &event.AgeMin, &event.AgeMax,
		&event.TicketPrice, &event.Currency,
		&event.Status, &event.IsPublished, &event.IsOnline, &event.OnlineLink, &event.JoinInstructions,
		&event.JoinLinkVisibleBeforeMinutes, &event.RejectionReason, &event.ApprovedAt,
		&event.CreatedAt, &event.UpdatedAt, &event.OrganizerName,
	)
}

// Create creates a new event
func (r *Repository) Create(event *models.Event) error {
	query := `
		INSERT INTO events (id, organizer_id, title, description, event_type, language, 
		                    country, city, address, latitude, longitude, start_date, end_date, 
		                    image_url, ticket_price, currency, is_online, online_link, join_instructions,
		                    join_link_visible_before_minutes, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23)
	`
	_, err := r.db.Exec(query,
		event.ID, event.OrganizerID, event.Title, event.Description, event.EventType,
		event.Language, event.Country, event.City, event.Address, event.Latitude,
		event.Longitude, event.StartDate, event.EndDate, event.ImageURL,
		event.TicketPrice, event.Currency,
		event.IsOnline, event.OnlineLink, event.JoinInstructions,
		event.JoinLinkVisibleBeforeMinutes, event.Status,
		event.CreatedAt, event.UpdatedAt,
	)
	return err
}

// GetByID retrieves an event by ID
func (r *Repository) GetByID(id uuid.UUID) (*models.EventWithOrganizer, error) {
	query := `SELECT ` + eventWithOrgCols + `
		FROM events e
		JOIN organizers o ON e.organizer_id = o.id
		WHERE e.id = $1`

	event := &models.EventWithOrganizer{}
	if err := scanEventWithOrg(r.db.QueryRow(query, id), event); err != nil {
		return nil, err
	}
	return event, nil
}

// List retrieves events with filters
func (r *Repository) List(filter *EventFilter) ([]models.EventWithOrganizer, int64, error) {
	query := `SELECT ` + eventWithOrgCols + `
		FROM events e
		JOIN organizers o ON e.organizer_id = o.id
		WHERE 1=1`
	countQuery := `SELECT COUNT(*) FROM events e WHERE 1=1`

	var args []interface{}
	var countArgs []interface{}
	argIndex := 1

	// Add filters
	if filter.Status != nil {
		query += ` AND e.status = $` + strconv.Itoa(argIndex)
		countQuery += ` AND e.status = $` + strconv.Itoa(argIndex)
		args = append(args, *filter.Status)
		countArgs = append(countArgs, *filter.Status)
		argIndex++
	}

	if filter.IsPublished != nil {
		query += ` AND e.is_published = $` + strconv.Itoa(argIndex)
		countQuery += ` AND e.is_published = $` + strconv.Itoa(argIndex)
		args = append(args, *filter.IsPublished)
		countArgs = append(countArgs, *filter.IsPublished)
		argIndex++
	}

	if filter.Country != nil {
		query += ` AND e.country ILIKE $` + strconv.Itoa(argIndex)
		countQuery += ` AND e.country ILIKE $` + strconv.Itoa(argIndex)
		args = append(args, "%"+*filter.Country+"%")
		countArgs = append(countArgs, "%"+*filter.Country+"%")
		argIndex++
	}

	if filter.City != nil {
		query += ` AND e.city ILIKE $` + strconv.Itoa(argIndex)
		countQuery += ` AND e.city ILIKE $` + strconv.Itoa(argIndex)
		args = append(args, "%"+*filter.City+"%")
		countArgs = append(countArgs, "%"+*filter.City+"%")
		argIndex++
	}

	if filter.EventType != nil {
		query += ` AND e.event_type = $` + strconv.Itoa(argIndex)
		countQuery += ` AND e.event_type = $` + strconv.Itoa(argIndex)
		args = append(args, *filter.EventType)
		countArgs = append(countArgs, *filter.EventType)
		argIndex++
	}

	if filter.Language != nil {
		query += ` AND e.language = $` + strconv.Itoa(argIndex)
		countQuery += ` AND e.language = $` + strconv.Itoa(argIndex)
		args = append(args, *filter.Language)
		countArgs = append(countArgs, *filter.Language)
		argIndex++
	}

	if filter.StartDate != nil {
		clause := ` AND COALESCE(e.end_date, e.start_date) >= $` + strconv.Itoa(argIndex)
		query += clause
		countQuery += clause
		args = append(args, *filter.StartDate)
		countArgs = append(countArgs, *filter.StartDate)
		argIndex++
	}

	if filter.EndDate != nil {
		query += ` AND e.start_date <= $` + strconv.Itoa(argIndex)
		countQuery += ` AND e.start_date <= $` + strconv.Itoa(argIndex)
		args = append(args, *filter.EndDate)
		countArgs = append(countArgs, *filter.EndDate)
		argIndex++
	}

	if filter.Search != nil && *filter.Search != "" {
		searchClause := ` AND search_vector @@ plainto_tsquery('simple', $` + strconv.Itoa(argIndex) + `)`
		query += searchClause
		countQuery += searchClause
		args = append(args, *filter.Search)
		countArgs = append(countArgs, *filter.Search)
		argIndex++
	}

	// Get total count
	var totalCount int64
	err := r.db.QueryRow(countQuery, countArgs...).Scan(&totalCount)
	if err != nil {
		return nil, 0, err
	}

	// Add sorting
	if filter.Trending {
		query += ` ORDER BY e.created_at DESC`
	} else {
		query += ` ORDER BY e.start_date ASC`
	}
	offset := (filter.Page - 1) * filter.PageSize
	query += ` LIMIT $` + strconv.Itoa(argIndex) + ` OFFSET $` + strconv.Itoa(argIndex+1)
	args = append(args, filter.PageSize, offset)

	// Execute query
	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var events []models.EventWithOrganizer
	for rows.Next() {
		var event models.EventWithOrganizer
		if err := scanEventWithOrg(rows, &event); err != nil {
			return nil, 0, err
		}
		events = append(events, event)
	}

	return events, totalCount, nil
}

// Update updates an event
func (r *Repository) Update(event *models.Event) error {
	query := `
		UPDATE events SET
			title = $2, description = $3, event_type = $4, language = $5,
			country = $6, city = $7, address = $8, latitude = $9, longitude = $10,
			start_date = $11, end_date = $12, image_url = $13, status = $14,
			ticket_price = $15, currency = $16,
			is_online = $17, online_link = $18, join_instructions = $19,
			join_link_visible_before_minutes = $20
		WHERE id = $1
	`
	_, err := r.db.Exec(query,
		event.ID, event.Title, event.Description, event.EventType, event.Language,
		event.Country, event.City, event.Address, event.Latitude, event.Longitude,
		event.StartDate, event.EndDate, event.ImageURL, event.Status,
		event.TicketPrice, event.Currency,
		event.IsOnline, event.OnlineLink, event.JoinInstructions,
		event.JoinLinkVisibleBeforeMinutes,
	)
	return err
}

// Delete deletes an event
func (r *Repository) Delete(id uuid.UUID) error {
	query := `DELETE FROM events WHERE id = $1`
	_, err := r.db.Exec(query, id)
	return err
}

// ListByOrganizerID retrieves events by organizer ID
func (r *Repository) ListByOrganizerID(organizerID uuid.UUID) ([]models.Event, error) {
	query := `SELECT ` + bareEventCols + `
		FROM events
		WHERE organizer_id = $1
		ORDER BY created_at DESC`

	rows, err := r.db.Query(query, organizerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var events []models.Event
	for rows.Next() {
		var event models.Event
		if err := scanEvent(rows, &event); err != nil {
			return nil, err
		}
		events = append(events, event)
	}

	return events, nil
}

// UpdateStatus updates the status of an event
func (r *Repository) UpdateStatus(id uuid.UUID, status string, rejectionReason *string) error {
	if status == "approved" || status == "published" {
		query := `UPDATE events SET status = $2, rejection_reason = $3, is_published = true, approved_at = NOW() WHERE id = $1`
		_, err := r.db.Exec(query, id, status, rejectionReason)
		return err
	}
	query := `UPDATE events SET status = $2, rejection_reason = $3 WHERE id = $1`
	_, err := r.db.Exec(query, id, status, rejectionReason)
	return err
}

// UpdateStatusWithReviewer updates the status of an event and records who reviewed it
func (r *Repository) UpdateStatusWithReviewer(id uuid.UUID, status string, rejectionReason *string, reviewedBy uuid.UUID) error {
	if status == "approved" || status == "published" {
		query := `UPDATE events SET status = $2, rejection_reason = $3, reviewed_by = $4, reviewed_at = NOW(), is_published = true, approved_at = NOW() WHERE id = $1`
		_, err := r.db.Exec(query, id, status, rejectionReason, reviewedBy)
		return err
	}
	query := `UPDATE events SET status = $2, rejection_reason = $3, reviewed_by = $4, reviewed_at = NOW() WHERE id = $1`
	_, err := r.db.Exec(query, id, status, rejectionReason, reviewedBy)
	return err
}

// ListPending retrieves pending events for admin review
func (r *Repository) ListPending() ([]models.EventWithOrganizer, error) {
	query := `SELECT ` + eventWithOrgCols + `
		FROM events e
		JOIN organizers o ON e.organizer_id = o.id
		WHERE e.status IN ('pending', 'draft')
		ORDER BY e.created_at ASC`

	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var events []models.EventWithOrganizer
	for rows.Next() {
		var event models.EventWithOrganizer
		if err := scanEventWithOrg(rows, &event); err != nil {
			return nil, err
		}
		events = append(events, event)
	}

	return events, nil
}

// FindDuplicate checks if a similar event already exists for the same organizer
func (r *Repository) FindDuplicate(organizerID uuid.UUID, title string, startDate time.Time) (*models.Event, error) {
	query := `SELECT ` + bareEventCols + `
		FROM events
		WHERE organizer_id = $1
		  AND LOWER(title) = LOWER($2)
		  AND DATE(start_date) = DATE($3)
		  AND status NOT IN ('cancelled', 'rejected')
		LIMIT 1`

	var event models.Event
	if err := scanEvent(r.db.QueryRow(query, organizerID, title, startDate), &event); err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &event, nil
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

// CheckUserRegistration checks if a user is registered for an event and returns the status
func (r *Repository) CheckUserRegistration(userID, eventID uuid.UUID) (string, error) {
	var status string
	err := r.db.QueryRow(
		`SELECT status FROM event_registrations WHERE user_id = $1 AND event_id = $2 LIMIT 1`,
		userID, eventID,
	).Scan(&status)
	if err == sql.ErrNoRows {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return status, nil
}
