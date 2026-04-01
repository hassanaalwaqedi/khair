package registration

import (
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math/big"
	"strings"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/pkg/config"
	"github.com/khair/backend/pkg/email"
)

// Service handles registration business logic
type Service struct {
	repo     *Repository
	cfg      *config.Config
	emailSvc *email.Service
}

// NewService creates a new registration service
func NewService(db *sql.DB, cfg *config.Config, emailSvc *email.Service) *Service {
	return &Service{
		repo:     NewRepository(db),
		cfg:      cfg,
		emailSvc: emailSvc,
	}
}

// --- Request types ---

// Step1Request is role selection + credentials
type Step1Request struct {
	Role        string `json:"role" binding:"required"`
	Email       string `json:"email" binding:"required,email"`
	Password    string `json:"password" binding:"required,min=8"`
	DisplayName string `json:"display_name"` // optional — required for simple roles
}

// Step2Request is basic info
type Step2Request struct {
	DraftID     uuid.UUID `json:"draft_id" binding:"required"`
	DisplayName string    `json:"display_name" binding:"required"`
	Bio         string    `json:"bio"`
	Location    string    `json:"location"`
	City        string    `json:"city"`
	Country     string    `json:"country"`
	Language    string    `json:"preferred_language"`
}

// Step3Request is role-specific info
type Step3Request struct {
	DraftID uuid.UUID              `json:"draft_id" binding:"required"`
	Data    map[string]interface{} `json:"data" binding:"required"`
}

// Step4Request is email verification trigger
type Step4Request struct {
	DraftID uuid.UUID `json:"draft_id" binding:"required"`
}

// VerifyCodeRequest verifies email with 6-digit code
type VerifyCodeRequest struct {
	Email string `json:"email" binding:"required,email"`
	Code  string `json:"code" binding:"required,len=6"`
}

// ResendCodeRequest requests a new verification code
type ResendCodeRequest struct {
	Email string `json:"email" binding:"required,email"`
}

// --- Response types ---

// StepResponse is returned after each step
type StepResponse struct {
	DraftID         uuid.UUID    `json:"draft_id"`
	CurrentStep     int          `json:"current_step"`
	CompletionScore int          `json:"completion_score"`
	Suggestions     []Suggestion `json:"suggestions"`
	Message         string       `json:"message,omitempty"`
}

// RegistrationCompleteResponse is returned after final step
type RegistrationCompleteResponse struct {
	User            *models.User    `json:"user"`
	Profile         *models.Profile `json:"profile"`
	CompletionScore int             `json:"completion_score"`
	Suggestions     []Suggestion    `json:"suggestions"`
	WelcomeMessage  string          `json:"welcome_message"`
}

// --- Step Handlers ---

