package event

import (
	"database/sql"
	"errors"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"

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

func (r *Repository) IsSaved(userID, eventID uuid.UUID) (bool, error) {
	var exists bool
	err := r.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM saved_events WHERE user_id = $1 AND event_id = $2)`, userID, eventID).Scan(&exists)
	return exists, err
}

func (r *Repository) SaveForUser(userID, eventID uuid.UUID) error {
	_, err := r.db.Exec(`INSERT INTO saved_events (user_id, event_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, userID, eventID)
	return err
}

func (r *Repository) UnsaveForUser(userID, eventID uuid.UUID) error {
	_, err := r.db.Exec(`DELETE FROM saved_events WHERE user_id = $1 AND event_id = $2`, userID, eventID)
	return err
}

// RecordView stores a visit only when the target remains publicly viewable.
func (r *Repository) RecordView(eventID uuid.UUID, sessionID string) error {
	result, err := r.db.Exec(`INSERT INTO event_views (event_id, session_id, source)
		SELECT e.id, $2, 'event_detail'
		FROM events e
		WHERE e.id=$1 AND e.status IN ('approved', 'published')
		  AND NOT EXISTS (
			SELECT 1 FROM event_views existing
			WHERE existing.event_id = e.id
			  AND existing.session_id = $2
			  AND existing.created_at >= NOW() - INTERVAL '30 minutes'
		  )`, eventID, sessionID)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return errors.New("event not found")
	}
	return nil
}

type SavedEventSummary struct {
	ID        uuid.UUID `json:"id"`
	Title     string    `json:"title"`
	StartDate time.Time `json:"start_date"`
	ImageURL  *string   `json:"image_url,omitempty"`
	City      *string   `json:"city,omitempty"`
	Country   *string   `json:"country,omitempty"`
	EventType string    `json:"event_type"`
	IsOnline  bool      `json:"is_online"`
}

