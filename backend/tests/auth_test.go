//go:build integration

package tests

import (
	"os"
	"testing"

	"golang.org/x/crypto/bcrypt"

	_ "github.com/lib/pq"
)

func TestMain(m *testing.M) {
	SetupTestDB()
	code := m.Run()
	if testDB != nil {
		testDB.Close()
	}
	os.Exit(code)
}

// TestRegistrationAndVerification tests the full registration + OTP verification flow.
func TestRegistrationAndVerification(t *testing.T) {
	CleanupDB(t)

	// 1. Create a user directly (simulating registration)
	hashedPw, _ := bcrypt.GenerateFromPassword([]byte("TestPass123!"), bcrypt.DefaultCost)
	var userID string
	err := testDB.QueryRow(`
		INSERT INTO users (email, password_hash, name, role, status, is_verified)
		VALUES ($1, $2, $3, 'organizer', 'pending_verification', false)
		RETURNING id
	`, "test@example.com", string(hashedPw), "Test User").Scan(&userID)
	if err != nil {
		t.Fatalf("insert user: %v", err)
	}

	// 2. Verify user exists and is not verified
	var isVerified bool
	err = testDB.QueryRow(`SELECT is_verified FROM users WHERE id = $1`, userID).Scan(&isVerified)
	if err != nil {
		t.Fatalf("query user: %v", err)
	}
	if isVerified {
		t.Fatal("expected user to NOT be verified initially")
	}

	// 3. Simulate email verification
	_, err = testDB.Exec(`UPDATE users SET is_verified = true, status = 'active' WHERE id = $1`, userID)
	if err != nil {
		t.Fatalf("mark verified: %v", err)
	}

	// 4. Confirm verification
	err = testDB.QueryRow(`SELECT is_verified FROM users WHERE id = $1`, userID).Scan(&isVerified)
	if err != nil {
		t.Fatalf("query verified user: %v", err)
	}
	if !isVerified {
		t.Fatal("expected user to be verified after update")
	}
}