// ProcessStep1 handles role selection and credential creation
func (s *Service) ProcessStep1(req *Step1Request, ipAddress string) (*StepResponse, error) {
	// Validate role
	validRoles := map[string]bool{
		models.RoleOrganization:       true,
		models.RoleSheikh:             true,
		models.RoleNewMuslim:          true,
		models.RoleStudent:            true,
		models.RoleCommunityOrganizer: true,
	}
	if !validRoles[req.Role] {
		return nil, errors.New("invalid role selection")
	}

	// Check if email already exists as verified user
	existing, _ := s.repo.GetUserByEmail(req.Email)
	if existing != nil {
		if existing.VerifiedAt != nil {
			// Verified user — reject
			return nil, errors.New("this email is already registered")
		}
		// Legacy: unverified user in DB — delete so they can re-register
		if err := s.repo.DeleteUnverifiedUser(existing.ID); err != nil {
			log.Printf("[WARN] Failed to delete unverified user %s: %v", req.Email, err)
			return nil, errors.New("this email is already registered")
		}
		log.Printf("[INFO] Deleted unverified user %s to allow re-registration", req.Email)
	}

	// Clean up any existing draft for this email (allows re-registration)
	if oldDraft, err := s.repo.LoadDraftByEmail(req.Email); err == nil && oldDraft != nil {
		s.repo.DeleteDraft(oldDraft.ID)
		log.Printf("[INFO] Deleted old draft for %s to allow re-registration", req.Email)
	}

	// Validate password strength
	strength := CalculatePasswordStrength(req.Password)
	if strength.Score < 2 {
		return nil, errors.New("password is too weak: " + strings.Join(strength.Tips, ", "))
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, errors.New("failed to process password")
	}

	// Create draft
	formData := map[string]interface{}{
		"role":          req.Role,
		"email":         req.Email,
		"password_hash": string(hashedPassword),
	}
	if req.DisplayName != "" {
		formData["display_name"] = req.DisplayName
	}
	formDataJSON, _ := json.Marshal(formData)

	draft := &models.RegistrationDraft{
		ID:          uuid.New(),
		Email:       req.Email,
		CurrentStep: 2,
		Role:        &req.Role,
		FormData:    formDataJSON,
		IPAddress:   &ipAddress,
		ExpiresAt:   time.Now().Add(7 * 24 * time.Hour),
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	if err := s.repo.SaveDraft(draft); err != nil {
		return nil, errors.New("failed to save registration progress")
	}

	// Audit log
	s.logAudit(nil, &req.Email, intPtr(1), "step1_completed", ipAddress, "")

	return &StepResponse{
		DraftID:         draft.ID,
		CurrentStep:     2,
		CompletionScore: CalculateProfileCompletion(req.Role, formData),
		Suggestions:     GetSuggestionsForRole(req.Role, formData),
		Message:         "Credentials saved. Please complete your profile.",
	}, nil
}

// ProcessStep2 handles basic profile info
func (s *Service) ProcessStep2(req *Step2Request, ipAddress string) (*StepResponse, error) {
	draft, err := s.loadAndValidateDraft(req.DraftID)
	if err != nil {
		return nil, err
	}

	// Merge data into draft
	var formData map[string]interface{}
	json.Unmarshal(draft.FormData, &formData)

	formData["display_name"] = req.DisplayName
	formData["bio"] = req.Bio
	formData["location"] = req.Location
	formData["city"] = req.City
	formData["country"] = req.Country
	formData["preferred_language"] = req.Language

	formDataJSON, _ := json.Marshal(formData)
	draft.FormData = formDataJSON
	draft.CurrentStep = 3
	draft.UpdatedAt = time.Now()

	if err := s.repo.SaveDraft(draft); err != nil {
		return nil, errors.New("failed to save registration progress")
	}

	role := ""
	if draft.Role != nil {
		role = *draft.Role
	}

	s.logAudit(nil, &draft.Email, intPtr(2), "step2_completed", ipAddress, "")

	return &StepResponse{
		DraftID:         draft.ID,
		CurrentStep:     3,
		CompletionScore: CalculateProfileCompletion(role, formData),
		Suggestions:     GetSuggestionsForRole(role, formData),
		Message:         "Profile basics saved. Now add your role-specific details.",
	}, nil
}

// ProcessStep3 handles role-specific info
func (s *Service) ProcessStep3(req *Step3Request, ipAddress string) (*StepResponse, error) {
	draft, err := s.loadAndValidateDraft(req.DraftID)
	if err != nil {
		return nil, err
	}

	var formData map[string]interface{}
	json.Unmarshal(draft.FormData, &formData)

	// Merge role-specific data
	for k, v := range req.Data {
		formData[k] = v
	}

	formDataJSON, _ := json.Marshal(formData)
	draft.FormData = formDataJSON
	draft.CurrentStep = 4
	draft.UpdatedAt = time.Now()

	if err := s.repo.SaveDraft(draft); err != nil {
		return nil, errors.New("failed to save registration progress")
	}

	role := ""
	if draft.Role != nil {
		role = *draft.Role
	}

	s.logAudit(nil, &draft.Email, intPtr(3), "step3_completed", ipAddress, "")

	return &StepResponse{
		DraftID:         draft.ID,
		CurrentStep:     4,
		CompletionScore: CalculateProfileCompletion(role, formData),
		Suggestions:     GetSuggestionsForRole(role, formData),
		Message:         "Role details saved. Complete your registration.",
	}, nil
}

// ProcessStep4 stores the verification code in the draft and sends the email.
// The user is NOT created in the database until the code is verified.
func (s *Service) ProcessStep4(req *Step4Request, ipAddress string) (*RegistrationCompleteResponse, error) {
	draft, err := s.loadAndValidateDraft(req.DraftID)
	if err != nil {
		return nil, err
	}

	var formData map[string]interface{}
	json.Unmarshal(draft.FormData, &formData)

	// Generate 6-digit verification code
	code := generateVerificationCode()
	verificationExpires := time.Now().Add(10 * time.Minute)
	otpHash := hashOTP(code)

	// Store OTP hash + expiry in the draft's form_data (NOT in the users table)
	formData["otp_hash"] = otpHash
	formData["otp_expires"] = verificationExpires.Format(time.RFC3339)
	formData["otp_attempts"] = float64(0)
	formDataJSON, _ := json.Marshal(formData)

	draft.FormData = formDataJSON
	draft.CurrentStep = 5 // Mark as "awaiting verification"
	draft.UpdatedAt = time.Now()

	if err := s.repo.SaveDraft(draft); err != nil {
		return nil, errors.New("failed to save registration progress")
	}

	role := ""
	if draft.Role != nil {
		role = *draft.Role
	}

	lang := getString(formData, "preferred_language")
	if lang == "" {
		lang = "en"
	}

	// Send verification email
	if s.emailSvc != nil && s.emailSvc.IsEnabled() {
		if err := s.emailSvc.SendVerificationEmail(draft.Email, code, lang); err != nil {
			log.Printf("[WARN] Failed to send verification email to %s: %v", draft.Email, err)
		}
	}

	// Audit log
	s.logAudit(nil, &draft.Email, intPtr(4), "verification_code_sent", ipAddress, "")

	// Build a placeholder response (no user created yet)
	displayName := getString(formData, "display_name")
	return &RegistrationCompleteResponse{
		User: &models.User{
			Email:       draft.Email,
			Role:        role,
			Status:      "pending_verification",
			DisplayName: strPtr(displayName),
		},
		CompletionScore: CalculateProfileCompletion(role, formData),
		Suggestions:     GetSuggestionsForRole(role, formData),
		WelcomeMessage:  fmt.Sprintf("A verification code has been sent to %s. Please check your email.", draft.Email),
	}, nil
}

// VerifyCode verifies email with a 6-digit code.
// On success, it creates the user + profile + role records from the draft.
func (s *Service) VerifyCode(req *VerifyCodeRequest) (*models.User, error) {
	otpHash := hashOTP(req.Code)

	// Load the draft for this email
	draft, err := s.repo.LoadDraftByEmail(req.Email)
	if err != nil {
		log.Printf("[WARN] Verification attempt failed for %s: no draft found", req.Email)
		return nil, errors.New("invalid or expired verification code")
	}

	var formData map[string]interface{}
	json.Unmarshal(draft.FormData, &formData)

	// Check OTP attempts (prevent brute-force)
	attempts := int(getFloat(formData, "otp_attempts"))
	if attempts >= 5 {
		return nil, errors.New("too many attempts, please request a new code")
	}

	// Increment attempts
	formData["otp_attempts"] = float64(attempts + 1)
	formDataJSON, _ := json.Marshal(formData)
	draft.FormData = formDataJSON
	draft.UpdatedAt = time.Now()
	s.repo.SaveDraft(draft)

	// Verify OTP hash
	storedHash := getString(formData, "otp_hash")
	if storedHash == "" || storedHash != otpHash {
		log.Printf("[WARN] Verification code mismatch for %s (attempt %d)", req.Email, attempts+1)
		return nil, errors.New("invalid or expired verification code")
	}

	// Check expiry
	expiresStr := getString(formData, "otp_expires")
	expires, parseErr := time.Parse(time.RFC3339, expiresStr)
	if parseErr != nil || time.Now().After(expires) {
		return nil, errors.New("verification code has expired, please request a new one")
	}

	// ── OTP is valid — NOW create the user ──

	role := ""
	if draft.Role != nil {
		role = *draft.Role
	}

	displayName := getString(formData, "display_name")
	passwordHash := getString(formData, "password_hash")

	now := time.Now()
	user := &models.User{
		ID:           uuid.New(),
		Email:        draft.Email,
		PasswordHash: passwordHash,
		Role:         role,
		Status:       "active",
		DisplayName:  strPtr(displayName),
		IsVerified:   true,
		VerifiedAt:   &now,
		CreatedAt:    now,
		UpdatedAt:    now,
	}

	bio := getString(formData, "bio")
	location := getString(formData, "location")
	city := getString(formData, "city")
	country := getString(formData, "country")
	lang := getString(formData, "preferred_language")
	if lang == "" {
		lang = "en"
	}

	profile := &models.Profile{
		ID:                     uuid.New(),
		UserID:                 user.ID,
		Bio:                    strPtr(bio),
		Location:               strPtr(location),
		City:                   strPtr(city),
		Country:                strPtr(country),
		AvatarURL:              strPtr(getString(formData, "logo_url")),
		PreferredLanguage:      lang,
		ProfileCompletionScore: CalculateProfileCompletion(role, formData),
		CreatedAt:              now,
		UpdatedAt:              now,
	}

	if err := s.repo.CreateUserVerified(user, profile); err != nil {
		log.Printf("[ERROR] CreateUserVerified failed for %s: %v", draft.Email, err)
		return nil, errors.New("failed to create account")
	}

	// Create role-specific records
	if err := s.createRoleSpecificRecords(user, formData, role); err != nil {
		log.Printf("[WARN] Failed to create role-specific records for %s: %v", draft.Email, err)
	}

	// Delete draft
	s.repo.DeleteDraft(draft.ID)

	// Audit log
	userID := user.ID
	s.logAudit(&userID, &user.Email, intPtr(5), "email_verified_account_created", "", "")

	// Send welcome notification
	go s.sendWelcomeNotification(user.ID, role, displayName)

	log.Printf("[INFO] Email verified and account created for %s", user.Email)
	return user, nil
}

// ResendCode generates a new verification code and sends it.
// Works with drafts — no user in DB yet.
func (s *Service) ResendCode(req *ResendCodeRequest) error {
	// First check if there's a draft (new flow — user not in DB yet)
	draft, err := s.repo.LoadDraftByEmail(req.Email)
	if err == nil && draft != nil {
		// Draft exists — update the OTP in the draft
		var formData map[string]interface{}
		json.Unmarshal(draft.FormData, &formData)

		code := generateVerificationCode()
		otpHash := hashOTP(code)
		expires := time.Now().Add(10 * time.Minute)

		formData["otp_hash"] = otpHash
		formData["otp_expires"] = expires.Format(time.RFC3339)
		formData["otp_attempts"] = float64(0)
		formDataJSON, _ := json.Marshal(formData)

		draft.FormData = formDataJSON
		draft.UpdatedAt = time.Now()
		s.repo.SaveDraft(draft)

		lang := getString(formData, "preferred_language")
		if lang == "" {
			lang = "en"
		}

		if s.emailSvc != nil && s.emailSvc.IsEnabled() {
			if err := s.emailSvc.SendVerificationEmail(req.Email, code, lang); err != nil {
				log.Printf("[WARN] Failed to resend verification email to %s: %v", req.Email, err)
			}
		}
		return nil
	}

	// Legacy fallback: user might be in DB from old flow
	user, err := s.repo.GetUserByEmail(req.Email)
	if err != nil || user == nil {
		return nil // Generic to prevent email enumeration
	}
	if user.VerifiedAt != nil {
		return nil // Already verified
	}

	code := generateVerificationCode()
	otpHash := hashOTP(code)
	expires := time.Now().Add(10 * time.Minute)

	if err := s.repo.UpdateVerificationCode(user.ID, otpHash, expires); err != nil {
		return errors.New("failed to generate new code")
	}

	if s.emailSvc != nil && s.emailSvc.IsEnabled() {
		if err := s.emailSvc.SendVerificationEmail(req.Email, code, "en"); err != nil {
			log.Printf("[WARN] Failed to resend verification email to %s: %v", req.Email, err)
		}
	}

	return nil
}

// hashOTP hashes an OTP string using SHA256
func hashOTP(otp string) string {
	h := sha256.Sum256([]byte(otp))
	return hex.EncodeToString(h[:])
}

// generateVerificationCode creates a cryptographically secure 6-digit code
func generateVerificationCode() string {
	max := big.NewInt(1000000)
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		// Fallback (should never happen)
		return "000000"
	}
	return fmt.Sprintf("%06d", n.Int64())
}