func (r *Repository) GetSavedEvents(userID uuid.UUID) ([]SavedEventSummary, error) {
	rows, err := r.db.Query(`
		SELECT e.id, e.title, e.start_date, e.image_url, e.city, e.country, e.event_type, e.is_online
		FROM saved_events s JOIN events e ON e.id = s.event_id
		WHERE s.user_id = $1 AND e.status = 'approved'
		ORDER BY s.created_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []SavedEventSummary{}
	for rows.Next() {
		var item SavedEventSummary
		if err := rows.Scan(&item.ID, &item.Title, &item.StartDate, &item.ImageURL, &item.City, &item.Country, &item.EventType, &item.IsOnline); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
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
	IsOnline    *bool
	FreeOnly    bool
	Trending    bool
	Page        int
	PageSize    int
}

// ── Column lists used across queries ──

const eventCols = `e.id, e.organizer_id, e.title, e.description, e.event_type, e.category, e.language,
       e.country, e.city, e.address, e.latitude, e.longitude, e.start_date, e.end_date,
       e.image_url, e.capacity, e.reserved_count, e.gender_restriction, e.age_min, e.age_max,
       e.pricing_type, e.price_cents, e.currency, e.payment_method,
       e.status, e.is_published, e.is_online, e.online_link, e.join_instructions,
       e.join_link_visible_before_minutes, e.rejection_reason, e.approved_at,
       e.created_at, e.updated_at, e.venue_name, e.online_platform,
       e.registration_deadline, e.registration_mode, e.timezone,
       e.organizer_guidelines,
       COALESCE((SELECT array_agg(et.tag ORDER BY et.created_at)
                 FROM event_tags et WHERE et.event_id = e.id), ARRAY[]::text[])`

const eventWithOrgCols = eventCols + `, o.name as organizer_name`

const bareEventCols = `id, organizer_id, title, description, event_type, category, language,
       country, city, address, latitude, longitude, start_date, end_date,
       image_url, capacity, reserved_count, gender_restriction, age_min, age_max,
       pricing_type, price_cents, currency, payment_method,
       status, is_published, is_online, online_link, join_instructions,
       join_link_visible_before_minutes, rejection_reason, approved_at,
       created_at, updated_at, venue_name, online_platform,
       registration_deadline, registration_mode, timezone,
       organizer_guidelines,
       COALESCE((SELECT array_agg(et.tag ORDER BY et.created_at)
                 FROM event_tags et WHERE et.event_id = events.id), ARRAY[]::text[])`

// scanEvent scans a row into an Event struct
func scanEvent(scanner interface {
	Scan(dest ...interface{}) error
}, event *models.Event) error {
	var pricingType string
	var amountCents *int64
	var currency, paymentMethod *string

	err := scanner.Scan(
		&event.ID, &event.OrganizerID, &event.Title, &event.Description, &event.EventType,
		&event.Category, &event.Language, &event.Country, &event.City, &event.Address, &event.Latitude,
		&event.Longitude, &event.StartDate, &event.EndDate, &event.ImageURL,
		&event.Capacity, &event.ReservedCount, &event.GenderRestriction, &event.AgeMin, &event.AgeMax,
		&pricingType, &amountCents, &currency, &paymentMethod,
		&event.Status, &event.IsPublished, &event.IsOnline, &event.OnlineLink, &event.JoinInstructions,
		&event.JoinLinkVisibleBeforeMinutes, &event.RejectionReason, &event.ApprovedAt,
		&event.CreatedAt, &event.UpdatedAt, &event.VenueName, &event.OnlinePlatform,
		&event.RegistrationDeadline, &event.RegistrationMode, &event.Timezone,
		&event.OrganizerGuidelines, pq.Array(&event.Tags),
	)
	if err != nil {
		return err
	}
	
	if pricingType == "" {
		pricingType = "free"
	}
	event.Pricing = &models.PricingInfo{
		Type:          pricingType,
		AmountCents:   amountCents,
		Currency:      currency,
		PaymentMethod: paymentMethod,
	}
	return nil
}

// scanEventWithOrg scans a row into an EventWithOrganizer struct
func scanEventWithOrg(scanner interface {
	Scan(dest ...interface{}) error
}, event *models.EventWithOrganizer) error {
	var pricingType string
	var amountCents *int64
	var currency, paymentMethod *string

	err := scanner.Scan(
		&event.ID, &event.OrganizerID, &event.Title, &event.Description, &event.EventType,
		&event.Category, &event.Language, &event.Country, &event.City, &event.Address, &event.Latitude,
		&event.Longitude, &event.StartDate, &event.EndDate, &event.ImageURL,
		&event.Capacity, &event.ReservedCount, &event.GenderRestriction, &event.AgeMin, &event.AgeMax,
		&pricingType, &amountCents, &currency, &paymentMethod,
		&event.Status, &event.IsPublished, &event.IsOnline, &event.OnlineLink, &event.JoinInstructions,
		&event.JoinLinkVisibleBeforeMinutes, &event.RejectionReason, &event.ApprovedAt,
		&event.CreatedAt, &event.UpdatedAt, &event.VenueName, &event.OnlinePlatform,
		&event.RegistrationDeadline, &event.RegistrationMode, &event.Timezone,
		&event.OrganizerGuidelines, pq.Array(&event.Tags), &event.OrganizerName,
	)
	if err != nil {
		return err
	}
	
	if pricingType == "" {
		pricingType = "free"
	}
	event.Pricing = &models.PricingInfo{
		Type:          pricingType,
		AmountCents:   amountCents,
		Currency:      currency,
		PaymentMethod: paymentMethod,
	}
	return nil
}

// Create creates a new event
func (r *Repository) Create(event *models.Event) error {
	query := `
		INSERT INTO events (id, organizer_id, title, description, event_type, language, 
		                    country, city, address, latitude, longitude, start_date, end_date, 
		                    image_url, pricing_type, price_cents, currency, payment_method, is_online, online_link, join_instructions,
		                    join_link_visible_before_minutes, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25)
	`
	
	pricingType := "free"
	var priceCents *int64
	var currency, paymentMethod *string
	if event.Pricing != nil {
		pricingType = event.Pricing.Type
		priceCents = event.Pricing.AmountCents
		currency = event.Pricing.Currency
		paymentMethod = event.Pricing.PaymentMethod
	}

	_, err := r.db.Exec(query,
		event.ID, event.OrganizerID, event.Title, event.Description, event.EventType,
		event.Language, event.Country, event.City, event.Address, event.Latitude,
		event.Longitude, event.StartDate, event.EndDate, event.ImageURL,
		pricingType, priceCents, currency, paymentMethod,
		event.IsOnline, event.OnlineLink, event.JoinInstructions,
		event.JoinLinkVisibleBeforeMinutes, event.Status,
		event.CreatedAt, event.UpdatedAt,
	)
	return err
}

// SaveEditorMetadata persists fields introduced by the premium event editor
// without forcing the legacy Event read model to change all at once.
func (r *Repository) SaveEditorMetadata(eventID uuid.UUID, category string, tags []string, venueName, onlinePlatform *string, registrationDeadline *time.Time, registrationMode, timezone string, guidelines *string) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`UPDATE events SET category=$2, venue_name=$3, online_platform=$4, registration_deadline=$5, registration_mode=$6, timezone=$7, organizer_guidelines=$8 WHERE id=$1`, eventID, category, venueName, onlinePlatform, registrationDeadline, registrationMode, timezone, guidelines); err != nil {
		return err
	}
	if _, err := tx.Exec(`DELETE FROM event_tags WHERE event_id=$1`, eventID); err != nil {
		return err
	}
	for _, tag := range normalizeTags(tags) {
		if _, err := tx.Exec(`INSERT INTO event_tags (event_id, tag) VALUES ($1, $2) ON CONFLICT DO NOTHING`, eventID, tag); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (r *Repository) UpdateEditorMetadata(eventID uuid.UUID, category *string, tags *[]string, venueName, onlinePlatform *string, registrationDeadline *time.Time, registrationMode, timezone *string, guidelines *string) error {
	if _, err := r.db.Exec(`
		UPDATE events SET
			category=COALESCE($2, category),
			venue_name=COALESCE($3, venue_name),
			online_platform=COALESCE($4, online_platform),
			registration_deadline=COALESCE($5, registration_deadline),
			registration_mode=COALESCE($6, registration_mode),
			timezone=COALESCE($7, timezone),
			organizer_guidelines=COALESCE($8, organizer_guidelines)
		WHERE id=$1`, eventID, category, venueName, onlinePlatform, registrationDeadline, registrationMode, timezone, guidelines); err != nil {
		return err
	}
	if tags != nil {
		if _, err := r.db.Exec(`DELETE FROM event_tags WHERE event_id=$1`, eventID); err != nil {
			return err
		}
		for _, tag := range normalizeTags(*tags) {
			if _, err := r.db.Exec(`INSERT INTO event_tags (event_id, tag) VALUES ($1, $2) ON CONFLICT DO NOTHING`, eventID, tag); err != nil {
				return err
			}
		}
	}
	return nil
}

func normalizeTags(tags []string) []string {
	seen := make(map[string]struct{}, len(tags))
	result := make([]string, 0, minInt(len(tags), 8))
	for _, raw := range tags {
		tag := strings.TrimSpace(strings.TrimPrefix(raw, "#"))
		if tag == "" || len([]rune(tag)) > 32 {
			continue
		}
		key := strings.ToLower(tag)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		result = append(result, tag)
		if len(result) == 8 {
			break
		}
	}
	return result
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
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

	if filter.IsOnline != nil {
		query += ` AND e.is_online = $` + strconv.Itoa(argIndex)
		countQuery += ` AND e.is_online = $` + strconv.Itoa(argIndex)
		args = append(args, *filter.IsOnline)
		countArgs = append(countArgs, *filter.IsOnline)
		argIndex++
	}

	if filter.FreeOnly {
		const freeClause = ` AND e.pricing_type = 'free'`
		query += freeClause
		countQuery += freeClause
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
		// Search should be forgiving: full-text matching handles topics and
		// multiple words, ILIKE handles partial terms, and trigram similarity
		// catches small spelling differences such as "Hackathon" / "Hakathon".
		// The same predicate is used for the total so pagination stays accurate.
		termIndex := strconv.Itoa(argIndex)
		patternIndex := strconv.Itoa(argIndex + 1)
		searchClause := ` AND (
			search_vector @@ websearch_to_tsquery('simple', $` + termIndex + `)
			OR e.title ILIKE $` + patternIndex + `
			OR e.description ILIKE $` + patternIndex + `
			OR e.city ILIKE $` + patternIndex + `
			OR e.country ILIKE $` + patternIndex + `
			OR e.event_type ILIKE $` + patternIndex + `
			OR similarity(LOWER(COALESCE(e.title, '')), LOWER($` + termIndex + `)) >= 0.32
			OR (
				CHAR_LENGTH($` + termIndex + `) >= 3
				AND word_similarity(
					LOWER($` + termIndex + `),
					LOWER(CONCAT_WS(' ', e.title, e.description, e.event_type, e.city, e.country))
				) >= 0.38
			)
		)`
		query += searchClause
		countQuery += searchClause
		args = append(args, *filter.Search)
		args = append(args, "%"+*filter.Search+"%")
		countArgs = append(countArgs, *filter.Search)
		countArgs = append(countArgs, "%"+*filter.Search+"%")
		argIndex += 2
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
			pricing_type = $15, price_cents = $16, currency = $17, payment_method = $18,
			is_online = $19, online_link = $20, join_instructions = $21,
			join_link_visible_before_minutes = $22
		WHERE id = $1
	`
	
	pricingType := "free"
	var priceCents *int64
	var currency, paymentMethod *string
	if event.Pricing != nil {
		pricingType = event.Pricing.Type
		priceCents = event.Pricing.AmountCents
		currency = event.Pricing.Currency
		paymentMethod = event.Pricing.PaymentMethod
	}

	_, err := r.db.Exec(query,
		event.ID, event.Title, event.Description, event.EventType, event.Language,
		event.Country, event.City, event.Address, event.Latitude, event.Longitude,
		event.StartDate, event.EndDate, event.ImageURL, event.Status,
		pricingType, priceCents, currency, paymentMethod,
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
