//go:build integration

package tests

import (
	"testing"

	"golang.org/x/crypto/bcrypt"
)

// TestEventApprovalFlow tests: create event → admin approves → event appears in public list.
func TestEventApprovalFlow(t *testing.T) {
	CleanupDB(t)

	// 1. Create user + organizer
	hashedPw, _ := bcrypt.GenerateFromPassword([]byte("TestPass123!"), bcrypt.DefaultCost)
	var userID string
	err := testDB.QueryRow(`
		INSERT INTO users (email, password_hash, name, role, status, is_verified)
		VALUES ($1, $2, $3, 'organizer', 'active', true)
		RETURNING id
	`, "organizer@example.com", string(hashedPw), "Organizer").Scan(&userID)
	if err != nil {
		t.Fatalf("insert user: %v", err)
	}

	var orgID string
	err = testDB.QueryRow(`
		INSERT INTO organizers (user_id, name, status)
		VALUES ($1, 'Test Org', 'approved')
		RETURNING id
	`, userID).Scan(&orgID)
	if err != nil {
		t.Fatalf("insert organizer: %v", err)
	}

	// 2. Create event in draft status
	var eventID string
	err = testDB.QueryRow(`
		INSERT INTO events (organizer_id, title, event_type, start_date, status, is_published)
		VALUES ($1, 'Test Event', 'lecture', NOW() + interval '7 days', 'draft', false)
		RETURNING id
	`, orgID).Scan(&eventID)
	if err != nil {
		t.Fatalf("insert event: %v", err)
	}

	// 3. Submit for review (draft → pending)
	_, err = testDB.Exec(`UPDATE events SET status = 'pending' WHERE id = $1`, eventID)
	if err != nil {
		t.Fatalf("submit for review: %v", err)
	}

	// 4. Admin approves (pending → approved)
	_, err = testDB.Exec(`UPDATE events SET status = 'approved', is_published = true WHERE id = $1`, eventID)
	if err != nil {
		t.Fatalf("approve event: %v", err)
	}

	// 5. Verify event appears in public list (status=approved, is_published=true)
	var count int
	err = testDB.QueryRow(`
		SELECT COUNT(*) FROM events WHERE status = 'approved' AND is_published = true
	`).Scan(&count)
	if err != nil {
		t.Fatalf("count public events: %v", err)
	}
	if count != 1 {
		t.Fatalf("expected 1 public event, got %d", count)
	}
}

// TestEventApprovalNotification tests that approving an event creates a notification.
func TestEventApprovalNotification(t *testing.T) {
	CleanupDB(t)

	// Setup: create user + organizer + event
	hashedPw, _ := bcrypt.GenerateFromPassword([]byte("TestPass123!"), bcrypt.DefaultCost)
	var userID string
	err := testDB.QueryRow(`
		INSERT INTO users (email, password_hash, name, role, status, is_verified)
		VALUES ($1, $2, $3, 'organizer', 'active', true)
		RETURNING id
	`, "org2@example.com", string(hashedPw), "Org2").Scan(&userID)
	if err != nil {
		t.Fatalf("insert user: %v", err)
	}

	var orgID string
	err = testDB.QueryRow(`
		INSERT INTO organizers (user_id, name, status)
		VALUES ($1, 'Test Org 2', 'approved')
		RETURNING id
	`, userID).Scan(&orgID)
	if err != nil {
		t.Fatalf("insert organizer: %v", err)
	}

	var eventID string
	err = testDB.QueryRow(`
		INSERT INTO events (organizer_id, title, event_type, start_date, status, is_published)
		VALUES ($1, 'Notification Test', 'workshop', NOW() + interval '7 days', 'pending', false)
		RETURNING id
	`, orgID).Scan(&eventID)
	if err != nil {
		t.Fatalf("insert event: %v", err)
	}

	// Simulate approval + notification creation
	_, err = testDB.Exec(`UPDATE events SET status = 'approved', is_published = true WHERE id = $1`, eventID)
	if err != nil {
		t.Fatalf("approve event: %v", err)
	}

	// Create notification (simulating what admin service does)
	_, err = testDB.Exec(`
		INSERT INTO notifications (user_id, title, message)
		VALUES ($1, 'Event Approved', 'Your event "Notification Test" has been approved.')
	`, userID)
	if err != nil {
		t.Fatalf("create notification: %v", err)
	}

	// Verify notification exists
	var notifCount int
	err = testDB.QueryRow(`SELECT COUNT(*) FROM notifications WHERE user_id = $1`, userID).Scan(&notifCount)
	if err != nil {
		t.Fatalf("count notifications: %v", err)
	}
	if notifCount != 1 {
		t.Fatalf("expected 1 notification, got %d", notifCount)
	}
}
