package mapservice

import (
	"database/sql"

	"github.com/khair/backend/internal/models"
)

// Repository handles database operations for map queries
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new map repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// NearbyFilter represents filters for nearby searches
type NearbyFilter struct {
	Latitude  float64
	Longitude float64
	RadiusKm  float64
	EventType *string
	Language  *string
	Limit     int
}

// BoundsFilter represents filters for bounding box searches
type BoundsFilter struct {
	MinLat    float64
	MaxLat    float64
	MinLng    float64
	MaxLng    float64
	EventType *string
	Language  *string
	Limit     int
}

// FindNearby finds events within a radius of a point
func (r *Repository) FindNearby(filter *NearbyFilter) ([]models.EventWithOrganizer, error) {
	query := `
		SELECT e.id, e.organizer_id, e.title, e.description, e.event_type, e.language,
		       e.country, e.city, e.address, e.latitude, e.longitude, e.start_date, e.end_date,
		       e.image_url, e.status, e.rejection_reason, e.created_at, e.updated_at,
		       o.name as organizer_name,
		       ST_Distance(e.location, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography) / 1000 as distance_km
		FROM events e
		JOIN organizers o ON e.organizer_id = o.id
		WHERE e.status = 'approved'
		  AND e.location IS NOT NULL
		  AND ST_DWithin(
		      e.location,
		      ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography,
		      $3 * 1000
		  )
	`

	args := []interface{}{filter.Latitude, filter.Longitude, filter.RadiusKm}
	argIndex := 4

	if filter.EventType != nil {
		query += ` AND e.event_type = $` + string(rune('0'+argIndex))
		args = append(args, *filter.EventType)
		argIndex++
	}

	if filter.Language != nil {
		query += ` AND e.language = $` + string(rune('0'+argIndex))
		args = append(args, *filter.Language)
		argIndex++
	}

	query += ` ORDER BY distance_km ASC`
	query += ` LIMIT $` + string(rune('0'+argIndex))
	args = append(args, filter.Limit)

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var events []models.EventWithOrganizer
	for rows.Next() {
		var event models.EventWithOrganizer
		var distanceKm float64
		err := rows.Scan(
			&event.ID, &event.OrganizerID, &event.Title, &event.Description, &event.EventType,
			&event.Language, &event.Country, &event.City, &event.Address, &event.Latitude,
			&event.Longitude, &event.StartDate, &event.EndDate, &event.ImageURL, &event.Status,
			&event.RejectionReason, &event.CreatedAt, &event.UpdatedAt, &event.OrganizerName,
			&distanceKm,
		)
		if err != nil {
			return nil, err
		}
		events = append(events, event)
	}

	return events, nil
}

// FindInBounds finds events within a bounding box
func (r *Repository) FindInBounds(filter *BoundsFilter) ([]models.EventWithOrganizer, error) {
	query := `
		SELECT e.id, e.organizer_id, e.title, e.description, e.event_type, e.language,
		       e.country, e.city, e.address, e.latitude, e.longitude, e.start_date, e.end_date,
		       e.image_url, e.status, e.rejection_reason, e.created_at, e.updated_at,
		       o.name as organizer_name
		FROM events e
		JOIN organizers o ON e.organizer_id = o.id
		WHERE e.status = 'approved'
		  AND e.location IS NOT NULL
		  AND ST_Within(
		      e.location::geometry,
		      ST_MakeEnvelope($1, $2, $3, $4, 4326)
		  )
	`

	args := []interface{}{filter.MinLng, filter.MinLat, filter.MaxLng, filter.MaxLat}
	argIndex := 5

	if filter.EventType != nil {
		query += ` AND e.event_type = $` + string(rune('0'+argIndex))
		args = append(args, *filter.EventType)
		argIndex++
	}

	if filter.Language != nil {
		query += ` AND e.language = $` + string(rune('0'+argIndex))
		args = append(args, *filter.Language)
		argIndex++
	}

	query += ` LIMIT $` + string(rune('0'+argIndex))
	args = append(args, filter.Limit)

	rows, err := r.db.Query(query, args...)
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
