package orgdash

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
)

// Repository handles database operations for organization dashboard
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new orgdash repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// ── Dashboard Stats ──

// GetDashboardStats retrieves overview statistics for an organization
func (r *Repository) GetDashboardStats(orgID uuid.UUID) (*models.DashboardStats, error) {
	stats := &models.DashboardStats{}

	// Total events, upcoming, past
	err := r.db.QueryRow(`
		SELECT
			COUNT(*),
			COUNT(*) FILTER (WHERE start_date > NOW()),
			COUNT(*) FILTER (WHERE start_date <= NOW())
		FROM events WHERE organizer_id = $1 AND status != 'draft'
	`, orgID).Scan(&stats.TotalEvents, &stats.UpcomingEvents, &stats.PastEvents)
	if err != nil {
		return nil, fmt.Errorf("failed to count events: %w", err)
	}

	// Total attendees (any status), confirmed
	err = r.db.QueryRow(`
		SELECT
			COALESCE(COUNT(*), 0),
			COALESCE(COUNT(*) FILTER (WHERE er.status = 'confirmed'), 0)
		FROM event_registrations er
		JOIN events e ON e.id = er.event_id
		WHERE e.organizer_id = $1
	`, orgID).Scan(&stats.TotalAttendees, &stats.ConfirmedAttendees)
	if err != nil {
		return nil, fmt.Errorf("failed to count attendees: %w", err)
	}

	// Event fill rate: average (reserved_count / capacity) for events with capacity
	var fillRate sql.NullFloat64
	err = r.db.QueryRow(`
		SELECT AVG(CASE WHEN capacity > 0 THEN reserved_count::float / capacity ELSE 0 END)
		FROM events
		WHERE organizer_id = $1 AND capacity IS NOT NULL AND capacity > 0
	`, orgID).Scan(&fillRate)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate fill rate: %w", err)
	}
	if fillRate.Valid {
		stats.EventFillRate = fillRate.Float64 * 100 // as percentage
	}

	// Trust level + profile completion from organizer
	err = r.db.QueryRow(`
		SELECT trust_level, profile_completion_score FROM organizers WHERE id = $1
	`, orgID).Scan(&stats.TrustLevel, &stats.ProfileCompletionScore)
	if err != nil && err != sql.ErrNoRows {
		return nil, fmt.Errorf("failed to get organizer info: %w", err)
	}

	return stats, nil
}

// ── Analytics ──

// GetAttendanceTrend returns daily registration counts over the last N days
func (r *Repository) GetAttendanceTrend(orgID uuid.UUID, days int) ([]models.TrendPoint, error) {
	rows, err := r.db.Query(`
		SELECT d.day::date AS date, COALESCE(COUNT(er.id), 0) AS count
		FROM generate_series(NOW() - $2::interval, NOW(), '1 day') AS d(day)
		LEFT JOIN event_registrations er ON DATE(er.created_at) = d.day::date
			AND er.event_id IN (SELECT id FROM events WHERE organizer_id = $1)
		GROUP BY d.day::date
		ORDER BY d.day::date
	`, orgID, fmt.Sprintf("%d days", days))
	if err != nil {
		return nil, fmt.Errorf("failed to get attendance trend: %w", err)
	}
	defer rows.Close()

	var trend []models.TrendPoint
	for rows.Next() {
		var pt models.TrendPoint
		var date time.Time
		if err := rows.Scan(&date, &pt.Count); err != nil {
			return nil, err
		}
		pt.Date = date.Format("2006-01-02")
		trend = append(trend, pt)
	}
	return trend, rows.Err()
}

