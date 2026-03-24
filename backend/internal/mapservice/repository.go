package mapservice

import (
	"context"
	"database/sql"
	"encoding/json"
	"net"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"
)

// Repository handles database operations for geo map queries.
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new map repository.
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// FindNearby executes a radius + viewport optimized geo search.
func (r *Repository) FindNearby(ctx context.Context, filter *NearbyFilter) ([]NearbyEvent, int64, error) {
	orderClause := "recommendation_score DESC, distance_km ASC, starts_at ASC"
	if strings.EqualFold(filter.SortBy, "distance") {
		orderClause = "distance_km ASC, starts_at ASC"
	}

	query := `
		WITH user_point AS (
			SELECT ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography AS point
		),
		user_category_affinity AS (
			SELECT
				category,
				cnt / NULLIF(MAX(cnt) OVER(), 0) AS affinity
			FROM (
				SELECT
					COALESCE(ev.category, ev.event_type) AS category,
					COUNT(*)::float AS cnt
				FROM user_interactions ui
				JOIN events ev ON ev.id = ui.event_id
				WHERE ui.user_id = $20
					AND ui.interaction_type IN ('join', 'view', 'save', 'click')
				GROUP BY COALESCE(ev.category, ev.event_type)
			) ranked
		),
		user_location_affinity AS (
			SELECT LEAST(1.0, COUNT(*)::float / 20.0) AS affinity
			FROM user_interactions ui
			JOIN events ev ON ev.id = ui.event_id
			CROSS JOIN user_point up
			WHERE ui.user_id = $20
				AND ev.location_point IS NOT NULL
				AND ST_DWithin(ev.location_point, up.point, 50000)
		),
		candidate AS (
			SELECT
				e.id,
				COALESCE(e.organization_id, e.organizer_id) AS organization_id,
				e.title,
				o.name AS organization,
				COALESCE(e.category, e.event_type) AS category,
				COALESCE(e.latitude, ST_Y(e.location_point::geometry)) AS latitude,
				COALESCE(e.longitude, ST_X(e.location_point::geometry)) AS longitude,
				COALESCE(e.starts_at, e.start_date) AS starts_at,
				COALESCE(e.ends_at, e.end_date) AS ends_at,
				e.capacity,
				COALESCE(e.reserved_count, 0) AS reserved_count,
				CASE
					WHEN e.capacity IS NULL THEN NULL
					ELSE GREATEST(e.capacity - COALESCE(e.reserved_count, 0), 0)
				END AS remaining_seats,
				e.gender_restriction,
				COALESCE(e.min_age, e.age_min) AS min_age,
				COALESCE(e.max_age, e.age_max) AS max_age,
				ST_Distance(e.location_point, up.point) / 1000.0 AS distance_km,
				COALESCE(o.trust_level, 'basic') AS trust_level,
				CASE
					WHEN e.capacity IS NOT NULL AND e.capacity > 0
						THEN LEAST(1.0, COALESCE(e.reserved_count, 0)::float / e.capacity::float)
					ELSE LEAST(1.0, COALESCE(e.reserved_count, 0)::float / 50.0)
				END AS popularity_score,
				COALESCE(uca.affinity, 0.0) AS category_affinity,
				COALESCE(ula.affinity, 0.0) AS location_affinity,
				CASE
					WHEN $15 <= 0 THEN 0.5
					WHEN (COALESCE(e.min_age, e.age_min) IS NULL OR COALESCE(e.min_age, e.age_min) <= $15)
						AND (COALESCE(e.max_age, e.age_max) IS NULL OR COALESCE(e.max_age, e.age_max) >= $15)
						THEN 1.0
					ELSE 0.0
				END AS age_compatibility,
				COALESCE(aes.relevance_score, 0.0) AS ai_score,
				COALESCE(tr.join_count, 0) AS recent_join_count,
				LEAST(1.0, GREATEST(0.0,
					0.35 * GREATEST(0.0, 1.0 - ((ST_Distance(e.location_point, up.point) / 1000.0) / GREATEST($3 / 1000.0, 1.0)))
					+ 0.20 * CASE
						WHEN e.capacity IS NOT NULL AND e.capacity > 0
							THEN LEAST(1.0, COALESCE(e.reserved_count, 0)::float / e.capacity::float)
						ELSE LEAST(1.0, COALESCE(e.reserved_count, 0)::float / 50.0)
					  END
					+ 0.15 * COALESCE(uca.affinity, 0.0)
					+ 0.10 * COALESCE(ula.affinity, 0.0)
					+ 0.10 * CASE
						WHEN $15 <= 0 THEN 0.5
						WHEN (COALESCE(e.min_age, e.age_min) IS NULL OR COALESCE(e.min_age, e.age_min) <= $15)
							AND (COALESCE(e.max_age, e.age_max) IS NULL OR COALESCE(e.max_age, e.age_max) >= $15)
							THEN 1.0
						ELSE 0.0
					  END
					+ 0.10 * COALESCE(aes.relevance_score, 0.0)
				)) AS recommendation_score,
				(COALESCE(tr.join_count, 0) >= 8 OR
					(
						CASE
							WHEN e.capacity IS NOT NULL AND e.capacity > 0
								THEN LEAST(1.0, COALESCE(e.reserved_count, 0)::float / e.capacity::float)
							ELSE LEAST(1.0, COALESCE(e.reserved_count, 0)::float / 50.0)
						END
					) >= 0.75
				) AS is_trending,
				($20 IS NOT NULL AND
					LEAST(1.0, GREATEST(0.0,
						0.35 * GREATEST(0.0, 1.0 - ((ST_Distance(e.location_point, up.point) / 1000.0) / GREATEST($3 / 1000.0, 1.0)))
						+ 0.20 * CASE
							WHEN e.capacity IS NOT NULL AND e.capacity > 0
								THEN LEAST(1.0, COALESCE(e.reserved_count, 0)::float / e.capacity::float)
							ELSE LEAST(1.0, COALESCE(e.reserved_count, 0)::float / 50.0)
						  END
						+ 0.15 * COALESCE(uca.affinity, 0.0)
						+ 0.10 * COALESCE(ula.affinity, 0.0)
						+ 0.10 * CASE
							WHEN $15 <= 0 THEN 0.5
							WHEN (COALESCE(e.min_age, e.age_min) IS NULL OR COALESCE(e.min_age, e.age_min) <= $15)
								AND (COALESCE(e.max_age, e.age_max) IS NULL OR COALESCE(e.max_age, e.age_max) >= $15)
								THEN 1.0
							ELSE 0.0
						  END
						+ 0.10 * COALESCE(aes.relevance_score, 0.0)
					)) >= 0.65
				) AS recommended,
				(COALESCE(e.ends_at, e.end_date, COALESCE(e.starts_at, e.start_date) + INTERVAL '2 hours') <= NOW() + INTERVAL '24 hours') AS ending_soon
			FROM events e
			JOIN organizers o ON o.id = COALESCE(e.organization_id, e.organizer_id)
			CROSS JOIN user_point up
			LEFT JOIN ai_event_scores aes
				ON aes.user_id = $20
				AND aes.event_id = e.id
			LEFT JOIN user_category_affinity uca
				ON uca.category = COALESCE(e.category, e.event_type)
			LEFT JOIN user_location_affinity ula
				ON TRUE
			LEFT JOIN LATERAL (
				SELECT COUNT(*)::int AS join_count
				FROM event_registrations er
				WHERE er.event_id = e.id
					AND er.created_at >= NOW() - INTERVAL '48 hours'
					AND er.status IN ('pending', 'confirmed')
			) tr ON TRUE
			WHERE e.status = 'approved'
				AND e.location_point IS NOT NULL
				-- Bounding-box optimization before precise radius check
				AND e.location_point::geometry && ST_MakeEnvelope($4, $5, $6, $7, 4326)
				AND ST_DWithin(e.location_point, up.point, $3)
				-- Optional viewport bound (map viewport fetching)
				AND (
					$8 = false
					OR e.location_point::geometry && ST_MakeEnvelope($9, $10, $11, $12, 4326)
				)
				-- Multi-category filter
				AND (
					COALESCE(array_length($13::text[], 1), 0) = 0
					OR COALESCE(e.category, e.event_type) = ANY($13::text[])
				)
				-- Gender compatibility filter
				AND (
					$14 = ''
					OR COALESCE(NULLIF(e.gender_restriction, ''), 'any') IN ('any', 'mixed', $14)
				)
				-- Age compatibility
				AND (
					$15 <= 0
					OR (
						(COALESCE(e.min_age, e.age_min) IS NULL OR COALESCE(e.min_age, e.age_min) <= $15)
						AND (COALESCE(e.max_age, e.age_max) IS NULL OR COALESCE(e.max_age, e.age_max) >= $15)
					)
				)
				-- Date range
				AND ($16::timestamptz IS NULL OR COALESCE(e.starts_at, e.start_date) >= $16::timestamptz)
				AND ($17::timestamptz IS NULL OR COALESCE(e.starts_at, e.start_date) <= $17::timestamptz)
				-- Free-only filter
				AND (NOT $18 OR COALESCE(e.price_cents, 0) = 0)
				-- Almost full filter
				AND (
					NOT $19
					OR (
						e.capacity IS NOT NULL
						AND e.capacity > 0
						AND (e.capacity - COALESCE(e.reserved_count, 0)) <= GREATEST(5, CEIL(e.capacity * 0.15)::int)
					)
				)
				-- Text search on title/organization
				AND (
					$23 = ''
					OR e.title ILIKE '%' || $23 || '%'
					OR o.name ILIKE '%' || $23 || '%'
				)
		),
		paged AS (
			SELECT
				*,
				COUNT(*) OVER() AS total_count
			FROM candidate
			ORDER BY ` + orderClause + `
			LIMIT $21 OFFSET $22
		)
		SELECT
			id,
			organization_id,
			title,
			organization,
			category,
			latitude,
			longitude,
			starts_at,
			ends_at,
			capacity,
			reserved_count,
			remaining_seats,
			gender_restriction,
			min_age,
			max_age,
			distance_km,
			trust_level,
			is_trending,
			recommendation_score,
			recommended,
			ending_soon,
			total_count
		FROM paged
	`

	args := []interface{}{
		filter.Latitude,                     // $1
		filter.Longitude,                    // $2
		filter.RadiusKm * 1000.0,            // $3 meters
		filter.MinLng,                       // $4
		filter.MinLat,                       // $5
		filter.MaxLng,                       // $6
		filter.MaxLat,                       // $7
		filter.UseViewport,                  // $8
		filter.MinLng,                       // $9
		filter.MinLat,                       // $10
		filter.MaxLng,                       // $11
		filter.MaxLat,                       // $12
		pq.Array(filter.Categories),         // $13
		filter.Gender,                       // $14
		filter.Age,                          // $15
		filter.DateFrom,                     // $16
		filter.DateTo,                       // $17
		filter.FreeOnly,                     // $18
		filter.AlmostFull,                   // $19
		uuidValue(filter.UserID),            // $20
		filter.PageSize,                     // $21
		(filter.Page - 1) * filter.PageSize, // $22
		filter.Search,                       // $23
	}

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	events := make([]NearbyEvent, 0, filter.PageSize)
	var totalCount int64

	for rows.Next() {
		var ev NearbyEvent
		var endsAt sql.NullTime
		var capacity sql.NullInt64
		var remainingSeats sql.NullInt64
		var gender sql.NullString
		var minAge sql.NullInt64
		var maxAge sql.NullInt64

		if err := rows.Scan(
			&ev.ID,
			&ev.OrganizationID,
			&ev.Title,
			&ev.Organization,
			&ev.Category,
			&ev.Latitude,
			&ev.Longitude,
			&ev.StartsAt,
			&endsAt,
			&capacity,
			&ev.ReservedCount,
			&remainingSeats,
			&gender,
			&minAge,
			&maxAge,
			&ev.DistanceKm,
			&ev.TrustLevel,
			&ev.IsTrending,
			&ev.RecommendationScore,
			&ev.Recommended,
			&ev.EndingSoon,
			&totalCount,
		); err != nil {
			return nil, 0, err
		}

		if endsAt.Valid {
			ev.EndsAt = &endsAt.Time
		}
		if capacity.Valid {
			v := int(capacity.Int64)
			ev.Capacity = &v
		}
		if remainingSeats.Valid {
			v := int(remainingSeats.Int64)
			ev.RemainingSeats = &v
		}
		if gender.Valid {
			ev.GenderRestriction = &gender.String
		}
		if minAge.Valid {
			v := int(minAge.Int64)
			ev.MinAge = &v
		}
		if maxAge.Valid {
			v := int(maxAge.Int64)
			ev.MaxAge = &v
		}

		events = append(events, ev)
	}

	if err := rows.Err(); err != nil {
		return nil, 0, err
	}

	return events, totalCount, nil
}

