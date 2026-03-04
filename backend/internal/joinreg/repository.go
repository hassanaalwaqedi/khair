package joinreg

import (
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/khair/backend/internal/models"
)

// Repository handles database operations for minimal join registration
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new join registration repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// CheckEmailExists checks if an email is already registered
func (r *Repository) CheckEmailExists(email string) (bool, error) {
	var exists bool
	err := r.db.QueryRow("SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)", email).Scan(&exists)
	return exists, err
}

// SaveDraft saves or updates a registration draft
func (r *Repository) SaveDraft(draft *models.RegistrationDraft) error {
	_, err := r.db.Exec(`
		INSERT INTO registration_drafts (id, email, current_step, role, form_data, ip_address, expires_at, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		ON CONFLICT (email) DO UPDATE SET
			current_step = EXCLUDED.current_step,
			form_data = EXCLUDED.form_data,
			updated_at = NOW()`,
		draft.ID, draft.Email, draft.CurrentStep, draft.Role, draft.FormData,
		draft.IPAddress, draft.ExpiresAt, draft.CreatedAt, draft.UpdatedAt,
	)
	return err
}

// LoadDraft loads a registration draft by email
func (r *Repository) LoadDraft(email string) (*models.RegistrationDraft, error) {
	draft := &models.RegistrationDraft{}
	err := r.db.QueryRow(`
		SELECT id, email, current_step, role, form_data, expires_at, created_at, updated_at
		FROM registration_drafts WHERE email = $1 AND expires_at > NOW()`,
		email,
	).Scan(&draft.ID, &draft.Email, &draft.CurrentStep, &draft.Role,
		&draft.FormData, &draft.ExpiresAt, &draft.CreatedAt, &draft.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return draft, nil
}

// CreateMemberUser creates a new member user transactionally
func (r *Repository) CreateMemberUser(name, email, passwordHash, gender string, age *int, eventID *uuid.UUID) (*models.User, string, error) {
	tx, err := r.db.Begin()
	if err != nil {
		return nil, "", err
	}
	defer tx.Rollback()

	// Generate verification token
	tokenBytes := make([]byte, 32)
	if _, err := rand.Read(tokenBytes); err != nil {
		return nil, "", errors.New("failed to generate verification token")
	}
	token := hex.EncodeToString(tokenBytes)
	tokenExpiry := time.Now().Add(30 * time.Minute)

	// Hash the token with SHA256 before storing
	tokenHash := sha256Hash(token)

	user := &models.User{
		ID:           uuid.New(),
		Email:        email,
		PasswordHash: passwordHash,
		Role:         models.RoleMember,
		Status:       "pending_verification",
		DisplayName:  &name,
		Gender:       &gender,
		Age:          age,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	_, err = tx.Exec(`
		INSERT INTO users (id, email, password_hash, role, status, display_name, gender, age,
			created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		user.ID, user.Email, user.PasswordHash, user.Role, user.Status,
		user.DisplayName, user.Gender, user.Age,
		user.CreatedAt, user.UpdatedAt,
	)
	if err != nil {
		return nil, "", errors.New("failed to create user (email may already exist)")
	}

	// Store hashed verification token in email_verifications table
	_, err = tx.Exec(`
		INSERT INTO email_verifications (id, user_id, otp_hash, expires_at, attempts, last_sent_at, created_at)
		VALUES ($1, $2, $3, $4, 0, NOW(), NOW())`,
		uuid.New(), user.ID, tokenHash, tokenExpiry,
	)
	if err != nil {
		return nil, "", errors.New("failed to create verification record")
	}

	// Delete the draft
	tx.Exec("DELETE FROM registration_drafts WHERE email = $1", email)

	// Log audit event
	details, _ := json.Marshal(map[string]interface{}{
		"role": models.RoleMember, "gender": gender, "event_id": eventID,
	})
	tx.Exec(`
		INSERT INTO registration_audit_log (id, user_id, email, step, action, details, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		uuid.New(), user.ID, email, 2, "member_registration_complete", details, time.Now(),
	)

	if err := tx.Commit(); err != nil {
		return nil, "", err
	}

	// Return the raw token for email sending (not the hash)
	return user, token, nil
}

// VerifyEmailAndConfirmSeat atomically verifies email and confirms any pending seat
func (r *Repository) VerifyEmailAndConfirmSeat(token string) (*models.User, error) {
	tx, err := r.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	// Hash the submitted token to match against stored hash
	tokenHash := sha256Hash(token)

	// Find user via the verification record
	var userID uuid.UUID
	var verificationID uuid.UUID
	err = tx.QueryRow(`
		SELECT ev.id, ev.user_id FROM email_verifications ev
		WHERE ev.otp_hash = $1 AND ev.expires_at > NOW()`,
		tokenHash,
	).Scan(&verificationID, &userID)
	if err != nil {
		return nil, errors.New("invalid or expired verification token")
	}

	// Update user status
	user := &models.User{}
	err = tx.QueryRow(`
		UPDATE users SET
			status = 'active',
			is_verified = true,
			verified_at = NOW(),
			updated_at = NOW()
		WHERE id = $1
			AND verified_at IS NULL
		RETURNING id, email, role, status, display_name`,
		userID,
	).Scan(&user.ID, &user.Email, &user.Role, &user.Status, &user.DisplayName)
	if err != nil {
		return nil, errors.New("invalid or expired verification token")
	}

	// Delete verification record
	tx.Exec(`DELETE FROM email_verifications WHERE id = $1`, verificationID)

	// Confirm any pending seat reservations for this user
	tx.Exec(`
		UPDATE event_registrations SET status = 'confirmed', updated_at = NOW()
		WHERE user_id = $1 AND status = 'pending'`, user.ID)

	// Audit log
	details, _ := json.Marshal(map[string]string{"action": "email_verified_seat_confirmed"})
	tx.Exec(`
		INSERT INTO registration_audit_log (id, user_id, email, action, details, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)`,
		uuid.New(), user.ID, user.Email, "email_verified", details, time.Now(),
	)

	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return user, nil
}

// sha256Hash computes a SHA256 hex digest
func sha256Hash(s string) string {
	h := sha256.Sum256([]byte(s))
	return hex.EncodeToString(h[:])
}
