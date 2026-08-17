package orgdash

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/khair/backend/internal/models"
)

// ErrOrganizerAccess is deliberately returned for both missing and unapproved
// organizer profiles. The HTTP layer exposes neither distinction to callers.
var ErrOrganizerAccess = errors.New("approved organizer access is required")

// HubDashboard is the one real aggregate used by the organizer landing page.
// It is intentionally scoped by the authenticated user, never a client-supplied
// organization id.
type HubDashboard struct {
	Organizer   HubOrganizer       `json:"organizer"`
	Range       HubRange           `json:"range"`
	Metrics     HubMetrics         `json:"metrics"`
	NextEvent   *HubEvent          `json:"next_event,omitempty"`
	Events      HubEventGroups     `json:"events"`
	Attention   []HubAttentionItem `json:"attention"`
	Performance []HubTrendPoint    `json:"performance"`
	Activity    []HubActivityItem  `json:"activity"`
}

type HubOrganizer struct {
	ID      uuid.UUID `json:"id"`
	Name    string    `json:"name"`
	LogoURL *string   `json:"logo_url,omitempty"`
	Status  string    `json:"status"`
	Trust   string    `json:"trust_level"`
}

type HubRange struct {
	Key   string    `json:"key"`
	Start time.Time `json:"start"`
	End   time.Time `json:"end"`
}

type HubMetrics struct {
	UpcomingEvents int      `json:"upcoming_events"`
	TotalAttendees int      `json:"total_attendees"`
	EventViews     int      `json:"event_views"`
	JoinRate       float64  `json:"join_rate"`
	AttendeeChange *float64 `json:"attendee_change,omitempty"`
	ViewChange     *float64 `json:"view_change,omitempty"`
	JoinRateChange *float64 `json:"join_rate_change,omitempty"`
}

type HubEvent struct {
	ID        uuid.UUID  `json:"id"`
	Title     string     `json:"title"`
	Status    string     `json:"status"`
	StartDate time.Time  `json:"start_date"`
	EndDate   *time.Time `json:"end_date,omitempty"`
	ImageURL  *string    `json:"image_url,omitempty"`
	City      *string    `json:"city,omitempty"`
	Address   *string    `json:"address,omitempty"`
	IsOnline  bool       `json:"is_online"`
	Capacity  *int       `json:"capacity,omitempty"`
	Attendees       int                  `json:"attendees"`
	Views           int                  `json:"views"`
	AttendeePreview []HubAttendeePreview `json:"attendee_preview,omitempty"`
}

type HubAttendeePreview struct {
	DisplayName string  `json:"display_name"`
	AvatarURL   *string `json:"avatar_url,omitempty"`
}

type HubEventGroups struct {
	Upcoming []HubEvent `json:"upcoming"`
	Drafts   []HubEvent `json:"drafts"`
	Past     []HubEvent `json:"past"`
}

type HubAttentionItem struct {
	ID          string     `json:"id"`
	Type        string     `json:"type"`
	Severity    string     `json:"severity"`
	Title       string     `json:"title"`
	Detail      string     `json:"detail"`
	EventID     *uuid.UUID `json:"event_id,omitempty"`
	Action      string     `json:"action"`
	ActionRoute string     `json:"action_route"`
}

type HubTrendPoint struct {
	Date      string `json:"date"`
	Views     int    `json:"views"`
	Attendees int    `json:"attendees"`
}

type HubActivityItem struct {
	ID        string     `json:"id"`
	Type      string     `json:"type"`
	Title     string     `json:"title"`
	Detail    string     `json:"detail"`
	CreatedAt time.Time  `json:"created_at"`
	EventID   *uuid.UUID `json:"event_id,omitempty"`
}