// LoadDraft loads a saved registration draft
func (s *Service) LoadDraft(email string) (*StepResponse, error) {
	draft, err := s.repo.LoadDraftByEmail(email)
	if err != nil {
		return nil, errors.New("no saved registration found")
	}

	var formData map[string]interface{}
	json.Unmarshal(draft.FormData, &formData)

	role := ""
	if draft.Role != nil {
		role = *draft.Role
	}

	return &StepResponse{
		DraftID:         draft.ID,
		CurrentStep:     draft.CurrentStep,
		CompletionScore: CalculateProfileCompletion(role, formData),
		Suggestions:     GetSuggestionsForRole(role, formData),
	}, nil
}

// GetSuggestions returns smart suggestions for current data
func (s *Service) GetSuggestions(role string, data map[string]interface{}) (*StepResponse, error) {
	return &StepResponse{
		CompletionScore: CalculateProfileCompletion(role, data),
		Suggestions:     GetSuggestionsForRole(role, data),
	}, nil
}

// --- Internal helpers ---

func (s *Service) loadAndValidateDraft(id uuid.UUID) (*models.RegistrationDraft, error) {
	draft := &models.RegistrationDraft{}
	err := s.repo.db.QueryRow(`
		SELECT id, email, current_step, role, form_data, expires_at, created_at, updated_at
		FROM registration_drafts
		WHERE id = $1 AND expires_at > NOW()`, id,
	).Scan(&draft.ID, &draft.Email, &draft.CurrentStep, &draft.Role,
		&draft.FormData, &draft.ExpiresAt, &draft.CreatedAt, &draft.UpdatedAt)
	if err != nil {
		return nil, errors.New("registration session not found or expired")
	}
	return draft, nil
}

