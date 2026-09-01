package event

import (
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"

	"github.com/khair/backend/internal/eligibility"
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

// RecordExternalRegistrationClick keeps a privacy-minimal aggregate audit of
// outbound registration handoffs. The destination URL is never stored here.
func (r *Repository) RecordExternalRegistrationClick(eventID uuid.UUID, domain string) error {
	result, err := r.db.Exec(`INSERT INTO event_external_registration_clicks (event_id, domain)
		SELECT id, $2 FROM events WHERE id=$1 AND status IN ('approved', 'published')`, eventID, domain)
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
	Category    *string
	Language    *string
	StartDate   *time.Time
	EndDate     *time.Time
	Status      *string
	IsPublished *bool
	Search      *string
	IsOnline    *bool
	FreeOnly    bool
	PricingType *string
	Latitude    *float64
	Longitude   *float64
	RadiusKm    *float64
	Trending    bool
	Page        int
	PageSize    int
}

// ── Column lists used across queries ──

const eventCols = `e.id, e.organizer_id, e.title, e.description, e.event_type, e.category, e.language,
       e.country, e.city, e.address, e.latitude, e.longitude, e.start_date, e.end_date,
	   e.image_url, e.capacity, e.reserved_count, e.gender_restriction, e.attendance_policy, e.age_min, e.age_max,
       e.pricing_type, e.price_cents, e.currency, e.payment_method,
       e.status, e.is_published, e.is_online, e.online_link, e.join_instructions,
       e.join_link_visible_before_minutes, e.rejection_reason, e.approved_at,
       e.created_at, e.updated_at, e.venue_name, e.online_platform,
	   e.registration_deadline, e.registration_mode, e.timezone,
	   e.registration_required, e.registration_type, e.external_platform_name,
	   e.external_registration_url, e.external_registration_instructions,
	   e.registration_requirements, e.application_approval_required,
	   e.organizer_guidelines,
       COALESCE((SELECT array_agg(et.tag ORDER BY et.created_at)
                 FROM event_tags et WHERE et.event_id = e.id), ARRAY[]::text[])`

const eventWithOrgCols = eventCols + `, o.name as organizer_name`

const bareEventCols = `id, organizer_id, title, description, event_type, category, language,
       country, city, address, latitude, longitude, start_date, end_date,
	   image_url, capacity, reserved_count, gender_restriction, attendance_policy, age_min, age_max,
       pricing_type, price_cents, currency, payment_method,
       status, is_published, is_online, online_link, join_instructions,
       join_link_visible_before_minutes, rejection_reason, approved_at,
       created_at, updated_at, venue_name, online_platform,
	   registration_deadline, registration_mode, timezone,
	   registration_required, registration_type, external_platform_name,
	   external_registration_url, external_registration_instructions,
	   registration_requirements, application_approval_required,
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
		&event.Capacity, &event.ReservedCount, &event.GenderRestriction, &event.AttendancePolicy, &event.AgeMin, &event.AgeMax,
		&pricingType, &amountCents, &currency, &paymentMethod,
		&event.Status, &event.IsPublished, &event.IsOnline, &event.OnlineLink, &event.JoinInstructions,
		&event.JoinLinkVisibleBeforeMinutes, &event.RejectionReason, &event.ApprovedAt,
		&event.CreatedAt, &event.UpdatedAt, &event.VenueName, &event.OnlinePlatform,
		&event.RegistrationDeadline, &event.RegistrationMode, &event.Timezone,
		&event.RegistrationRequired, &event.RegistrationType, &event.ExternalPlatformName,
		&event.ExternalRegistrationURL, &event.ExternalRegistrationInstructions,
		&event.RegistrationRequirements, &event.ApplicationApprovalRequired,
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
		&event.Capacity, &event.ReservedCount, &event.GenderRestriction, &event.AttendancePolicy, &event.AgeMin, &event.AgeMax,
		&pricingType, &amountCents, &currency, &paymentMethod,
		&event.Status, &event.IsPublished, &event.IsOnline, &event.OnlineLink, &event.JoinInstructions,
		&event.JoinLinkVisibleBeforeMinutes, &event.RejectionReason, &event.ApprovedAt,
		&event.CreatedAt, &event.UpdatedAt, &event.VenueName, &event.OnlinePlatform,
		&event.RegistrationDeadline, &event.RegistrationMode, &event.Timezone,
		&event.RegistrationRequired, &event.RegistrationType, &event.ExternalPlatformName,
		&event.ExternalRegistrationURL, &event.ExternalRegistrationInstructions,
		&event.RegistrationRequirements, &event.ApplicationApprovalRequired,
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
	policy, legacyGenderRestriction, err := persistedAttendancePolicy(event)
	if err != nil {
		return err
	}
	event.AttendancePolicy = policy
	event.GenderRestriction = legacyGenderRestriction

	query := `
		INSERT INTO events (id, organizer_id, title, description, event_type, language, 
		                    country, city, address, latitude, longitude, start_date, end_date, 
		                    image_url, pricing_type, price_cents, currency, payment_method, is_online, online_link, join_instructions,
			                    join_link_visible_before_minutes, status, created_at, updated_at, gender_restriction, attendance_policy,
			                    registration_required, registration_type, external_platform_name, external_registration_url,
			                    external_registration_instructions, registration_requirements, application_approval_required)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31, $32, $33, $34)
	`

	pricingType := "free"
	var priceCents int64 = 0
	var currency, paymentMethod *string
	if event.Pricing != nil {
		pricingType = event.Pricing.Type
		if event.Pricing.AmountCents != nil {
			priceCents = *event.Pricing.AmountCents
		}
		currency = event.Pricing.Currency
		paymentMethod = event.Pricing.PaymentMethod
	}

	_, err = r.db.Exec(query,
		event.ID, event.OrganizerID, event.Title, event.Description, event.EventType,
		event.Language, event.Country, event.City, event.Address, event.Latitude,
		event.Longitude, event.StartDate, event.EndDate, event.ImageURL,
		pricingType, priceCents, currency, paymentMethod,
		event.IsOnline, event.OnlineLink, event.JoinInstructions,
		event.JoinLinkVisibleBeforeMinutes, event.Status,
		event.CreatedAt, event.UpdatedAt,
		event.GenderRestriction, event.AttendancePolicy,
		event.RegistrationRequired, event.RegistrationType, event.ExternalPlatformName,
		event.ExternalRegistrationURL, event.ExternalRegistrationInstructions,
		event.RegistrationRequirements, event.ApplicationApprovalRequired,
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
	countQuery := `SELECT COUNT(*) FROM events e JOIN organizers o ON e.organizer_id = o.id WHERE 1=1`

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

	if filter.Category != nil {
		query += ` AND e.category = $` + strconv.Itoa(argIndex)
		countQuery += ` AND e.category = $` + strconv.Itoa(argIndex)
		args = append(args, *filter.Category)
		countArgs = append(countArgs, *filter.Category)
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

	if filter.PricingType != nil {
		clause := ` AND e.pricing_type = $` + strconv.Itoa(argIndex)
		query += clause
		countQuery += clause
		args = append(args, *filter.PricingType)
		countArgs = append(countArgs, *filter.PricingType)
		argIndex++
	}

	if filter.Latitude != nil && filter.Longitude != nil && filter.RadiusKm != nil {
		clause := ` AND e.location IS NOT NULL AND ST_DWithin(e.location, ST_SetSRID(ST_MakePoint($` + strconv.Itoa(argIndex+1) + `, $` + strconv.Itoa(argIndex) + `), 4326)::geography, $` + strconv.Itoa(argIndex+2) + ` * 1000)`
		query += clause
		countQuery += clause
		args = append(args, *filter.Latitude, *filter.Longitude, *filter.RadiusKm)
		countArgs = append(countArgs, *filter.Latitude, *filter.Longitude, *filter.RadiusKm)
		argIndex += 3
	}

	if filter.StartDate != nil {
		// The event must still be active at the beginning of the requested window.
		clause := ` AND COALESCE(e.end_date, e.start_date) >= $` + strconv.Itoa(argIndex)
		query += clause
		countQuery += clause
		args = append(args, *filter.StartDate)
		countArgs = append(countArgs, *filter.StartDate)
		argIndex++
	}

	if filter.EndDate != nil {
		// The event must begin before the requested window closes. A strict
		// comparison prevents an event beginning exactly at midnight tomorrow
		// from appearing in today's results.
		query += ` AND e.start_date < $` + strconv.Itoa(argIndex)
		countQuery += ` AND e.start_date < $` + strconv.Itoa(argIndex)
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
			COALESCE(e.search_vector, ''::tsvector) @@ websearch_to_tsquery('simple', $` + termIndex + `)
			OR e.title ILIKE $` + patternIndex + `
			OR e.description ILIKE $` + patternIndex + `
			OR e.category ILIKE $` + patternIndex + `
			OR e.city ILIKE $` + patternIndex + `
			OR e.country ILIKE $` + patternIndex + `
			OR e.address ILIKE $` + patternIndex + `
			OR e.venue_name ILIKE $` + patternIndex + `
			OR e.event_type ILIKE $` + patternIndex + `
			OR o.name ILIKE $` + patternIndex + `
			OR EXISTS (SELECT 1 FROM event_tags et WHERE et.event_id = e.id AND et.tag ILIKE $` + patternIndex + `)
			OR similarity(LOWER(COALESCE(e.title, '')), LOWER($` + termIndex + `)) >= 0.32
			OR (
				CHAR_LENGTH($` + termIndex + `) >= 3
				AND word_similarity(
					LOWER($` + termIndex + `),
					LOWER(CONCAT_WS(' ', e.title, e.description, e.category, e.event_type, e.city, e.country, e.address, e.venue_name, o.name))
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

	// Add sorting. Search results prioritize exact/title matches, then
	// PostgreSQL full-text relevance, then the next upcoming event.
	if filter.Trending {
		query += ` ORDER BY e.created_at DESC`
	} else if filter.Search != nil && *filter.Search != "" {
		termIndex := strconv.Itoa(argIndex - 2)
		patternIndex := strconv.Itoa(argIndex - 1)
		query += ` ORDER BY
			CASE WHEN LOWER(e.title) = LOWER($` + termIndex + `) THEN 100 ELSE 0 END DESC,
			CASE WHEN e.title ILIKE $` + patternIndex + ` THEN 50 ELSE 0 END DESC,
			ts_rank(COALESCE(e.search_vector, ''::tsvector), websearch_to_tsquery('simple', $` + termIndex + `)) DESC,
			e.start_date ASC`
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
	policy, legacyGenderRestriction, err := persistedAttendancePolicy(event)
	if err != nil {
		return err
	}
	event.AttendancePolicy = policy
	event.GenderRestriction = legacyGenderRestriction

	query := `
		UPDATE events SET
			title = $2, description = $3, event_type = $4, language = $5,
			country = $6, city = $7, address = $8, latitude = $9, longitude = $10,
			start_date = $11, end_date = $12, image_url = $13, status = $14,
			pricing_type = $15, price_cents = $16, currency = $17, payment_method = $18,
			is_online = $19, online_link = $20, join_instructions = $21,
			join_link_visible_before_minutes = $22,
			gender_restriction = $23, attendance_policy = $24,
			age_min = $25, age_max = $26,
			registration_required = $27, registration_type = $28,
			external_platform_name = $29, external_registration_url = $30,
			external_registration_instructions = $31, registration_requirements = $32,
			application_approval_required = $33
		WHERE id = $1
	`

	pricingType := "free"
	var priceCents int64 = 0
	var currency, paymentMethod *string
	if event.Pricing != nil {
		pricingType = event.Pricing.Type
		if event.Pricing.AmountCents != nil {
			priceCents = *event.Pricing.AmountCents
		}
		currency = event.Pricing.Currency
		paymentMethod = event.Pricing.PaymentMethod
	}

	_, err = r.db.Exec(query,
		event.ID, event.Title, event.Description, event.EventType, event.Language,
		event.Country, event.City, event.Address, event.Latitude, event.Longitude,
		event.StartDate, event.EndDate, event.ImageURL, event.Status,
		pricingType, priceCents, currency, paymentMethod,
		event.IsOnline, event.OnlineLink, event.JoinInstructions,
		event.JoinLinkVisibleBeforeMinutes,
		event.GenderRestriction, event.AttendancePolicy, event.AgeMin, event.AgeMax,
		event.RegistrationRequired, event.RegistrationType, event.ExternalPlatformName,
		event.ExternalRegistrationURL, event.ExternalRegistrationInstructions,
		event.RegistrationRequirements, event.ApplicationApprovalRequired,
	)
	return err
}

// CreateOrUpdatePendingEventUpdate stores one pending snapshot per event.
// Autosave in the organizer editor may call this more than once, so replacing
// the existing pending snapshot is intentional and keeps the admin queue clean.
func (r *Repository) CreateOrUpdatePendingEventUpdate(eventID, organizerID, requestedBy uuid.UUID, proposed *models.Event) error {
	payload, err := json.Marshal(proposed)
	if err != nil {
		return fmt.Errorf("marshal proposed event: %w", err)
	}
	_, err = r.db.Exec(`
		INSERT INTO event_update_requests
			(event_id, organizer_id, requested_by, proposed_event, status, rejection_reason, reviewed_by, reviewed_at)
		VALUES ($1, $2, $3, $4, 'pending', NULL, NULL, NULL)
		ON CONFLICT (event_id) WHERE status = 'pending'
		DO UPDATE SET
			organizer_id = EXCLUDED.organizer_id,
			requested_by = EXCLUDED.requested_by,
			proposed_event = EXCLUDED.proposed_event,
			status = 'pending',
			rejection_reason = NULL,
			reviewed_by = NULL,
			reviewed_at = NULL,
			updated_at = NOW()`, eventID, organizerID, requestedBy, payload)
	return err
}

func (r *Repository) GetPendingEventUpdate(eventID uuid.UUID) (*models.EventUpdateRequest, error) {
	var request models.EventUpdateRequest
	var payload []byte
	var requestedBy, reviewedBy sql.NullString
	if err := r.db.QueryRow(`
		SELECT id, event_id, organizer_id, requested_by, proposed_event, status,
		       rejection_reason, reviewed_by, created_at, reviewed_at
		FROM event_update_requests
		WHERE event_id = $1 AND status = 'pending'`, eventID).Scan(
		&request.ID, &request.EventID, &request.OrganizerID, &requestedBy, &payload,
		&request.Status, &request.RejectionReason, &reviewedBy,
		&request.CreatedAt, &request.ReviewedAt,
	); err != nil {
		return nil, err
	}
	if requestedBy.Valid {
		if id, err := uuid.Parse(requestedBy.String); err == nil {
			request.RequestedBy = &id
		}
	}
	if reviewedBy.Valid {
		if id, err := uuid.Parse(reviewedBy.String); err == nil {
			request.ReviewedBy = &id
		}
	}
	if err := json.Unmarshal(payload, &request.ProposedEvent); err != nil {
		return nil, fmt.Errorf("decode proposed event: %w", err)
	}
	return &request, nil
}

// ListPendingEventUpdates returns proposed versions shaped like events so the
// existing admin event review screen can display them without changing the
// public event read model.
func (r *Repository) ListPendingEventUpdates() ([]models.EventWithOrganizer, error) {
	rows, err := r.db.Query(`
		SELECT id, event_id
		FROM event_update_requests
		WHERE status = 'pending'
		ORDER BY created_at ASC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var events []models.EventWithOrganizer
	for rows.Next() {
		var requestID, eventID uuid.UUID
		if err := rows.Scan(&requestID, &eventID); err != nil {
			return nil, err
		}
		request, err := r.GetPendingEventUpdate(eventID)
		if err != nil {
			return nil, err
		}
		current, err := r.GetByID(eventID)
		if err != nil {
			return nil, err
		}
		proposed := request.ProposedEvent
		proposed.ID = current.ID
		proposed.OrganizerID = current.OrganizerID
		// This is a response-only status. The database event remains approved or
		// published until the update is reviewed.
		proposed.Status = "pending_update"
		proposed.IsPublished = current.IsPublished
		events = append(events, models.EventWithOrganizer{
			Event:         proposed,
			OrganizerName: current.OrganizerName,
		})
		_ = requestID // kept in the query for stable future response contracts
	}
	return events, rows.Err()
}

