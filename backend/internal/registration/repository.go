package registration

import (
	"database/sql"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"

	"github.com/khair/backend/internal/models"
)

// Repository handles database operations for registration
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new registration repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// --- User Operations ---

// CreateUserWithProfile creates a user and their profile in a single transaction
func (r *Repository) CreateUserWithProfile(user *models.User, profile *models.Profile) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Create user
	_, err = tx.Exec(`
		INSERT INTO users (id, email, password_hash, role, status, display_name, is_verified, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, false, $7, $8)`,
		user.ID, user.Email, user.PasswordHash, user.Role, user.Status,
		user.DisplayName,
		user.CreatedAt, user.UpdatedAt,
	)
	if err != nil {
		return err
	}

	// Create profile
	_, err = tx.Exec(`
		INSERT INTO profiles (id, user_id, bio, location, city, country, avatar_url, preferred_language, profile_completion_score, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
		profile.ID, profile.UserID, profile.Bio, profile.Location, profile.City,
		profile.Country, profile.AvatarURL, profile.PreferredLanguage,
		profile.ProfileCompletionScore, profile.CreatedAt, profile.UpdatedAt,
	)
	if err != nil {
		return err
	}

	return tx.Commit()
}

// CreateOrganizer creates an organizer record
func (r *Repository) CreateOrganizer(org *models.Organizer) error {
	_, err := r.db.Exec(`
		INSERT INTO organizers (id, user_id, name, description, website, phone, logo_url, status, registration_number, organization_type, city, country, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
		org.ID, org.UserID, org.Name, org.Description, org.Website, org.Phone,
		org.LogoURL, org.Status, org.RegistrationNumber, org.OrganizationType,
		org.City, org.Country, org.CreatedAt, org.UpdatedAt,
	)
	return err
}

