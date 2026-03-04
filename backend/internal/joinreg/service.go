package joinreg

import (
	"database/sql"
	"encoding/json"
	"errors"
	"net/mail"
	"strings"
	"time"
	"unicode"

	"github.com/google/uuid"
	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/pkg/config"
	"golang.org/x/crypto/bcrypt"
)

// Service handles minimal join registration logic
type Service struct {
	repo *Repository
	cfg  *config.Config
}

// NewService creates a new join registration service
func NewService(db *sql.DB, cfg *config.Config) *Service {
	return &Service{
		repo: NewRepository(db),
		cfg:  cfg,
	}
}

// Step1Request is step 1: name + email
type Step1Request struct {
	Name    string `json:"name" binding:"required"`
	Email   string `json:"email" binding:"required"`
	EventID string `json:"event_id,omitempty"`
}

// Step1Response returned after step 1
type Step1Response struct {
	DraftID string `json:"draft_id"`
	Step    int    `json:"step"`
	Message string `json:"message"`
}

// Step2Request is step 2: password + gender + age
type Step2Request struct {
	DraftID  string `json:"draft_id" binding:"required"`
	Password string `json:"password" binding:"required"`
	Gender   string `json:"gender" binding:"required"`
	Age      *int   `json:"age,omitempty"`
}

// Step2Response returned after step 2
type Step2Response struct {
	UserID           string `json:"user_id"`
	Message          string `json:"message"`
	VerificationSent bool   `json:"verification_sent"`
}

// Disposable email domain blocklist
var disposableDomains = map[string]bool{
	"tempmail.com": true, "throwaway.email": true, "guerrillamail.com": true,
	"mailinator.com": true, "trashmail.com": true, "yopmail.com": true,
	"sharklasers.com": true, "guerrillamail.info": true, "grr.la": true,
	"dispostable.com": true, "mailnesia.com": true, "maildrop.cc": true,
	"10minutemail.com": true, "tempail.com": true, "fakeinbox.com": true,
}

// ProcessStep1 validates name + email and creates a draft
func (s *Service) ProcessStep1(req *Step1Request, ipAddress string) (*Step1Response, error) {
	name := strings.TrimSpace(req.Name)
	if len(name) < 2 {
		return nil, errors.New("name must be at least 2 characters")
	}
	if len(name) > 100 {
		return nil, errors.New("name is too long")
	}

	email := strings.ToLower(strings.TrimSpace(req.Email))
	if _, err := mail.ParseAddress(email); err != nil {
		return nil, errors.New("please enter a valid email address")
	}

	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		return nil, errors.New("invalid email format")
	}
	if disposableDomains[parts[1]] {
		return nil, errors.New("disposable email addresses are not allowed — please use a real email")
	}

	exists, err := s.repo.CheckEmailExists(email)
	if err != nil {
		return nil, errors.New("failed to check email availability")
	}
	if exists {
		return nil, errors.New("an account with this email already exists — try signing in")
	}

	formData, _ := json.Marshal(map[string]interface{}{
		"name": name, "email": email, "event_id": req.EventID,
	})
	role := models.RoleMember
	ip := ipAddress
	draft := &models.RegistrationDraft{
		ID:          uuid.New(),
		Email:       email,
		CurrentStep: 1,
		Role:        &role,
		FormData:    formData,
		IPAddress:   &ip,
		ExpiresAt:   time.Now().Add(30 * time.Minute),
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	if err := s.repo.SaveDraft(draft); err != nil {
		return nil, errors.New("failed to save registration progress")
	}

	return &Step1Response{
		DraftID: draft.ID.String(),
		Step:    1,
		Message: "Email validated. Continue to set your password.",
	}, nil
}

// ProcessStep2 finalizes registration: password + gender + age
func (s *Service) ProcessStep2(req *Step2Request) (*Step2Response, *models.User, error) {
	draftID, err := uuid.Parse(req.DraftID)
	if err != nil {
		return nil, nil, errors.New("invalid draft ID")
	}

	// Load draft directly by ID
	var email string
	var formDataRaw json.RawMessage
	err = s.repo.db.QueryRow(`
		SELECT email, form_data FROM registration_drafts WHERE id = $1 AND expires_at > NOW()`,
		draftID,
	).Scan(&email, &formDataRaw)
	if err != nil {
		return nil, nil, errors.New("registration session expired — please start again")
	}

	var savedData map[string]interface{}
	json.Unmarshal(formDataRaw, &savedData)
	name, _ := savedData["name"].(string)
	eventIDStr, _ := savedData["event_id"].(string)

	if err := validatePassword(req.Password); err != nil {
		return nil, nil, err
	}

	gender := strings.ToLower(strings.TrimSpace(req.Gender))
	if gender != "male" && gender != "female" {
		return nil, nil, errors.New("gender must be 'male' or 'female'")
	}

	if req.Age != nil {
		if *req.Age < 13 || *req.Age > 120 {
			return nil, nil, errors.New("age must be between 13 and 120")
		}
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, nil, errors.New("failed to secure password")
	}

	var eventID *uuid.UUID
	if eventIDStr != "" {
		eid, err := uuid.Parse(eventIDStr)
		if err == nil {
			eventID = &eid
		}
	}

	user, _, err := s.repo.CreateMemberUser(name, email, string(hashedPassword), gender, req.Age, eventID)
	if err != nil {
		return nil, nil, err
	}

	return &Step2Response{
		UserID:           user.ID.String(),
		Message:          "Account created! Please verify your email to confirm your seat.",
		VerificationSent: true,
	}, user, nil
}

// VerifyEmail verifies the email token and confirms any pending seats
func (s *Service) VerifyEmail(token string) (*models.User, error) {
	token = strings.TrimSpace(token)
	if token == "" {
		return nil, errors.New("verification token is required")
	}
	return s.repo.VerifyEmailAndConfirmSeat(token)
}

// validatePassword checks password strength
func validatePassword(password string) error {
	if len(password) < 8 {
		return errors.New("password must be at least 8 characters")
	}
	if len(password) > 128 {
		return errors.New("password is too long")
	}

	var hasUpper, hasLower, hasDigit bool
	for _, ch := range password {
		switch {
		case unicode.IsUpper(ch):
			hasUpper = true
		case unicode.IsLower(ch):
			hasLower = true
		case unicode.IsDigit(ch):
			hasDigit = true
		}
	}
	if !hasUpper || !hasLower || !hasDigit {
		return errors.New("password must include uppercase, lowercase, and a number")
	}
	return nil
}