// ReviewEventUpdate approves or rejects the current pending update for an
// event. Approval applies the snapshot atomically with the request status.
func (r *Repository) ReviewEventUpdate(eventID uuid.UUID, status string, reason *string, reviewerID uuid.UUID) (*models.EventWithOrganizer, error) {
	request, err := r.GetPendingEventUpdate(eventID)
	if err != nil {
		return nil, err
	}
	if status != "approved" && status != "rejected" && status != "needs_revision" {
		return nil, errors.New("invalid event update review status")
	}

	if status != "approved" {
		_, err = r.db.Exec(`
			UPDATE event_update_requests
			SET status = $2, rejection_reason = $3, reviewed_by = $4,
			    reviewed_at = NOW(), updated_at = NOW()
			WHERE id = $1 AND status = 'pending'`, request.ID, status, reason, reviewerID)
		if err != nil {
			return nil, err
		}
		return r.GetByID(eventID)
	}

	proposed := request.ProposedEvent
	policy, legacyGenderRestriction, err := persistedAttendancePolicy(&proposed)
	if err != nil {
		return nil, err
	}
	proposed.AttendancePolicy = policy
	proposed.GenderRestriction = legacyGenderRestriction

	tx, err := r.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	var currentStatus string
	var isPublished bool
	if err := tx.QueryRow(`SELECT status, is_published FROM events WHERE id = $1 FOR UPDATE`, eventID).Scan(&currentStatus, &isPublished); err != nil {
		return nil, err
	}
	if currentStatus != "approved" && currentStatus != "published" {
		return nil, errors.New("event is no longer available for this update")
	}

	pricingType := "free"
	var priceCents int64
	var currency, paymentMethod *string
	if proposed.Pricing != nil {
		pricingType = proposed.Pricing.Type
		if proposed.Pricing.AmountCents != nil {
			priceCents = *proposed.Pricing.AmountCents
		}
		currency = proposed.Pricing.Currency
		paymentMethod = proposed.Pricing.PaymentMethod
	}
	_, err = tx.Exec(`
		UPDATE events SET
			title=$2, description=$3, event_type=$4, language=$5, country=$6,
			city=$7, address=$8, latitude=$9, longitude=$10, start_date=$11,
			end_date=$12, image_url=$13, pricing_type=$14, price_cents=$15,
			currency=$16, payment_method=$17, is_online=$18, online_link=$19,
			join_instructions=$20, join_link_visible_before_minutes=$21,
			gender_restriction=$22, attendance_policy=$23, age_min=$24,
			age_max=$25, category=$26, venue_name=$27, online_platform=$28,
			registration_deadline=$29, registration_mode=$30, timezone=$31,
			organizer_guidelines=$32, status=$33, is_published=$34
		WHERE id=$1`, eventID, proposed.Title, proposed.Description, proposed.EventType,
		proposed.Language, proposed.Country, proposed.City, proposed.Address,
		proposed.Latitude, proposed.Longitude, proposed.StartDate, proposed.EndDate,
		proposed.ImageURL, pricingType, priceCents, currency, paymentMethod,
		proposed.IsOnline, proposed.OnlineLink, proposed.JoinInstructions,
		proposed.JoinLinkVisibleBeforeMinutes, proposed.GenderRestriction,
		proposed.AttendancePolicy, proposed.AgeMin, proposed.AgeMax, proposed.Category,
		proposed.VenueName, proposed.OnlinePlatform, proposed.RegistrationDeadline,
		proposed.RegistrationMode, proposed.Timezone, proposed.OrganizerGuidelines,
		currentStatus, isPublished)
	if err != nil {
		return nil, err
	}
	if _, err = tx.Exec(`DELETE FROM event_tags WHERE event_id = $1`, eventID); err != nil {
		return nil, err
	}
	for _, tag := range normalizeTags(proposed.Tags) {
		if _, err = tx.Exec(`INSERT INTO event_tags (event_id, tag) VALUES ($1, $2) ON CONFLICT DO NOTHING`, eventID, tag); err != nil {
			return nil, err
		}
	}
	if _, err = tx.Exec(`
		UPDATE event_update_requests
		SET status = 'approved', rejection_reason = NULL, reviewed_by = $2,
		    reviewed_at = NOW(), updated_at = NOW()
		WHERE id = $1 AND status = 'pending'`, request.ID, reviewerID); err != nil {
		return nil, err
	}
	if err = tx.Commit(); err != nil {
		return nil, err
	}
	return r.GetByID(eventID)
}