// GetGenderDistribution returns gender split of attendees
func (r *Repository) GetGenderDistribution(orgID uuid.UUID) ([]models.DistributionItem, error) {
	rows, err := r.db.Query(`
		SELECT COALESCE(u.gender, 'unknown') AS label, COUNT(*) AS count
		FROM event_registrations er
		JOIN events e ON e.id = er.event_id
		JOIN users u ON u.id = er.user_id
		WHERE e.organizer_id = $1 AND er.status = 'confirmed'
		GROUP BY COALESCE(u.gender, 'unknown')
		ORDER BY count DESC
	`, orgID)
	if err != nil {
		return nil, fmt.Errorf("failed to get gender distribution: %w", err)
	}
	defer rows.Close()

	var items []models.DistributionItem
	for rows.Next() {
		var item models.DistributionItem
		if err := rows.Scan(&item.Label, &item.Count); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

// GetAgeDistribution returns age-bucketed distribution of attendees
func (r *Repository) GetAgeDistribution(orgID uuid.UUID) ([]models.DistributionItem, error) {
	rows, err := r.db.Query(`
		SELECT
			CASE
				WHEN u.age IS NULL THEN 'Unknown'
				WHEN u.age BETWEEN 13 AND 18 THEN '13-18'
				WHEN u.age BETWEEN 19 AND 25 THEN '19-25'
				WHEN u.age BETWEEN 26 AND 35 THEN '26-35'
				WHEN u.age BETWEEN 36 AND 50 THEN '36-50'
				ELSE '50+'
			END AS label,
			COUNT(*) AS count
		FROM event_registrations er
		JOIN events e ON e.id = er.event_id
		JOIN users u ON u.id = er.user_id
		WHERE e.organizer_id = $1 AND er.status = 'confirmed'
		GROUP BY label
		ORDER BY MIN(COALESCE(u.age, 0))
	`, orgID)
	if err != nil {
		return nil, fmt.Errorf("failed to get age distribution: %w", err)
	}
	defer rows.Close()

	var items []models.DistributionItem
	for rows.Next() {
		var item models.DistributionItem
		if err := rows.Scan(&item.Label, &item.Count); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

// GetEventPopularity returns events ranked by attendance count
func (r *Repository) GetEventPopularity(orgID uuid.UUID, limit int) ([]models.EventRanking, error) {
	rows, err := r.db.Query(`
		SELECT e.id, e.title, e.capacity, e.reserved_count,
			COALESCE(COUNT(er.id) FILTER (WHERE er.attended = true), 0) AS attended_count
		FROM events e
		LEFT JOIN event_registrations er ON er.event_id = e.id AND er.status = 'confirmed'
		WHERE e.organizer_id = $1
		GROUP BY e.id, e.title, e.capacity, e.reserved_count
		ORDER BY attended_count DESC, e.reserved_count DESC
		LIMIT $2
	`, orgID, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to get event popularity: %w", err)
	}
	defer rows.Close()

	var rankings []models.EventRanking
	for rows.Next() {
		var r models.EventRanking
		if err := rows.Scan(&r.EventID, &r.Title, &r.Capacity, &r.ReservedCount, &r.AttendedCount); err != nil {
			return nil, err
		}
		rankings = append(rankings, r)
	}
	return rankings, rows.Err()
}

// GetConversionRate calculates reserved → confirmed conversion for the org
func (r *Repository) GetConversionRate(orgID uuid.UUID) (totalReserved int, totalConfirmed int, err error) {
	err = r.db.QueryRow(`
		SELECT
			COALESCE(COUNT(*), 0),
			COALESCE(COUNT(*) FILTER (WHERE er.status = 'confirmed'), 0)
		FROM event_registrations er
		JOIN events e ON e.id = er.event_id
		WHERE e.organizer_id = $1
	`, orgID).Scan(&totalReserved, &totalConfirmed)
	return
}

// ── Audit Log ──

// GetRecentActivity fetches recent audit log entries for the org
func (r *Repository) GetRecentActivity(orgID uuid.UUID, limit int) ([]models.OrgAuditLog, error) {
	rows, err := r.db.Query(`
		SELECT oal.id, oal.organization_id, oal.actor_id, oal.action,
			oal.target_type, oal.target_id, oal.metadata, oal.created_at,
			COALESCE(u.email, '') AS actor_email
		FROM org_audit_logs oal
		LEFT JOIN users u ON u.id = oal.actor_id
		WHERE oal.organization_id = $1
		ORDER BY oal.created_at DESC
		LIMIT $2
	`, orgID, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to get recent activity: %w", err)
	}
	defer rows.Close()

	var logs []models.OrgAuditLog
	for rows.Next() {
		var log models.OrgAuditLog
		if err := rows.Scan(
			&log.ID, &log.OrganizationID, &log.ActorID, &log.Action,
			&log.TargetType, &log.TargetID, &log.Metadata, &log.CreatedAt,
			&log.ActorEmail,
		); err != nil {
			return nil, err
		}
		logs = append(logs, log)
	}
	return logs, rows.Err()
}

// LogAction inserts an audit log entry
func (r *Repository) LogAction(orgID, actorID uuid.UUID, action string, targetType *string, targetID *uuid.UUID, metadata interface{}, ipAddress *string) error {
	metaJSON, _ := json.Marshal(metadata)
	_, err := r.db.Exec(`
		INSERT INTO org_audit_logs (id, organization_id, actor_id, action, target_type, target_id, metadata, ip_address)
		VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7)
	`, orgID, actorID, action, targetType, targetID, metaJSON, ipAddress)
	return err
}

// ── Organization Events (org-scoped) ──

// ListOrgEvents returns events for an organization with attendee counts
func (r *Repository) ListOrgEvents(orgID uuid.UUID, status *string, page, pageSize int) ([]models.Event, int64, error) {
	args := []interface{}{orgID}
	where := "WHERE e.organizer_id = $1"
	argN := 2

	if status != nil {
		where += fmt.Sprintf(" AND e.status = $%d", argN)
		args = append(args, *status)
		argN++
	}

	// Count
	var count int64
	countQ := fmt.Sprintf("SELECT COUNT(*) FROM events e %s", where)
	if err := r.db.QueryRow(countQ, args...).Scan(&count); err != nil {
		return nil, 0, fmt.Errorf("failed to count events: %w", err)
	}

	// Paginated list
	query := fmt.Sprintf(`
		SELECT e.id, e.organizer_id, e.title, e.description, e.event_type, e.language,
			e.country, e.city, e.address, e.latitude, e.longitude, e.start_date,
			e.end_date, e.image_url, e.capacity, e.reserved_count,
			e.gender_restriction, e.age_min, e.age_max,
			e.status, e.rejection_reason, e.created_at, e.updated_at
		FROM events e %s
		ORDER BY e.created_at DESC
		LIMIT $%d OFFSET $%d
	`, where, argN, argN+1)
	args = append(args, pageSize, (page-1)*pageSize)

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to list org events: %w", err)
	}
	defer rows.Close()

	var events []models.Event
	for rows.Next() {
		var ev models.Event
		if err := rows.Scan(
			&ev.ID, &ev.OrganizerID, &ev.Title, &ev.Description, &ev.EventType, &ev.Language,
			&ev.Country, &ev.City, &ev.Address, &ev.Latitude, &ev.Longitude, &ev.StartDate,
			&ev.EndDate, &ev.ImageURL, &ev.Capacity, &ev.ReservedCount,
			&ev.GenderRestriction, &ev.AgeMin, &ev.AgeMax,
			&ev.Status, &ev.RejectionReason, &ev.CreatedAt, &ev.UpdatedAt,
		); err != nil {
			return nil, 0, err
		}
		events = append(events, ev)
	}
	return events, count, rows.Err()
}

// CreateEvent inserts a new event for the organization
func (r *Repository) CreateEvent(ev *models.Event) error {
	return r.db.QueryRow(`
		INSERT INTO events (organizer_id, title, description, event_type, language,
			country, city, address, latitude, longitude, start_date, end_date,
			image_url, capacity, gender_restriction, age_min, age_max, status)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
		RETURNING id, created_at, updated_at
	`,
		ev.OrganizerID, ev.Title, ev.Description, ev.EventType, ev.Language,
		ev.Country, ev.City, ev.Address, ev.Latitude, ev.Longitude,
		ev.StartDate, ev.EndDate, ev.ImageURL, ev.Capacity,
		ev.GenderRestriction, ev.AgeMin, ev.AgeMax, ev.Status,
	).Scan(&ev.ID, &ev.CreatedAt, &ev.UpdatedAt)
}

// UpdateEvent updates an existing event
func (r *Repository) UpdateEvent(ev *models.Event) error {
	_, err := r.db.Exec(`
		UPDATE events SET
			title=$2, description=$3, event_type=$4, language=$5,
			country=$6, city=$7, address=$8, latitude=$9, longitude=$10,
			start_date=$11, end_date=$12, image_url=$13, capacity=$14,
			gender_restriction=$15, age_min=$16, age_max=$17
		WHERE id=$1
	`,
		ev.ID, ev.Title, ev.Description, ev.EventType, ev.Language,
		ev.Country, ev.City, ev.Address, ev.Latitude, ev.Longitude,
		ev.StartDate, ev.EndDate, ev.ImageURL, ev.Capacity,
		ev.GenderRestriction, ev.AgeMin, ev.AgeMax,
	)
	return err
}

// CancelEvent sets event status to 'draft' (cancelled)
func (r *Repository) CancelEvent(eventID uuid.UUID) error {
	_, err := r.db.Exec(`UPDATE events SET status = 'draft' WHERE id = $1`, eventID)
	return err
}

// DuplicateEvent creates a copy of an event with a new ID and draft status
func (r *Repository) DuplicateEvent(eventID, orgID uuid.UUID) (*models.Event, error) {
	ev := &models.Event{}
	err := r.db.QueryRow(`
		INSERT INTO events (organizer_id, title, description, event_type, language,
			country, city, address, latitude, longitude, start_date, end_date,
			image_url, capacity, gender_restriction, age_min, age_max, status)
		SELECT organizer_id, title || ' (Copy)', description, event_type, language,
			country, city, address, latitude, longitude, start_date, end_date,
			image_url, capacity, gender_restriction, age_min, age_max, 'draft'
		FROM events WHERE id = $1 AND organizer_id = $2
		RETURNING id, organizer_id, title, description, event_type, language,
			country, city, address, latitude, longitude, start_date, end_date,
			image_url, capacity, COALESCE(reserved_count, 0),
			gender_restriction, age_min, age_max,
			status, rejection_reason, created_at, updated_at
	`, eventID, orgID).Scan(
		&ev.ID, &ev.OrganizerID, &ev.Title, &ev.Description, &ev.EventType, &ev.Language,
		&ev.Country, &ev.City, &ev.Address, &ev.Latitude, &ev.Longitude,
		&ev.StartDate, &ev.EndDate, &ev.ImageURL, &ev.Capacity, &ev.ReservedCount,
		&ev.GenderRestriction, &ev.AgeMin, &ev.AgeMax,
		&ev.Status, &ev.RejectionReason, &ev.CreatedAt, &ev.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to duplicate event: %w", err)
	}
	return ev, nil
}

// GetEventByID returns a single event, verifying it belongs to the org
func (r *Repository) GetEventByID(eventID, orgID uuid.UUID) (*models.Event, error) {
	ev := &models.Event{}
	err := r.db.QueryRow(`
		SELECT id, organizer_id, title, description, event_type, language,
			country, city, address, latitude, longitude, start_date, end_date,
			image_url, capacity, reserved_count,
			gender_restriction, age_min, age_max,
			status, rejection_reason, created_at, updated_at
		FROM events WHERE id = $1 AND organizer_id = $2
	`, eventID, orgID).Scan(
		&ev.ID, &ev.OrganizerID, &ev.Title, &ev.Description, &ev.EventType, &ev.Language,
		&ev.Country, &ev.City, &ev.Address, &ev.Latitude, &ev.Longitude,
		&ev.StartDate, &ev.EndDate, &ev.ImageURL, &ev.Capacity, &ev.ReservedCount,
		&ev.GenderRestriction, &ev.AgeMin, &ev.AgeMax,
		&ev.Status, &ev.RejectionReason, &ev.CreatedAt, &ev.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return ev, nil
}

// ── Members ──

// ListMembers retrieves all members of an organization
func (r *Repository) ListMembers(orgID uuid.UUID) ([]models.OrganizationMember, error) {
	rows, err := r.db.Query(`
		SELECT om.id, om.organization_id, om.user_id, om.role, om.joined_at,
			u.email, u.display_name
		FROM organization_members om
		JOIN users u ON u.id = om.user_id
		WHERE om.organization_id = $1
		ORDER BY
			CASE om.role
				WHEN 'owner' THEN 1
				WHEN 'admin' THEN 2
				WHEN 'event_manager' THEN 3
				WHEN 'viewer' THEN 4
			END
	`, orgID)
	if err != nil {
		return nil, fmt.Errorf("failed to list members: %w", err)
	}
	defer rows.Close()

	var members []models.OrganizationMember
	for rows.Next() {
		var m models.OrganizationMember
		if err := rows.Scan(&m.ID, &m.OrganizationID, &m.UserID, &m.Role, &m.JoinedAt, &m.UserEmail, &m.DisplayName); err != nil {
			return nil, err
		}
		members = append(members, m)
	}
	return members, rows.Err()
}

// AddMember adds a user to an organization
func (r *Repository) AddMember(orgID, userID uuid.UUID, role string) (*models.OrganizationMember, error) {
	m := &models.OrganizationMember{}
	err := r.db.QueryRow(`
		INSERT INTO organization_members (id, organization_id, user_id, role)
		VALUES (gen_random_uuid(), $1, $2, $3)
		RETURNING id, organization_id, user_id, role, joined_at
	`, orgID, userID, role).Scan(&m.ID, &m.OrganizationID, &m.UserID, &m.Role, &m.JoinedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to add member: %w", err)
	}
	return m, nil
}

// UpdateMemberRole changes a member's role
func (r *Repository) UpdateMemberRole(memberID uuid.UUID, role string) error {
	_, err := r.db.Exec(`UPDATE organization_members SET role = $2 WHERE id = $1`, memberID, role)
	return err
}

// RemoveMember removes a member from an organization
func (r *Repository) RemoveMember(memberID uuid.UUID) error {
	_, err := r.db.Exec(`DELETE FROM organization_members WHERE id = $1`, memberID)
	return err
}

// GetMemberByID returns a specific member
func (r *Repository) GetMemberByID(memberID uuid.UUID) (*models.OrganizationMember, error) {
	m := &models.OrganizationMember{}
	err := r.db.QueryRow(`
		SELECT id, organization_id, user_id, role, joined_at
		FROM organization_members WHERE id = $1
	`, memberID).Scan(&m.ID, &m.OrganizationID, &m.UserID, &m.Role, &m.JoinedAt)
	if err != nil {
		return nil, err
	}
	return m, nil
}

// FindUserByEmail finds a user by email for member invitation
func (r *Repository) FindUserByEmail(email string) (uuid.UUID, error) {
	var id uuid.UUID
	err := r.db.QueryRow(`SELECT id FROM users WHERE email = $1`, email).Scan(&id)
	return id, err
}

// ── Profile ──

// GetOrgProfile returns org profile with completion score calculated
func (r *Repository) GetOrgProfile(orgID uuid.UUID) (*models.Organizer, error) {
	org := &models.Organizer{}
	err := r.db.QueryRow(`
		SELECT id, user_id, name, description, website, phone, logo_url,
			status, rejection_reason, registration_number, organization_type,
			city, country, trust_level, profile_completion_score, contact_email,
			created_at, updated_at
		FROM organizers WHERE id = $1
	`, orgID).Scan(
		&org.ID, &org.UserID, &org.Name, &org.Description, &org.Website, &org.Phone, &org.LogoURL,
		&org.Status, &org.RejectionReason, &org.RegistrationNumber, &org.OrganizationType,
		&org.City, &org.Country, &org.TrustLevel, &org.ProfileCompletionScore, &org.ContactEmail,
		&org.CreatedAt, &org.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return org, nil
}

// UpdateOrgProfile updates organizer profile fields
func (r *Repository) UpdateOrgProfile(org *models.Organizer) error {
	_, err := r.db.Exec(`
		UPDATE organizers SET
			name=$2, description=$3, website=$4, phone=$5, logo_url=$6,
			contact_email=$7, city=$8, country=$9,
			profile_completion_score=$10
		WHERE id=$1
	`, org.ID, org.Name, org.Description, org.Website, org.Phone, org.LogoURL,
		org.ContactEmail, org.City, org.Country, org.ProfileCompletionScore)
	return err
}

// UpdateTrustLevel updates the trust level for an organizer
func (r *Repository) UpdateTrustLevel(orgID uuid.UUID, level string) error {
	_, err := r.db.Exec(`UPDATE organizers SET trust_level = $2 WHERE id = $1`, orgID, level)
	return err
}