// HubRangeWindow validates the explicit presets accepted by the API. A custom
// range is allowed only when both parsed timestamps form a bounded interval.
func HubRangeWindow(key, startParam, endParam string, now time.Time) (HubRange, time.Time, time.Time, error) {
	now = now.UTC()
	end := now
	start := now.AddDate(0, 0, -30)
	switch key {
	case "", "30d":
		key = "30d"
	case "7d":
		start = now.AddDate(0, 0, -7)
	case "this_month":
		start = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	case "last_month":
		end = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
		start = end.AddDate(0, -1, 0)
	case "custom":
		var err error
		start, err = time.Parse(time.RFC3339, startParam)
		if err != nil {
			return HubRange{}, time.Time{}, time.Time{}, errors.New("custom range requires start in RFC3339 format")
		}
		end, err = time.Parse(time.RFC3339, endParam)
		if err != nil {
			return HubRange{}, time.Time{}, time.Time{}, errors.New("custom range requires end in RFC3339 format")
		}
		start, end = start.UTC(), end.UTC()
		if !end.After(start) || end.Sub(start) > 366*24*time.Hour {
			return HubRange{}, time.Time{}, time.Time{}, errors.New("custom range must be positive and at most 366 days")
		}
	default:
		return HubRange{}, time.Time{}, time.Time{}, errors.New("unsupported dashboard range")
	}
	previousEnd := start
	previousStart := start.Add(-end.Sub(start))
	return HubRange{Key: key, Start: start, End: end}, previousStart, previousEnd, nil
}

// GetHubDashboard returns a non-mocked overview for an approved organizer.
func (s *Service) GetHubDashboard(userID uuid.UUID, key, startParam, endParam string) (*HubDashboard, error) {
	org, err := s.repo.GetApprovedOrganizerByUser(userID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrOrganizerAccess
		}
		return nil, err
	}
	rangeValue, previousStart, previousEnd, err := HubRangeWindow(key, startParam, endParam, time.Now())
	if err != nil {
		return nil, err
	}
	metrics, err := s.repo.GetHubMetrics(org.ID, rangeValue.Start, rangeValue.End, previousStart, previousEnd)
	if err != nil {
		return nil, err
	}
	next, err := s.repo.GetHubNextEvent(org.ID)
	if err != nil {
		return nil, err
	}
	events, err := s.repo.GetHubEventGroups(org.ID)
	if err != nil {
		return nil, err
	}
	attention, err := s.repo.GetHubAttention(org.ID)
	if err != nil {
		return nil, err
	}
	performance, err := s.repo.GetHubPerformance(org.ID, rangeValue.Start, rangeValue.End)
	if err != nil {
		return nil, err
	}
	activity, err := s.repo.GetHubActivity(org.ID)
	if err != nil {
		return nil, err
	}
	return &HubDashboard{
		Organizer: HubOrganizer{ID: org.ID, Name: org.Name, LogoURL: org.LogoURL, Status: org.Status, Trust: org.TrustLevel},
		Range:     rangeValue, Metrics: *metrics, NextEvent: next, Events: *events,
		Attention: attention, Performance: performance, Activity: activity,
	}, nil
}

// AuthorizeOrganization secures old org-id based routes while the new hub uses
// the more restrictive self-scoped dashboard endpoint. Administrators retain
// operational access; all other callers need an approved owner/member role.
func (s *Service) AuthorizeOrganization(userID, orgID uuid.UUID, globalRole string) (string, error) {
	if globalRole == models.RoleAdmin || globalRole == "super_admin" {
		return models.OrgRoleAdmin, nil
	}
	return s.repo.GetOrganizationRole(userID, orgID)
}

func (r *Repository) GetApprovedOrganizerByUser(userID uuid.UUID) (*models.Organizer, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	org := &models.Organizer{}
	err := r.db.QueryRowContext(ctx, `SELECT id, user_id, name, logo_url, status, trust_level
		FROM organizers WHERE user_id = $1 AND status = 'approved'`, userID).
		Scan(&org.ID, &org.UserID, &org.Name, &org.LogoURL, &org.Status, &org.TrustLevel)
	return org, err
}

func (r *Repository) GetOrganizationRole(userID, orgID uuid.UUID) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	var ownerID uuid.UUID
	var status string
	if err := r.db.QueryRowContext(ctx, `SELECT user_id, status FROM organizers WHERE id = $1`, orgID).Scan(&ownerID, &status); err != nil {
		return "", err
	}
	if status != "approved" {
		return "", ErrOrganizerAccess
	}
	if ownerID == userID {
		return models.OrgRoleOwner, nil
	}
	var role string
	err := r.db.QueryRowContext(ctx, `SELECT role FROM organization_members WHERE organization_id = $1 AND user_id = $2`, orgID, userID).Scan(&role)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrOrganizerAccess
	}
	return role, err
}