func persistedAttendancePolicy(event *models.Event) (string, *string, error) {
	policyInput := event.AttendancePolicy
	if strings.TrimSpace(policyInput) == "" && event.GenderRestriction != nil {
		policyInput = *event.GenderRestriction
	}
	policy, err := eligibility.NormalizePolicy(policyInput)
	if err != nil {
		return "", nil, err
	}
	legacy := eligibility.LegacyGenderRestriction(policy)
	return policy, &legacy, nil
}

// HasFutureRegistrations is used before changing an event's eligibility
// policy so existing attendees are never silently removed.
func (r *Repository) HasFutureRegistrations(eventID uuid.UUID) (bool, error) {
	var exists bool
	err := r.db.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM event_registrations er
			JOIN events e ON e.id = er.event_id
			WHERE er.event_id = $1
			  AND er.status IN ('pending', 'confirmed', 'reserved')
			  AND COALESCE(e.end_date, e.start_date) > NOW()
		)`, eventID).Scan(&exists)
	return exists, err
}

// FlagIneligibleRegistrations keeps registrations intact while making a
// policy change visible to organizer review.
func (r *Repository) FlagIneligibleRegistrations(eventID uuid.UUID, policy string) error {
	_, err := r.db.Exec(`
		UPDATE event_registrations er
		SET eligibility_review_required = true, updated_at = NOW()
		FROM users u
		WHERE er.user_id = u.id
		  AND er.event_id = $1
		  AND er.status IN ('pending', 'confirmed', 'reserved')
		  AND $2 <> 'EVERYONE'
		  AND (($2 = 'WOMEN_ONLY' AND COALESCE(UPPER(u.gender), 'NOT_SET') <> 'WOMAN')
		    OR ($2 = 'MEN_ONLY' AND COALESCE(UPPER(u.gender), 'NOT_SET') <> 'MAN'))`, eventID, policy)
	return err
}

// Delete deletes an event
func (r *Repository) Delete(id uuid.UUID) error {
	query := `DELETE FROM events WHERE id = $1`
	_, err := r.db.Exec(query, id)
	return err
}

func (r *Repository) Cancel(id uuid.UUID) error {
	_, err := r.db.Exec(`UPDATE events SET status = 'cancelled', is_published = false WHERE id = $1`, id)
	return err
}

func (r *Repository) HasActiveRegistrations(eventID uuid.UUID) (bool, error) {
	var exists bool
	err := r.db.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM event_registrations
			WHERE event_id = $1 AND status IN ('pending', 'confirmed', 'reserved')
		)`, eventID).Scan(&exists)
	return exists, err
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
	if status == "cancelled" {
		_, err := r.db.Exec(`UPDATE events SET status = $2, rejection_reason = $3, is_published = false WHERE id = $1`, id, status, rejectionReason)
		return err
	}
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
	if status == "cancelled" {
		query := `UPDATE events SET status = $2, rejection_reason = $3, reviewed_by = $4, reviewed_at = NOW(), is_published = false WHERE id = $1`
		_, err := r.db.Exec(query, id, status, rejectionReason, reviewedBy)
		return err
	}
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

// ListAll returns every event for administrator management, including events
// that are approved, rejected, cancelled, or still in draft.
func (r *Repository) ListAll() ([]models.EventWithOrganizer, error) {
	query := `SELECT ` + eventWithOrgCols + `
		FROM events e
		JOIN organizers o ON e.organizer_id = o.id
		ORDER BY e.created_at DESC`

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
	return events, rows.Err()
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