func (s *Service) createRoleSpecificRecords(user *models.User, data map[string]interface{}, role string) error {
	now := time.Now()

	switch role {
	case models.RoleOrganization:
		org := &models.Organizer{
			ID:                 uuid.New(),
			UserID:             user.ID,
			Name:               getString(data, "org_name"),
			Description:        strPtr(getString(data, "org_description")),
			OrganizationType:   strPtr(getString(data, "org_type")),
			City:               strPtr(getString(data, "org_city")),
			Country:            strPtr(getString(data, "org_country")),
			RegistrationNumber: strPtr(getString(data, "registration_number")),
			LogoURL:            strPtr(getString(data, "logo_url")),
			Status:             "pending",
			CreatedAt:          now,
			UpdatedAt:          now,
		}
		if org.Name == "" {
			org.Name = getString(data, "display_name")
		}
		return s.repo.CreateOrganizer(org)

	case models.RoleSheikh:
		certs := []string{}
		if certsRaw, ok := data["certifications"]; ok {
			if certsList, ok := certsRaw.([]interface{}); ok {
				for _, c := range certsList {
					if str, ok := c.(string); ok {
						certs = append(certs, str)
					}
				}
			}
		}
		sheikh := &models.Sheikh{
			ID:                 uuid.New(),
			UserID:             user.ID,
			Specialization:     strPtr(getString(data, "specialization")),
			IjazahInfo:         strPtr(getString(data, "ijazah_info")),
			Certifications:     certs,
			VerificationStatus: "unverified",
			CreatedAt:          now,
			UpdatedAt:          now,
		}
		if yoe, ok := data["years_experience"]; ok {
			if num, ok := yoe.(float64); ok {
				years := int(num)
				sheikh.YearsOfExperience = &years
			}
		}
		return s.repo.CreateSheikh(sheikh)

	case models.RoleCommunityOrganizer:
		org := &models.Organizer{
			ID:               uuid.New(),
			UserID:           user.ID,
			Name:             getString(data, "org_name"),
			Description:      strPtr(getString(data, "community_focus")),
			City:             strPtr(getString(data, "org_city")),
			Country:          strPtr(getString(data, "org_country")),
			OrganizationType: strPtr("community"),
			Status:           "pending",
			CreatedAt:        now,
			UpdatedAt:        now,
		}
		if org.Name == "" {
			org.Name = getString(data, "display_name")
		}
		return s.repo.CreateOrganizer(org)
	}

	return nil
}

