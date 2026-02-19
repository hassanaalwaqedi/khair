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
	Country   *string
	City      *string
	EventType *string
	Language  *string
	StartDate *time.Time
	EndDate   *time.Time
	Status    *string
	Search    *string
	Trending  bool
	Page      int
	PageSize  int
}

// Create creates a new event
func (r *Repository) Create(event *models.Event) error {
	query := `
		INSERT INTO events (id, organizer_id, title, description, event_type, language, 
		                    country, city, address, latitude, longitude, start_date, end_date, 
		                    image_url, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
	`
	_, err := r.db.Exec(query,
		event.ID, event.OrganizerID, event.Title, event.Description, event.EventType,
		event.Language, event.Country, event.City, event.Address, event.Latitude,
		event.Longitude, event.StartDate, event.EndDate, event.ImageURL, event.Status,
		event.CreatedAt, event.UpdatedAt,
	)
	return err
}

// GetByID retrieves an event by ID
func (r *Repository) GetByID(id uuid.UUID) (*models.EventWithOrganizer, error) {
	query := `
		SELECT e.id, e.organizer_id, e.title, e.description, e.event_type, e.language,
		       e.country, e.city, e.address, e.latitude, e.longitude, e.start_date, e.end_date,
		       e.image_url, e.status, e.rejection_reason, e.created_at, e.updated_at,
		       o.name as organizer_name
		FROM events e
		JOIN organizers o ON e.organizer_id = o.id
		WHERE e.id = $1
	`
	event := &models.EventWithOrganizer{}
	err := r.db.QueryRow(query, id).Scan(
		&event.ID, &event.OrganizerID, &event.Title, &event.Description, &event.EventType,
		&event.Language, &event.Country, &event.City, &event.Address, &event.Latitude,
		&event.Longitude, &event.StartDate, &event.EndDate, &event.ImageURL, &event.Status,
		&event.RejectionReason, &event.CreatedAt, &event.UpdatedAt, &event.OrganizerName,
	)
	if err != nil {
		return nil, err
	}
	return event, nil
}

// List retrieves events with filters
func (r *Repository) List(filter *EventFilter) ([]models.EventWithOrganizer, int64, error) {
	// Build query with filters
	query := `
		SELECT e.id, e.organizer_id, e.title, e.description, e.event_type, e.language,
		       e.country, e.city, e.address, e.latitude, e.longitude, e.start_date, e.end_date,
		       e.image_url, e.status, e.rejection_reason, e.created_at, e.updated_at,
		       o.name as organizer_name
		FROM events e
		JOIN organizers o ON e.organizer_id = o.id
		WHERE 1=1
	`
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
		query += ` AND e.start_date >= $` + strconv.Itoa(argIndex)
		countQuery += ` AND e.start_date >= $` + strconv.Itoa(argIndex)
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
		searchClause := ` AND (e.title ILIKE $` + strconv.Itoa(argIndex) + ` OR COALESCE(e.description, '') ILIKE $` + strconv.Itoa(argIndex) + `)`
		query += searchClause
		countQuery += searchClause
		args = append(args, "%"+*filter.Search+"%")
		countArgs = append(countArgs, "%"+*filter.Search+"%")
		argIndex++
	}

	// Get total count
	var totalCount int64
	err := r.db.QueryRow(countQuery, countArgs...).Scan(&totalCount)
	if err != nil {
		return nil, 0, err
	}

	// Add sorting — trending sorts by recency, otherwise by start_date
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
		err := rows.Scan(
			&event.ID, &event.OrganizerID, &event.Title, &event.Description, &event.EventType,
			&event.Language, &event.Country, &event.City, &event.Address, &event.Latitude,
			&event.Longitude, &event.StartDate, &event.EndDate, &event.ImageURL, &event.Status,
			&event.RejectionReason, &event.CreatedAt, &event.UpdatedAt, &event.OrganizerName,
		)
		if err != nil {
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
			start_date = $11, end_date = $12, image_url = $13, status = $14
		WHERE id = $1
	`
	_, err := r.db.Exec(query,
		event.ID, event.Title, event.Description, event.EventType, event.Language,
		event.Country, event.City, event.Address, event.Latitude, event.Longitude,
		event.StartDate, event.EndDate, event.ImageURL, event.Status,
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
	query := `
		SELECT id, organizer_id, title, description, event_type, language,
		       country, city, address, latitude, longitude, start_date, end_date,
		       image_url, status, rejection_reason, created_at, updated_at
		FROM events
		WHERE organizer_id = $1
		ORDER BY created_at DESC
	`
	rows, err := r.db.Query(query, organizerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var events []models.Event
	for rows.Next() {
		var event models.Event
		err := rows.Scan(
			&event.ID, &event.OrganizerID, &event.Title, &event.Description, &event.EventType,
			&event.Language, &event.Country, &event.City, &event.Address, &event.Latitude,
			&event.Longitude, &event.StartDate, &event.EndDate, &event.ImageURL, &event.Status,
			&event.RejectionReason, &event.CreatedAt, &event.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		events = append(events, event)
	}

	return events, nil
}

// UpdateStatus updates the status of an event
func (r *Repository) UpdateStatus(id uuid.UUID, status string, rejectionReason *string) error {
	query := `UPDATE events SET status = $2, rejection_reason = $3 WHERE id = $1`
	_, err := r.db.Exec(query, id, status, rejectionReason)
	return err
}

// ListPending retrieves pending events for admin review
func (r *Repository) ListPending() ([]models.EventWithOrganizer, error) {
	query := `
		SELECT e.id, e.organizer_id, e.title, e.description, e.event_type, e.language,
		       e.country, e.city, e.address, e.latitude, e.longitude, e.start_date, e.end_date,
		       e.image_url, e.status, e.rejection_reason, e.created_at, e.updated_at,
		       o.name as organizer_name
		FROM events e
		JOIN organizers o ON e.organizer_id = o.id
		WHERE e.status = 'pending'
		ORDER BY e.created_at ASC
	`
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var events []models.EventWithOrganizer
	for rows.Next() {
		var event models.EventWithOrganizer
		err := rows.Scan(
			&event.ID, &event.OrganizerID, &event.Title, &event.Description, &event.EventType,
			&event.Language, &event.Country, &event.City, &event.Address, &event.Latitude,
			&event.Longitude, &event.StartDate, &event.EndDate, &event.ImageURL, &event.Status,
			&event.RejectionReason, &event.CreatedAt, &event.UpdatedAt, &event.OrganizerName,
		)
		if err != nil {
			return nil, err
		}
		events = append(events, event)
	}

	return events, nil
}
