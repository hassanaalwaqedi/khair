package auth

import (
	"database/sql"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
)

// Repository handles database operations for auth
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new auth repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// EmailVerification represents a record in the email_verifications table
type EmailVerification struct {
	ID         uuid.UUID
	UserID     uuid.UUID
	OTPHash    string
	ExpiresAt  time.Time
	Attempts   int
	LastSentAt time.Time
	CreatedAt  time.Time
}

// ── User Operations ──

// CreateUser creates a new user
func (r *Repository) CreateUser(user *models.User) error {
	query := `
		INSERT INTO users (id, email, password_hash, role, status, is_verified, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`
	_, err := r.db.Exec(query,
		user.ID, user.Email, user.PasswordHash, user.Role,
		user.Status, user.IsVerified,
		user.CreatedAt, user.UpdatedAt,
	)
	return err
}

// GetUserByEmail retrieves a user by email
func (r *Repository) GetUserByEmail(email string) (*models.User, error) {
	query := `
		SELECT id, email, password_hash, role, status, is_verified,
		       verified_at, created_at, updated_at
		FROM users WHERE email = $1
	`
	user := &models.User{}
	err := r.db.QueryRow(query, email).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.Role, &user.Status,
		&user.IsVerified, &user.VerifiedAt,
		&user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return user, nil
}

// GetUserByID retrieves a user by ID
func (r *Repository) GetUserByID(id uuid.UUID) (*models.User, error) {
	query := `
		SELECT id, email, password_hash, role, status, is_verified,
		       verified_at, created_at, updated_at
		FROM users WHERE id = $1
	`
	user := &models.User{}
	err := r.db.QueryRow(query, id).Scan(
		&user.ID, &user.Email, &user.PasswordHash, &user.Role, &user.Status,
		&user.IsVerified, &user.VerifiedAt, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return user, nil
}

// MarkEmailVerified sets is_verified = true, status = 'active', clears verification record
func (r *Repository) MarkEmailVerified(email string) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Update user
	result, err := tx.Exec(`
		UPDATE users
		SET is_verified = TRUE, verified_at = NOW(), status = 'active', updated_at = NOW()
		WHERE email = $1
	`, email)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return sql.ErrNoRows
	}

	// Delete verification record
	_, err = tx.Exec(`
		DELETE FROM email_verifications
		WHERE user_id = (SELECT id FROM users WHERE email = $1)
	`, email)
	if err != nil {
		return err
	}

	return tx.Commit()
}

// ── Email Verification Operations ──

// CreateVerification inserts a new verification record, replacing any existing one
func (r *Repository) CreateVerification(userID uuid.UUID, otpHash string, expiresAt time.Time) error {
	// Delete any existing verification for this user
	_, _ = r.db.Exec(`DELETE FROM email_verifications WHERE user_id = $1`, userID)

	query := `
		INSERT INTO email_verifications (id, user_id, otp_hash, expires_at, attempts, last_sent_at, created_at)
		VALUES ($1, $2, $3, $4, 0, NOW(), NOW())
	`
	_, err := r.db.Exec(query, uuid.New(), userID, otpHash, expiresAt)
	return err
}

// GetVerification fetches the verification record for a user by email
func (r *Repository) GetVerification(email string) (*EmailVerification, error) {
	query := `
		SELECT ev.id, ev.user_id, ev.otp_hash, ev.expires_at, ev.attempts, ev.last_sent_at, ev.created_at
		FROM email_verifications ev
		JOIN users u ON u.id = ev.user_id
		WHERE u.email = $1
	`
	v := &EmailVerification{}
	err := r.db.QueryRow(query, email).Scan(
		&v.ID, &v.UserID, &v.OTPHash, &v.ExpiresAt, &v.Attempts, &v.LastSentAt, &v.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return v, nil
}

// IncrementAttempts bumps the attempt counter for a verification record
func (r *Repository) IncrementAttempts(verificationID uuid.UUID) error {
	_, err := r.db.Exec(`
		UPDATE email_verifications SET attempts = attempts + 1 WHERE id = $1
	`, verificationID)
	return err
}

// UpdateVerification replaces the OTP hash and resets state for a resend
func (r *Repository) UpdateVerification(userID uuid.UUID, otpHash string, expiresAt time.Time) error {
	result, err := r.db.Exec(`
		UPDATE email_verifications
		SET otp_hash = $1, expires_at = $2, attempts = 0, last_sent_at = NOW()
		WHERE user_id = $3
	`, otpHash, expiresAt, userID)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		// No existing record — create one
		return r.CreateVerification(userID, otpHash, expiresAt)
	}
	return nil
}