func (s *Service) logAudit(userID *uuid.UUID, email *string, step *int, action, ip, ua string) {
	s.repo.LogAudit(&models.RegistrationAuditLog{
		ID:        uuid.New(),
		UserID:    userID,
		Email:     email,
		Step:      step,
		Action:    action,
		IPAddress: &ip,
		UserAgent: &ua,
		CreatedAt: time.Now(),
	})
}

func getWelcomeMessage(role string) string {
	messages := map[string]string{
		models.RoleOrganization:       "Your organization is now registered. You are part of a growing Ummah of knowledge and service. Your account will be reviewed shortly.",
		models.RoleSheikh:             "Welcome, dear teacher. Your knowledge is a trust (amanah). May Allah benefit the Ummah through you.",
		models.RoleNewMuslim:          "Welcome to Islam and to our community! We are honored to support your journey. You are never alone.",
		models.RoleStudent:            "Welcome, seeker of knowledge. The Prophet ﷺ said: 'Whoever follows a path seeking knowledge, Allah will make his path to Paradise easy.'",
		models.RoleCommunityOrganizer: "Welcome, community builder. Your efforts to unite the Ummah are a form of worship. Let us build together.",
	}
	if msg, ok := messages[role]; ok {
		return msg
	}
	return "You are now part of a growing Ummah of knowledge and service."
}

