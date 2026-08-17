package orgdash

import (
	"fmt"
	"time"

	"github.com/google/uuid"
)

type EventAttendee struct {
	UserID      uuid.UUID `json:"user_id"`
	DisplayName string    `json:"display_name"`
	AvatarURL   *string   `json:"avatar_url,omitempty"`
	Status      string    `json:"status"`
	JoinedAt    time.Time `json:"joined_at"`
}

type EventAttendeesResponse struct {
	EventID   uuid.UUID       `json:"event_id"`
	Total     int64           `json:"total"`
	Attendees []EventAttendee `json:"attendees"`
}

func (r *Repository) GetEventAttendees(orgID, eventID uuid.UUID, page, pageSize int, search string) (*EventAttendeesResponse, error) {
	// Security check: ensure event belongs to this org
	var count int
	err := r.db.QueryRow("SELECT COUNT(*) FROM events WHERE id=$1 AND organizer_id=$2", eventID, orgID).Scan(&count)
	if err != nil || count == 0 {
		return nil, fmt.Errorf("event not found or access denied")
	}

	offset := (page - 1) * pageSize
	if offset < 0 {
		offset = 0
	}

	searchCondition := ""
	args := []interface{}{eventID}
	argIdx := 2
	if search != "" {
		searchCondition = fmt.Sprintf(" AND u.display_name ILIKE $%d", argIdx)
		args = append(args, "%"+search+"%")
		argIdx++
	}

	countQuery := fmt.Sprintf(`
		SELECT COUNT(*) 
		FROM event_registrations er
		JOIN users u ON u.id = er.user_id
		WHERE er.event_id = $1 AND er.status = 'confirmed'%s
	`, searchCondition)
	
	var total int64
	if err := r.db.QueryRow(countQuery, args...).Scan(&total); err != nil {
		return nil, fmt.Errorf("failed to count attendees: %w", err)
	}

	args = append(args, pageSize, offset)
	query := fmt.Sprintf(`
		SELECT er.user_id, COALESCE(u.display_name, 'Anonymous'), p.avatar_url, er.status, er.created_at
		FROM event_registrations er
		JOIN users u ON u.id = er.user_id
		LEFT JOIN profiles p ON p.user_id = er.user_id
		WHERE er.event_id = $1 AND er.status = 'confirmed'%s
		ORDER BY er.created_at DESC
		LIMIT $%d OFFSET $%d
	`, searchCondition, argIdx, argIdx+1)

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch attendees: %w", err)
	}
	defer rows.Close()

	resp := &EventAttendeesResponse{
		EventID:   eventID,
		Total:     total,
		Attendees: []EventAttendee{},
	}

	for rows.Next() {
		var a EventAttendee
		if err := rows.Scan(&a.UserID, &a.DisplayName, &a.AvatarURL, &a.Status, &a.JoinedAt); err != nil {
			return nil, err
		}
		resp.Attendees = append(resp.Attendees, a)
	}

	return resp, nil
}