func (r *Repository) GetHubMetrics(orgID uuid.UUID, start, end, previousStart, previousEnd time.Time) (*HubMetrics, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	m := &HubMetrics{}
	var currentAttendees, previousAttendees, currentViews, previousViews int
	err := r.db.QueryRowContext(ctx, `
		SELECT
		 (SELECT COUNT(*) FROM events
		  WHERE organizer_id = $1
		    AND status IN ('approved', 'published')
		    AND is_published = true
		    AND start_date >= NOW()),
		 (SELECT COUNT(DISTINCT er.user_id) FROM event_registrations er
		  JOIN events e ON e.id=er.event_id
		  WHERE e.organizer_id=$1 AND e.status IN ('approved', 'published')
		    AND e.is_published = true AND er.status='confirmed'
		    AND er.created_at >= $2 AND er.created_at < $3),
		 (SELECT COUNT(DISTINCT er.user_id) FROM event_registrations er
		  JOIN events e ON e.id=er.event_id
		  WHERE e.organizer_id=$1 AND e.status IN ('approved', 'published')
		    AND e.is_published = true AND er.status='confirmed'
		    AND er.created_at >= $4 AND er.created_at < $5),
		 (SELECT COUNT(DISTINCT (CASE WHEN ev.viewer_user_id IS NOT NULL
		  THEN ev.viewer_user_id::text ELSE ev.session_id END))
		  FROM event_views ev JOIN events e ON e.id=ev.event_id
		  WHERE e.organizer_id=$1 AND e.status IN ('approved', 'published')
		    AND e.is_published = true AND ev.created_at >= $2 AND ev.created_at < $3),
		 (SELECT COUNT(DISTINCT (CASE WHEN ev.viewer_user_id IS NOT NULL
		  THEN ev.viewer_user_id::text ELSE ev.session_id END))
		  FROM event_views ev JOIN events e ON e.id=ev.event_id
		  WHERE e.organizer_id=$1 AND e.status IN ('approved', 'published')
		    AND e.is_published = true AND ev.created_at >= $4 AND ev.created_at < $5)`,
		orgID, start, end, previousStart, previousEnd).Scan(&m.UpcomingEvents, &currentAttendees, &previousAttendees, &currentViews, &previousViews)
	if err != nil {
		return nil, fmt.Errorf("load hub metrics: %w", err)
	}
	m.TotalAttendees, m.EventViews = currentAttendees, currentViews
	m.JoinRate = rate(currentAttendees, currentViews)
	m.AttendeeChange = percentageChange(currentAttendees, previousAttendees)
	m.ViewChange = percentageChange(currentViews, previousViews)
	m.JoinRateChange = percentageChangeFloat(m.JoinRate, rate(previousAttendees, previousViews))
	return m, nil
}

func percentageChange(current, previous int) *float64 {
	return percentageChangeFloat(float64(current), float64(previous))
}
func percentageChangeFloat(current, previous float64) *float64 {
	if previous == 0 {
		if current == 0 {
			value := 0.0
			return &value
		}
		return nil
	}
	value := (current - previous) / previous * 100
	return &value
}
func rate(attendees, views int) float64 {
	if views == 0 {
		return 0
	}
	return float64(attendees) / float64(views) * 100
}

func (r *Repository) GetHubNextEvent(orgID uuid.UUID) (*HubEvent, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	e, err := r.scanHubEvent(r.db.QueryRowContext(ctx, hubEventQuery+` WHERE e.organizer_id=$1 AND e.status IN ('approved','published') AND e.is_published = true AND e.start_date >= NOW() ORDER BY e.start_date LIMIT 1`, orgID))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return e, err
}

const hubEventQuery = `SELECT e.id,e.title,e.status,e.start_date,e.end_date,e.image_url,e.city,e.address,e.is_online,e.capacity,
	COALESCE((SELECT COUNT(DISTINCT er.user_id) FROM event_registrations er WHERE er.event_id=e.id AND er.status='confirmed'),0),
	COALESCE((SELECT COUNT(DISTINCT (CASE WHEN ev.viewer_user_id IS NOT NULL THEN ev.viewer_user_id::text ELSE ev.session_id END)) FROM event_views ev WHERE ev.event_id=e.id),0),
	COALESCE((
		SELECT json_agg(json_build_object('display_name', COALESCE(t.display_name, 'Anonymous'), 'avatar_url', t.avatar_url))
		FROM (
			SELECT u.display_name, p.avatar_url
			FROM event_registrations er
			JOIN users u ON u.id = er.user_id
			LEFT JOIN profiles p ON p.user_id = er.user_id
			WHERE er.event_id=e.id AND er.status='confirmed'
			ORDER BY er.created_at ASC
			LIMIT 4
		) t
	), '[]'::json) FROM events e`