// Utility functions
func getString(m map[string]interface{}, key string) string {
	if val, ok := m[key]; ok {
		if str, ok := val.(string); ok {
			return str
		}
	}
	return ""
}

func getFloat(m map[string]interface{}, key string) float64 {
	if val, ok := m[key]; ok {
		if f, ok := val.(float64); ok {
			return f
		}
	}
	return 0
}

func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func intPtr(i int) *int {
	return &i
}

// sendWelcomeNotification inserts a role-appropriate welcome notification.
// Authority roles get an "under review" message; normal roles get an instant welcome.
func (s *Service) sendWelcomeNotification(userID uuid.UUID, role, displayName string) {
	var title, message string

	name := displayName
	if name == "" {
		name = "there"
	}

	switch role {
	case "sheikh":
		title = "Welcome to Khair – Account Under Review"
		message = fmt.Sprintf(
			"Assalamu Alaikum %s! Thank you for registering as a Sheikh on Khair. "+
				"Your account is currently under review by the Khair team. "+
				"This process usually takes a few hours. "+
				"We will notify you once your account has been approved. JazakAllahu Khairan!",
			name,
		)
	case "organization":
		title = "Welcome to Khair – Account Under Review"
		message = fmt.Sprintf(
			"Assalamu Alaikum %s! Thank you for registering your organization on Khair. "+
				"Your account is currently under review by the Khair team. "+
				"This process usually takes a few hours. "+
				"You will be notified once your account is approved and you can start creating events.",
			name,
		)
	case "community_organizer":
		title = "Welcome to Khair – Account Under Review"
		message = fmt.Sprintf(
			"Assalamu Alaikum %s! Thank you for joining Khair as a Community Organizer. "+
				"Your account is currently under review by the Khair team. "+
				"This usually takes a few hours. "+
				"Once approved, you'll be able to organize and manage community events.",
			name,
		)
	default:
		// Normal users: student, new_muslim, etc.
		title = "Welcome to Khair! 🎉"
		message = fmt.Sprintf(
			"Assalamu Alaikum %s! Welcome to Khair – your Islamic community platform. "+
				"Explore events, connect with scholars, and grow your faith journey. "+
				"May Allah bless your path! 🤲",
			name,
		)
	}

	_, err := s.repo.db.Exec(
		`INSERT INTO notifications (user_id, title, message) VALUES ($1, $2, $3)`,
		userID, title, message,
	)
	if err != nil {
		log.Printf("[WARN] Failed to send welcome notification to %s: %v", userID, err)
	}
}