// CreateSheikh creates a sheikh record
func (r *Repository) CreateSheikh(sheikh *models.Sheikh) error {
	_, err := r.db.Exec(`
		INSERT INTO sheikhs (id, user_id, specialization, ijazah_info, certifications, years_of_experience, verification_status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
		sheikh.ID, sheikh.UserID, sheikh.Specialization, sheikh.IjazahInfo,
		pq.Array(sheikh.Certifications), sheikh.YearsOfExperience,
		sheikh.VerificationStatus, sheikh.CreatedAt, sheikh.UpdatedAt,
	)
	return err
}

// GetUserByEmail checks for existing user
func (r *Repository) GetUserByEmail(email string) (*models.User, error) {
	user := &models.User{}
	err := r.db.QueryRow(`
		SELECT id, email, password_hash, role, status, display_name, verified_at, created_at, updated_at
		FROM users WHERE email = $1`, email,
	).Scan(&user.ID, &user.Email, &user.PasswordHash, &user.Role, &user.Status,
		&user.DisplayName, &user.VerifiedAt, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return user, nil
}

// VerifyByCode verifies a user by matching an OTP hash from the email_verifications table
func (r *Repository) VerifyByCode(email string, otpHash string) (*models.User, error) {
	tx, err := r.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	// Increment attempts first (prevents brute-force)
	tx.Exec(`
		UPDATE email_verifications SET attempts = attempts + 1
		WHERE user_id = (SELECT id FROM users WHERE email = $1)`, email)

	// Verify the OTP
	var verificationID uuid.UUID
	err = tx.QueryRow(`
		SELECT ev.id FROM email_verifications ev
		JOIN users u ON u.id = ev.user_id
		WHERE u.email = $1 AND ev.otp_hash = $2 AND ev.expires_at > NOW() AND ev.attempts < 5`,
		email, otpHash,
	).Scan(&verificationID)
	if err != nil {
		return nil, err
	}

	// Mark user as verified
	user := &models.User{}
	err = tx.QueryRow(`
		UPDATE users SET is_verified = true, verified_at = NOW(), status = 'active', updated_at = NOW()
		WHERE email = $1 AND is_verified = false
		RETURNING id, email, role, status, display_name, verified_at, created_at, updated_at`,
		email,
	).Scan(&user.ID, &user.Email, &user.Role, &user.Status, &user.DisplayName,
		&user.VerifiedAt, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		return nil, err
	}

	// Delete verification record
	_, _ = tx.Exec(`DELETE FROM email_verifications WHERE id = $1`, verificationID)

	if err := tx.Commit(); err != nil {
		return nil, err
	}
	user.IsVerified = true
	return user, nil
}

// UpdateVerificationCode updates the OTP hash in email_verifications for a user (resend)
func (r *Repository) UpdateVerificationCode(userID uuid.UUID, otpHash string, expires time.Time) error {
	result, err := r.db.Exec(`
		UPDATE email_verifications SET otp_hash = $2, expires_at = $3, attempts = 0, last_sent_at = NOW()
		WHERE user_id = $1`,
		userID, otpHash, expires,
	)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		// No existing record — create one
		_, err = r.db.Exec(`
			INSERT INTO email_verifications (id, user_id, otp_hash, expires_at, attempts, last_sent_at, created_at)
			VALUES ($1, $2, $3, $4, 0, NOW(), NOW())`,
			uuid.New(), userID, otpHash, expires,
		)
		return err
	}
	return nil
}

// CreateVerification inserts a new email verification record
func (r *Repository) CreateVerification(userID uuid.UUID, otpHash string, expires time.Time) error {
	// Delete any existing verification for this user
	_, _ = r.db.Exec(`DELETE FROM email_verifications WHERE user_id = $1`, userID)

	_, err := r.db.Exec(`
		INSERT INTO email_verifications (id, user_id, otp_hash, expires_at, attempts, last_sent_at, created_at)
		VALUES ($1, $2, $3, $4, 0, NOW(), NOW())`,
		uuid.New(), userID, otpHash, expires,
	)
	return err
}

// GetProfile gets a user's profile
func (r *Repository) GetProfile(userID uuid.UUID) (*models.Profile, error) {
	profile := &models.Profile{}
	err := r.db.QueryRow(`
		SELECT id, user_id, bio, location, city, country, avatar_url, preferred_language, profile_completion_score, created_at, updated_at
		FROM profiles WHERE user_id = $1`, userID,
	).Scan(&profile.ID, &profile.UserID, &profile.Bio, &profile.Location, &profile.City,
		&profile.Country, &profile.AvatarURL, &profile.PreferredLanguage,
		&profile.ProfileCompletionScore, &profile.CreatedAt, &profile.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return profile, nil
}

// UpdateProfile updates a user's profile
func (r *Repository) UpdateProfile(profile *models.Profile) error {
	_, err := r.db.Exec(`
		UPDATE profiles SET bio = $2, location = $3, city = $4, country = $5, avatar_url = $6,
		preferred_language = $7, profile_completion_score = $8
		WHERE user_id = $1`,
		profile.UserID, profile.Bio, profile.Location, profile.City, profile.Country,
		profile.AvatarURL, profile.PreferredLanguage, profile.ProfileCompletionScore,
	)
	return err
}

// --- Draft Operations ---

// SaveDraft creates or updates a registration draft
func (r *Repository) SaveDraft(draft *models.RegistrationDraft) error {
	_, err := r.db.Exec(`
		INSERT INTO registration_drafts (id, email, current_step, role, form_data, ip_address, expires_at, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		ON CONFLICT (id) DO UPDATE SET
			current_step = $3, role = $4, form_data = $5, updated_at = $9`,
		draft.ID, draft.Email, draft.CurrentStep, draft.Role, draft.FormData,
		draft.IPAddress, draft.ExpiresAt, draft.CreatedAt, draft.UpdatedAt,
	)
	return err
}

// LoadDraftByEmail loads the latest active draft for an email
func (r *Repository) LoadDraftByEmail(email string) (*models.RegistrationDraft, error) {
	draft := &models.RegistrationDraft{}
	err := r.db.QueryRow(`
		SELECT id, email, current_step, role, form_data, expires_at, created_at, updated_at
		FROM registration_drafts
		WHERE email = $1 AND expires_at > NOW()
		ORDER BY updated_at DESC LIMIT 1`, email,
	).Scan(&draft.ID, &draft.Email, &draft.CurrentStep, &draft.Role,
		&draft.FormData, &draft.ExpiresAt, &draft.CreatedAt, &draft.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return draft, nil
}

// DeleteDraft removes a draft after successful registration
func (r *Repository) DeleteDraft(id uuid.UUID) error {
	_, err := r.db.Exec(`DELETE FROM registration_drafts WHERE id = $1`, id)
	return err
}

// --- Audit Log ---

// LogAudit logs a registration event
func (r *Repository) LogAudit(log *models.RegistrationAuditLog) error {
	detailsJSON, _ := json.Marshal(log.Details)
	if detailsJSON == nil {
		detailsJSON = []byte("{}")
	}
	_, err := r.db.Exec(`
		INSERT INTO registration_audit_log (id, user_id, email, step, action, details, ip_address, user_agent, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
		log.ID, log.UserID, log.Email, log.Step, log.Action, detailsJSON,
		log.IPAddress, log.UserAgent, log.CreatedAt,
	)
	return err
}