type rowScanner interface{ Scan(...interface{}) error }

func (r *Repository) scanHubEvent(row rowScanner) (*HubEvent, error) {
	e := &HubEvent{}
	var previewJSON []byte
	err := row.Scan(&e.ID, &e.Title, &e.Status, &e.StartDate, &e.EndDate, &e.ImageURL, &e.City, &e.Address, &e.IsOnline, &e.Capacity, &e.Attendees, &e.Views, &previewJSON)
	if err == nil && len(previewJSON) > 0 {
		importJsonError := false
		if err := json.Unmarshal(previewJSON, &e.AttendeePreview); err != nil {
			importJsonError = true
		}
		_ = importJsonError
	}
	return e, err
}

func (r *Repository) GetHubEventGroups(orgID uuid.UUID) (*HubEventGroups, error) {
	groups := &HubEventGroups{Upcoming: []HubEvent{}, Drafts: []HubEvent{}, Past: []HubEvent{}}
	load := func(clause string, target *[]HubEvent) error {
		ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
		defer cancel()
		rows, err := r.db.QueryContext(ctx, hubEventQuery+" WHERE e.organizer_id=$1 AND "+clause+" LIMIT 8", orgID)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			e, scanErr := r.scanHubEvent(rows)
			if scanErr != nil {
				return scanErr
			}
			*target = append(*target, *e)
		}
		return rows.Err()
	}
	if err := load("e.status IN ('approved','published') AND e.is_published = true AND e.start_date >= NOW() ORDER BY e.start_date ASC", &groups.Upcoming); err != nil {
		return nil, err
	}
	if err := load("e.status IN ('draft','pending','needs_revision','rejected') ORDER BY e.updated_at DESC", &groups.Drafts); err != nil {
		return nil, err
	}
	if err := load("e.status IN ('approved','published') AND e.is_published = true AND e.start_date < NOW() ORDER BY e.start_date DESC", &groups.Past); err != nil {
		return nil, err
	}
	return groups, nil
}

