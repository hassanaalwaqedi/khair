package reminder

import (
	"database/sql"
	"log"
	"time"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/push"
	"github.com/khair/backend/pkg/email"
)

// Service handles event reminder scheduling and sending.
type Service struct {
	db       *sql.DB
	pushSvc  *push.Service
	emailSvc *email.Service
}

// NewService creates a new reminder service.
func NewService(db *sql.DB, pushSvc *push.Service, emailSvc *email.Service) *Service {
	return &Service{db: db, pushSvc: pushSvc, emailSvc: emailSvc}
}

// ProcessReminders finds events starting soon and sends reminders.
// Called by the background worker on a schedule.
func (s *Service) ProcessReminders(reminderType string, duration time.Duration) {
	// Find events starting within the window
	windowStart := time.Now()
	windowEnd := windowStart.Add(duration).Add(5 * time.Minute) // small buffer

	rows, err := s.db.Query(`
		SELECT e.id, e.title, e.start_date
		FROM events e
		WHERE e.status = 'approved' AND e.is_published = true
		  AND e.start_date >= $1 AND e.start_date <= $2
	`, windowStart, windowEnd)
	if err != nil {
		log.Printf("[REMINDER] Query error: %v", err)
		return
	}
	defer rows.Close()

	for rows.Next() {
		var eventID uuid.UUID
		var title string
		var startDate time.Time
		rows.Scan(&eventID, &title, &startDate)

		s.sendRemindersForEvent(eventID, title, startDate, reminderType)
	}
}

func (s *Service) sendRemindersForEvent(eventID uuid.UUID, title string, startDate time.Time, reminderType string) {
	// Get registered attendees who haven't received this reminder
	rows, err := s.db.Query(`
		SELECT a.user_id, u.email, u.name
		FROM attendees a
		JOIN users u ON u.id = a.user_id
		WHERE a.event_id = $1
		  AND NOT EXISTS (
			SELECT 1 FROM event_reminders er
			WHERE er.event_id = $1 AND er.user_id = a.user_id AND er.reminder_type = $2
		  )
	`, eventID, reminderType)
	if err != nil {
		log.Printf("[REMINDER] Attendee query error for event %s: %v", eventID, err)
		return
	}
	defer rows.Close()

	timeUntil := time.Until(startDate)
	var timeStr string
	if timeUntil.Hours() >= 20 {
		timeStr = "tomorrow"
	} else {
		timeStr = "in 2 hours"
	}

	for rows.Next() {
		var userID uuid.UUID
		var userEmail, userName string
		rows.Scan(&userID, &userEmail, &userName)

		// Send push notification
		if s.pushSvc != nil {
			s.pushSvc.SendToUser(userID, "Event Reminder 🔔",
				title+" starts "+timeStr,
				map[string]string{"event_id": eventID.String()})
		}

		// Mark as sent
		s.db.Exec(`
			INSERT INTO event_reminders (event_id, user_id, reminder_type)
			VALUES ($1, $2, $3)
			ON CONFLICT DO NOTHING
		`, eventID, userID, reminderType)

		log.Printf("[REMINDER] Sent %s reminder for event %s to user %s", reminderType, eventID, userID)
	}
}