// ── Organizer Operations ──

// CreateOrganizer creates a new organizer profile
func (r *Repository) CreateOrganizer(organizer *models.Organizer) error {
	query := `
		INSERT INTO organizers (id, user_id, name, description, website, phone, logo_url, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`
	_, err := r.db.Exec(query,
		organizer.ID, organizer.UserID, organizer.Name, organizer.Description,
		organizer.Website, organizer.Phone, organizer.LogoURL, organizer.Status,
		organizer.CreatedAt, organizer.UpdatedAt,
	)
	return err
}

// GetOrganizerByUserID retrieves an organizer by user ID
func (r *Repository) GetOrganizerByUserID(userID uuid.UUID) (*models.Organizer, error) {
	query := `
		SELECT id, user_id, name, description, website, phone, logo_url, status, rejection_reason, created_at, updated_at
		FROM organizers WHERE user_id = $1
	`
	org := &models.Organizer{}
	err := r.db.QueryRow(query, userID).Scan(
		&org.ID, &org.UserID, &org.Name, &org.Description, &org.Website,
		&org.Phone, &org.LogoURL, &org.Status, &org.RejectionReason, &org.CreatedAt, &org.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return org, nil
}

// ── Refresh Token Operations ──

// RefreshToken represents a refresh token record
type RefreshToken struct {
	ID         uuid.UUID
	UserID     uuid.UUID
	TokenHash  string
	ExpiresAt  time.Time
	CreatedAt  time.Time
	RevokedAt  *time.Time
	ReplacedBy *uuid.UUID
	UserAgent  string
	IPAddress  string
}

// CreateRefreshToken stores a new refresh token
func (r *Repository) CreateRefreshToken(rt *RefreshToken) error {
	query := `
		INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at, created_at, user_agent, ip_address)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err := r.db.Exec(query, rt.ID, rt.UserID, rt.TokenHash, rt.ExpiresAt, rt.CreatedAt, rt.UserAgent, rt.IPAddress)
	return err
}

// GetRefreshToken retrieves a refresh token by its hash
func (r *Repository) GetRefreshToken(tokenHash string) (*RefreshToken, error) {
	query := `
		SELECT id, user_id, token_hash, expires_at, created_at, revoked_at, replaced_by, user_agent, ip_address
		FROM refresh_tokens WHERE token_hash = $1
	`
	rt := &RefreshToken{}
	err := r.db.QueryRow(query, tokenHash).Scan(
		&rt.ID, &rt.UserID, &rt.TokenHash, &rt.ExpiresAt, &rt.CreatedAt,
		&rt.RevokedAt, &rt.ReplacedBy, &rt.UserAgent, &rt.IPAddress,
	)
	if err != nil {
		return nil, err
	}
	return rt, nil
}

// RevokeRefreshToken marks a refresh token as revoked and sets its replacement
func (r *Repository) RevokeRefreshToken(tokenID uuid.UUID, replacedBy *uuid.UUID) error {
	query := `UPDATE refresh_tokens SET revoked_at = NOW(), replaced_by = $1 WHERE id = $2`
	_, err := r.db.Exec(query, replacedBy, tokenID)
	return err
}

// RevokeAllUserTokens revokes all refresh tokens for a user (logout everywhere)
func (r *Repository) RevokeAllUserTokens(userID uuid.UUID) error {
	query := `UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = $1 AND revoked_at IS NULL`
	_, err := r.db.Exec(query, userID)
	return err
}

// ── Delete Unverified User ──

// DeleteUnverifiedUser removes an unverified user and all related records.
// This allows the email to be re-registered. Safety: only deletes if is_verified = false.
func (r *Repository) DeleteUnverifiedUser(userID uuid.UUID) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Delete email verifications
	_, _ = tx.Exec(`DELETE FROM email_verifications WHERE user_id = $1`, userID)
	// Delete organizer profile
	_, _ = tx.Exec(`DELETE FROM organizers WHERE user_id = $1`, userID)
	// Delete refresh tokens
	_, _ = tx.Exec(`DELETE FROM refresh_tokens WHERE user_id = $1`, userID)
	// Delete user ONLY if unverified (safety check)
	result, err := tx.Exec(`DELETE FROM users WHERE id = $1 AND is_verified = false`, userID)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return errors.New("user is already verified, cannot delete")
	}

	return tx.Commit()
}

// ── User Management Operations ──

// SuspendUser suspends a user account
func (r *Repository) SuspendUser(userID uuid.UUID, reason string, suspendedBy uuid.UUID) error {
	query := `
		UPDATE users SET status = 'suspended', suspended_at = NOW(),
		suspended_reason = $1, suspended_by = $2, updated_at = NOW()
		WHERE id = $3
	`
	_, err := r.db.Exec(query, reason, suspendedBy, userID)
	return err
}

// UnsuspendUser removes suspension from a user
func (r *Repository) UnsuspendUser(userID uuid.UUID) error {
	query := `
		UPDATE users SET status = 'active', suspended_at = NULL,
		suspended_reason = NULL, suspended_by = NULL, updated_at = NOW()
		WHERE id = $1
	`
	_, err := r.db.Exec(query, userID)
	return err
}

// SoftDeleteUser marks user as deleted (GDPR)
func (r *Repository) SoftDeleteUser(userID uuid.UUID) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Anonymize PII
	_, err = tx.Exec(`
		UPDATE users SET
			email = 'deleted_' || id::text || '@deleted.local',
			password_hash = 'DELETED',
			status = 'deleted',
			deleted_at = NOW(),
			updated_at = NOW()
		WHERE id = $1
	`, userID)
	if err != nil {
		return err
	}

	// Revoke all refresh tokens
	_, _ = tx.Exec(`UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = $1`, userID)

	// Anonymize organizer profile if exists
	_, _ = tx.Exec(`
		UPDATE organizers SET
			name = 'Deleted User',
			description = '',
			website = '',
			phone = '',
			logo_url = '',
			updated_at = NOW()
		WHERE user_id = $1
	`, userID)

	return tx.Commit()
}

// ExportUserData returns all user data for GDPR export
func (r *Repository) ExportUserData(userID uuid.UUID) (map[string]interface{}, error) {
	data := make(map[string]interface{})

	// User profile
	user, err := r.GetUserByID(userID)
	if err != nil {
		return nil, err
	}
	user.PasswordHash = "[REDACTED]"
	data["user"] = user

	// Organizer profile
	org, err := r.GetOrganizerByUserID(userID)
	if err == nil {
		data["organizer"] = org
	}

	// Events created
	var events []map[string]interface{}
	rows, err := r.db.Query(`
		SELECT id, title, status, created_at FROM events WHERE organizer_id IN
		(SELECT id FROM organizers WHERE user_id = $1)
	`, userID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var id uuid.UUID
			var title, status string
			var createdAt time.Time
			if rows.Scan(&id, &title, &status, &createdAt) == nil {
				events = append(events, map[string]interface{}{
					"id": id, "title": title, "status": status, "created_at": createdAt,
				})
			}
		}
	}
	data["events"] = events

	data["export_date"] = time.Now()
	data["format"] = "GDPR Data Subject Access Request"

	return data, nil
}