func (r *Repository) GetHubAttention(orgID uuid.UUID) ([]HubAttentionItem, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()
	rows, err := r.db.QueryContext(ctx, `SELECT id,title,status,COALESCE(rejection_reason,''),start_date,
		image_url,city,address,is_online,online_link,capacity,reserved_count
		FROM events WHERE organizer_id=$1 AND status NOT IN ('draft')
		ORDER BY start_date ASC LIMIT 32`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []HubAttentionItem{}
	for rows.Next() {
		var id uuid.UUID
		var title, status, reason string
		var start time.Time
		var capacity *int
		var imageURL, city, address, onlineLink *string
		var isOnline bool
		var reserved int
		if err := rows.Scan(&id, &title, &status, &reason, &start, &imageURL, &city, &address, &isOnline, &onlineLink, &capacity, &reserved); err != nil {
			return nil, err
		}
		add := func(kind, severity, itemTitle, detail, action string) {
			items = append(items, HubAttentionItem{
				ID: "event:" + id.String() + ":" + kind, Type: kind, Severity: severity,
				Title: itemTitle, Detail: detail, EventID: &id, Action: action,
				ActionRoute: "/organizer/events",
			})
		}
		switch status {
		case "rejected", "needs_revision":
			add("needs_revision", "urgent", "Event needs changes", title+detailSuffix(reason), "manage_event")
		case "pending":
			add("awaiting_approval", "warning", "Event is awaiting review", title, "manage_event")
		}
		if status == "approved" || status == "published" {
			if imageURL == nil || strings.TrimSpace(*imageURL) == "" {
				add("missing_image", "warning", "Add an event image", title, "manage_event")
			}
			if isOnline {
				if onlineLink == nil || strings.TrimSpace(*onlineLink) == "" {
					add("missing_online_link", "urgent", "Add your online meeting link", title, "manage_event")
				}
			} else if (city == nil || strings.TrimSpace(*city) == "") && (address == nil || strings.TrimSpace(*address) == "") {
				add("missing_venue", "warning", "Add a venue", title, "manage_event")
			}
			until := time.Until(start)
			if until >= 0 && until <= 24*time.Hour {
				if reserved == 0 {
					add("no_attendees", "urgent", "Your event starts soon", fmt.Sprintf("%s has no confirmed attendees yet", title), "manage_event")
				} else {
					add("starting_soon", "info", "Your event starts soon", title, "send_update")
				}
			}
			if capacity != nil && *capacity > 0 && float64(reserved)/float64(*capacity) >= 0.8 {
				add("capacity_near_full", "warning", "Event is nearly full", fmt.Sprintf("%s has %d confirmed attendees", title, reserved), "attendees")
			}
		}
	}
	severityRank := map[string]int{"urgent": 0, "warning": 1, "info": 2}
	sort.SliceStable(items, func(i, j int) bool { return severityRank[items[i].Severity] < severityRank[items[j].Severity] })
	if len(items) > 8 {
		items = items[:8]
	}
	return items, rows.Err()
}
func detailSuffix(value string) string {
	if strings.TrimSpace(value) == "" {
		return ""
	}
	return ": " + value
}

func (r *Repository) GetHubPerformance(orgID uuid.UUID, start, end time.Time) ([]HubTrendPoint, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	rows, err := r.db.QueryContext(ctx, `SELECT d.day::date,
		COALESCE((SELECT COUNT(DISTINCT (CASE WHEN ev.viewer_user_id IS NOT NULL THEN ev.viewer_user_id::text ELSE ev.session_id END))
		 FROM event_views ev JOIN events e ON e.id=ev.event_id
		 WHERE e.organizer_id=$1 AND e.status IN ('approved','published') AND e.is_published = true
		   AND ev.created_at>=d.day AND ev.created_at<d.day+INTERVAL '1 day'),0),
		COALESCE((SELECT COUNT(DISTINCT er.user_id)
		 FROM event_registrations er JOIN events e ON e.id=er.event_id
		 WHERE e.organizer_id=$1 AND e.status IN ('approved','published') AND e.is_published = true
		   AND er.status='confirmed' AND er.created_at>=d.day AND er.created_at<d.day+INTERVAL '1 day'),0)
		FROM generate_series($2::timestamptz::date,$3::timestamptz::date,INTERVAL '1 day') d(day) ORDER BY d.day`, orgID, start, end)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	points := []HubTrendPoint{}
	for rows.Next() {
		var date time.Time
		var p HubTrendPoint
		if err := rows.Scan(&date, &p.Views, &p.Attendees); err != nil {
			return nil, err
		}
		p.Date = date.Format("2006-01-02")
		points = append(points, p)
	}
	return points, rows.Err()
}

func (r *Repository) GetHubActivity(orgID uuid.UUID) ([]HubActivityItem, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()
	rows, err := r.db.QueryContext(ctx, `SELECT id::text,type,title,detail,created_at,event_id FROM (
		SELECT oal.id,oal.action AS type,COALESCE(oal.metadata->>'title',oal.action) AS title,COALESCE(oal.actor_email,'') AS detail,oal.created_at,oal.target_id AS event_id
		FROM (SELECT l.id,l.action,l.metadata,l.created_at,l.target_id,u.email AS actor_email FROM org_audit_logs l LEFT JOIN users u ON u.id=l.actor_id WHERE l.organization_id=$1) oal
		UNION ALL
		SELECT er.id,'attendee_joined',e.title,COALESCE(u.display_name,u.email,''),er.created_at,er.event_id FROM event_registrations er JOIN events e ON e.id=er.event_id JOIN users u ON u.id=er.user_id WHERE e.organizer_id=$1 AND er.status='confirmed'
		UNION ALL
		SELECT ea.id,'announcement_sent',COALESCE(ea.title,'Event update'),e.title,ea.created_at,ea.event_id FROM event_announcements ea JOIN events e ON e.id=ea.event_id WHERE e.organizer_id=$1
		) activity ORDER BY created_at DESC LIMIT 12`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []HubActivityItem{}
	for rows.Next() {
		var item HubActivityItem
		if err := rows.Scan(&item.ID, &item.Type, &item.Title, &item.Detail, &item.CreatedAt, &item.EventID); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}