// ListContextualPlaces returns optional Islamic contextual layer places.
func (r *Repository) ListContextualPlaces(ctx context.Context, q *ContextualQuery) ([]ContextualPlace, error) {
	query := `
		SELECT
			id,
			name,
			place_type,
			address,
			city,
			country,
			ST_Y(location_point::geometry) AS latitude,
			ST_X(location_point::geometry) AS longitude,
			verified
		FROM islamic_places
		WHERE location_point::geometry && ST_MakeEnvelope($1, $2, $3, $4, 4326)
			AND (
				COALESCE(array_length($5::text[], 1), 0) = 0
				OR place_type = ANY($5::text[])
			)
		ORDER BY verified DESC, name ASC
		LIMIT $6
	`

	rows, err := r.db.QueryContext(
		ctx,
		query,
		q.MinLng,
		q.MinLat,
		q.MaxLng,
		q.MaxLat,
		pq.Array(q.PlaceTypes),
		q.PageSize,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	places := make([]ContextualPlace, 0, q.PageSize)
	for rows.Next() {
		var place ContextualPlace
		var address sql.NullString
		var city sql.NullString
		var country sql.NullString

		if err := rows.Scan(
			&place.ID,
			&place.Name,
			&place.PlaceType,
			&address,
			&city,
			&country,
			&place.Latitude,
			&place.Longitude,
			&place.Verified,
		); err != nil {
			return nil, err
		}

		if address.Valid {
			place.Address = &address.String
		}
		if city.Valid {
			place.City = &city.String
		}
		if country.Valid {
			place.Country = &country.String
		}

		places = append(places, place)
	}

	return places, rows.Err()
}

// GetFilterOptions returns dynamic map filter options from live data.
func (r *Repository) GetFilterOptions(ctx context.Context) (*FilterOptionsResponse, error) {
	const categoriesQuery = `
		SELECT DISTINCT COALESCE(category, event_type) AS category
		FROM events
		WHERE status = 'approved'
			AND COALESCE(starts_at, start_date) >= NOW() - INTERVAL '30 days'
			AND COALESCE(category, event_type) IS NOT NULL
		ORDER BY category ASC
		LIMIT 200
	`
	catRows, err := r.db.QueryContext(ctx, categoriesQuery)
	if err != nil {
		return nil, err
	}
	defer catRows.Close()

	categories := make([]string, 0, 64)
	for catRows.Next() {
		var category string
		if err := catRows.Scan(&category); err != nil {
			return nil, err
		}
		categories = append(categories, category)
	}
	if err := catRows.Err(); err != nil {
		return nil, err
	}

	const genderQuery = `
		SELECT DISTINCT gender_restriction
		FROM events
		WHERE status = 'approved'
			AND gender_restriction IS NOT NULL
			AND gender_restriction <> ''
		ORDER BY gender_restriction ASC
		LIMIT 20
	`
	genderRows, err := r.db.QueryContext(ctx, genderQuery)
	if err != nil {
		return nil, err
	}
	defer genderRows.Close()

	genders := make([]string, 0, 8)
	for genderRows.Next() {
		var g string
		if err := genderRows.Scan(&g); err != nil {
			return nil, err
		}
		genders = append(genders, g)
	}
	if err := genderRows.Err(); err != nil {
		return nil, err
	}

	return &FilterOptionsResponse{
		Categories:         categories,
		GenderRestrictions: genders,
		RadiusOptionsKm:    []int{5, 10, 25, 50},
	}, nil
}

// LogGeoRequest logs geo requests and suspicious behavior signals.
func (r *Repository) LogGeoRequest(ctx context.Context, log *GeoRequestLog) error {
	const query = `
		INSERT INTO geo_request_logs (
			user_id,
			ip_address,
			endpoint,
			query_hash,
			latitude,
			longitude,
			radius_km,
			bbox,
			filters,
			is_flagged,
			flag_reason,
			created_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NULLIF($11, ''), $12)
	`

	bboxJSON, _ := json.Marshal(log.BBox)
	filtersJSON, _ := json.Marshal(log.Filters)

	var ipValue interface{}
	if parsed := net.ParseIP(log.IPAddress); parsed != nil {
		ipValue = parsed.String()
	}

	_, err := r.db.ExecContext(
		ctx,
		query,
		uuidValue(log.UserID),
		ipValue,
		log.Endpoint,
		log.QueryHash,
		log.Latitude,
		log.Longitude,
		log.RadiusKm,
		bboxJSON,
		filtersJSON,
		log.IsFlagged,
		log.FlagReason,
		log.RequestedAt,
	)
	return err
}

// TrackGeoInteraction stores anonymized geo interaction metrics.
func (r *Repository) TrackGeoInteraction(ctx context.Context, metric *GeoInteractionMetric) error {
	const query = `
		INSERT INTO geo_interaction_metrics (
			event_type,
			user_id,
			session_hash,
			latitude,
			longitude,
			distance_km,
			metadata,
			created_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`

	metadataJSON, _ := json.Marshal(metric.Metadata)

	_, err := r.db.ExecContext(
		ctx,
		query,
		metric.EventType,
		uuidValue(metric.UserID),
		metric.SessionHash,
		metric.Latitude,
		metric.Longitude,
		metric.DistanceKm,
		metadataJSON,
		time.Now(),
	)
	return err
}

func uuidValue(id *uuid.UUID) interface{} {
	if id == nil {
		return nil
	}
	return *id
}
