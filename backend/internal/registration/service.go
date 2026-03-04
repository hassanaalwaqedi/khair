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

	// Check if email already exists
	existing, _ := s.repo.GetUserByEmail(req.Email)
	if existing != nil {
		return nil, errors.New("this email is already registered")
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

// ProcessStep4 finalizes registration and triggers email verification
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

	role := ""
	if draft.Role != nil {
		role = *draft.Role
	}

	displayName := getString(formData, "display_name")
	passwordHash := getString(formData, "password_hash")

	// Create user
	now := time.Now()
	user := &models.User{
		ID:           uuid.New(),
		Email:        draft.Email,
		PasswordHash: passwordHash,
		Role:         role,
		Status:       "pending_verification",
		DisplayName:  strPtr(displayName),
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
		PreferredLanguage:      lang,
		ProfileCompletionScore: CalculateProfileCompletion(role, formData),
		CreatedAt:              now,
		UpdatedAt:              now,
	}

	if err := s.repo.CreateUserWithProfile(user, profile); err != nil {
		log.Printf("[ERROR] CreateUserWithProfile failed for %s: %v", draft.Email, err)
		return nil, errors.New("failed to create account")
	}

	// Store hashed OTP in email_verifications table
	otpHash := hashOTP(code)
	if err := s.repo.CreateVerification(user.ID, otpHash, verificationExpires); err != nil {
		log.Printf("[ERROR] Failed to create verification record for %s: %v", draft.Email, err)
	}

	// Create role-specific records
	if err := s.createRoleSpecificRecords(user, formData, role); err != nil {
		// Non-fatal — profile still created
	}

	// Delete draft
	s.repo.DeleteDraft(draft.ID)

	// Send verification email
	if s.emailSvc != nil && s.emailSvc.IsEnabled() {
		if err := s.emailSvc.SendVerificationEmail(draft.Email, code); err != nil {
			log.Printf("[WARN] Failed to send verification email to %s: %v", draft.Email, err)
		}
	}

	// Audit log
	userID := user.ID
	s.logAudit(&userID, &user.Email, intPtr(4), "registration_complete_pending_verification", ipAddress, "")

	return &RegistrationCompleteResponse{
		User:            user,
		Profile:         profile,
		CompletionScore: profile.ProfileCompletionScore,
		Suggestions:     GetSuggestionsForRole(role, formData),
		WelcomeMessage:  fmt.Sprintf("A verification code has been sent to %s. Please check your email.", draft.Email),
	}, nil
}

// VerifyCode verifies a user's email with a 6-digit code
func (s *Service) VerifyCode(req *VerifyCodeRequest) (*models.User, error) {
	// Hash the submitted code before comparing
	otpHash := hashOTP(req.Code)
	user, err := s.repo.VerifyByCode(req.Email, otpHash)
	if err != nil {
		log.Printf("[WARN] Verification attempt failed for %s", req.Email)
		return nil, errors.New("invalid or expired verification code")
	}
	log.Printf("[INFO] Email verified successfully for %s", user.Email)
	return user, nil
}

// ResendCode generates a new verification code and sends it
func (s *Service) ResendCode(req *ResendCodeRequest) error {
	user, err := s.repo.GetUserByEmail(req.Email)
	if err != nil || user == nil {
		// Generic response to prevent email enumeration
		return nil
	}

	// Already verified
	if user.VerifiedAt != nil {
		return nil
	}

	code := generateVerificationCode()
	otpHash := hashOTP(code)
	expires := time.Now().Add(10 * time.Minute)

	if err := s.repo.UpdateVerificationCode(user.ID, otpHash, expires); err != nil {
		return errors.New("failed to generate new code")
	}

	if s.emailSvc != nil && s.emailSvc.IsEnabled() {
		if err := s.emailSvc.SendVerificationEmail(req.Email, code); err != nil {
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

func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func intPtr(i int) *int {
	return &i
}
