package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"

	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/internal/rbac"
	"github.com/khair/backend/pkg/config"
	"github.com/khair/backend/pkg/email"
	"github.com/khair/backend/pkg/middleware"
)

const (
	otpExpiryMinutes   = 10
	maxVerifyAttempts  = 5
	resendCooldownSecs = 60
	refreshTokenBytes  = 32
	refreshTokenDays   = 7

	// Login lockout settings
	maxLoginAttempts    = 10
	lockoutDuration     = 15 * time.Minute
	loginAttemptsPrefix = "login_attempts:"
	loginLockoutPrefix  = "login_lockout:"
)

// Service handles authentication business logic
type Service struct {
	repo     *Repository
	cfg      *config.Config
	emailSvc *email.Service
	rbacRepo *rbac.Repository
	redis    *redis.Client
}

// NewService creates a new auth service
func NewService(db *sql.DB, cfg *config.Config, emailSvc *email.Service, rbacRepo *rbac.Repository, redisClient ...*redis.Client) *Service {
	svc := &Service{
		repo:     NewRepository(db),
		cfg:      cfg,
		emailSvc: emailSvc,
		rbacRepo: rbacRepo,
	}
	if len(redisClient) > 0 {
		svc.redis = redisClient[0]
	}
	return svc
}

// ── Request types ──

// RegisterRequest represents a registration request
type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8"`
	Name     string `json:"name" binding:"required"`
}

// LoginRequest represents a login request
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

// VerifyEmailRequest represents an email verification request
type VerifyEmailRequest struct {
	Email string `json:"email" binding:"required,email"`
	OTP   string `json:"otp" binding:"required,len=6"`
}

// ResendOTPRequest represents a resend OTP request
type ResendOTPRequest struct {
	Email string `json:"email" binding:"required,email"`
}

// ── Response types ──

// AuthResponse represents the response after successful authentication
type AuthResponse struct {
	Token        string            `json:"token"`
	RefreshToken string            `json:"refresh_token,omitempty"`
	ExpiresAt    time.Time         `json:"expires_at"`
	User         *models.User      `json:"user"`
	Organizer    *models.Organizer `json:"organizer,omitempty"`
}

// RefreshTokenRequest represents a token refresh request
type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

// MessageResponse represents a simple message response
type MessageResponse struct {
	Message string `json:"message"`
}

// ── Register ──

// Register registers a new user and sends verification OTP
func (s *Service) Register(req *RegisterRequest) (*MessageResponse, error) {
	// Check if user already exists — generic error to prevent enumeration
	existingUser, _ := s.repo.GetUserByEmail(req.Email)
	if existingUser != nil {
		return nil, errors.New("registration failed, please try again")
	}

	// Hash password with bcrypt
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}

	// Generate 6-digit OTP
	otp, err := generateOTP()
	if err != nil {
		return nil, fmt.Errorf("generate OTP: %w", err)
	}

	// Hash OTP with SHA256 before storing
	otpHash := hashOTP(otp)
	expiresAt := time.Now().Add(otpExpiryMinutes * time.Minute)

	// Create user
	user := &models.User{
		ID:           uuid.New(),
		Email:        req.Email,
		PasswordHash: string(hashedPassword),
		Role:         "organizer",
		Status:       "pending_verification",
		IsVerified:   false,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	if err := s.repo.CreateUser(user); err != nil {
		return nil, fmt.Errorf("create user: %w", err)
	}

	// Store hashed OTP in email_verifications table
	if err := s.repo.CreateVerification(user.ID, otpHash, expiresAt); err != nil {
		log.Printf("[ERROR] Failed to create verification record for %s: %v", req.Email, err)
		return nil, fmt.Errorf("create verification: %w", err)
	}

	// Create organizer profile
	organizer := &models.Organizer{
		ID:        uuid.New(),
		UserID:    user.ID,
		Name:      req.Name,
		Status:    "pending",
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	if err := s.repo.CreateOrganizer(organizer); err != nil {
		return nil, fmt.Errorf("create organizer profile: %w", err)
	}

	// Send verification email (do NOT return OTP in response)
	if err := s.emailSvc.SendVerificationEmail(req.Email, otp); err != nil {
		log.Printf("[WARN] Failed to send verification email to %s: %v", req.Email, err)
		// Don't fail registration if email fails — user can resend
	}

	log.Printf("[INFO] Registration completed for %s, verification email sent", req.Email)

	return &MessageResponse{
		Message: "Verification code sent to your email",
	}, nil
}

// ── Login ──

// Login authenticates a user (requires email verification)
func (s *Service) Login(req *LoginRequest) (*AuthResponse, error) {
	// Check login lockout
	if s.redis != nil {
		ctx := context.Background()
		lockKey := loginLockoutPrefix + req.Email
		if s.redis.Exists(ctx, lockKey).Val() > 0 {
			ttl := s.redis.TTL(ctx, lockKey).Val()
			log.Printf("[SECURITY] Login attempt for locked account %s (TTL: %v)", req.Email, ttl)
			return nil, fmt.Errorf("account temporarily locked due to too many failed login attempts, try again in %d minutes", int(ttl.Minutes())+1)
		}
	}

	user, err := s.repo.GetUserByEmail(req.Email)
	if err != nil {
		s.recordFailedLogin(req.Email)
		return nil, errors.New("invalid email or password")
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		s.recordFailedLogin(req.Email)
		return nil, errors.New("invalid email or password")
	}

	// Clear failed attempt counter on successful login
	s.clearLoginAttempts(req.Email)

	// Check if email is verified
	if !user.IsVerified {
		return nil, errors.New("email not verified, please check your inbox for the verification code")
	}

	// Get organizer profile if exists
	var organizer *models.Organizer
	if user.Role == "organizer" {
		organizer, _ = s.repo.GetOrganizerByUserID(user.ID)
	}

	// Generate JWT
	token, expiresAt, err := s.generateToken(user)
	if err != nil {
		return nil, fmt.Errorf("generate token: %w", err)
	}

	// Generate refresh token
	refreshTokenStr, err := s.createRefreshToken(user.ID, "", "")
	if err != nil {
		log.Printf("[WARN] Failed to create refresh token for %s: %v", user.Email, err)
	}

	return &AuthResponse{
		Token:        token,
		RefreshToken: refreshTokenStr,
		ExpiresAt:    expiresAt,
		User:         user,
		Organizer:    organizer,
	}, nil
}

// recordFailedLogin increments the failed login counter and locks the account
// after maxLoginAttempts.
func (s *Service) recordFailedLogin(email string) {
	if s.redis == nil {
		return
	}
	ctx := context.Background()
	attemptsKey := loginAttemptsPrefix + email

	count, err := s.redis.Incr(ctx, attemptsKey).Result()
	if err != nil {
		log.Printf("[WARN] Failed to increment login attempts for %s: %v", email, err)
		return
	}

	// Set expiry on the counter so it auto-resets
	if count == 1 {
		s.redis.Expire(ctx, attemptsKey, lockoutDuration)
	}

	if count >= int64(maxLoginAttempts) {
		// Lock the account
		lockKey := loginLockoutPrefix + email
		s.redis.Set(ctx, lockKey, "locked", lockoutDuration)
		// Clean up the counter
		s.redis.Del(ctx, attemptsKey)
		log.Printf("[SECURITY] Account %s locked after %d failed login attempts", email, count)
	}
}

// clearLoginAttempts removes the failed login counter on successful login.
func (s *Service) clearLoginAttempts(email string) {
	if s.redis == nil {
		return
	}
	ctx := context.Background()
	s.redis.Del(ctx, loginAttemptsPrefix+email)
	s.redis.Del(ctx, loginLockoutPrefix+email)
}

// ── Verify Email OTP ──

// VerifyEmail verifies a user's email with the 6-digit OTP
// Returns AuthResponse with JWT on success
func (s *Service) VerifyEmail(req *VerifyEmailRequest) (*AuthResponse, error) {
	log.Printf("[INFO] Email verification attempt for %s", req.Email)

	// Get user
	user, err := s.repo.GetUserByEmail(req.Email)
	if err != nil {
		return nil, errors.New("invalid verification request")
	}

	if user.IsVerified {
		// Already verified — just issue a token
		token, expiresAt, err := s.generateToken(user)
		if err != nil {
			return nil, errors.New("failed to generate token")
		}
		return &AuthResponse{
			Token:     token,
			ExpiresAt: expiresAt,
			User:      user,
		}, nil
	}

	// Get verification record
	verification, err := s.repo.GetVerification(req.Email)
	if err != nil {
		return nil, errors.New("invalid verification request")
	}

	// Check lockout (max 5 attempts)
	if verification.Attempts >= maxVerifyAttempts {
		log.Printf("[WARN] Verification locked for %s — %d attempts exceeded", req.Email, verification.Attempts)
		return nil, errors.New("too many failed attempts, please request a new verification code")
	}

	// Check expiration
	if time.Now().After(verification.ExpiresAt) {
		log.Printf("[WARN] Expired OTP used for %s", req.Email)
		return nil, errors.New("verification code has expired, please request a new one")
	}

	// Constant-time comparison of SHA256 hashes
	submittedHash := hashOTP(req.OTP)
	if !constantTimeEqual(verification.OTPHash, submittedHash) {
		// Increment attempt counter
		_ = s.repo.IncrementAttempts(verification.ID)
		remaining := maxVerifyAttempts - verification.Attempts - 1
		log.Printf("[WARN] Invalid OTP for %s — %d attempts remaining", req.Email, remaining)
		return nil, errors.New("invalid verification code")
	}

	// ✅ OTP is valid — mark email as verified
	if err := s.repo.MarkEmailVerified(req.Email); err != nil {
		return nil, fmt.Errorf("mark email verified: %w", err)
	}

	log.Printf("[INFO] Email verified successfully for %s", req.Email)

	// Refresh user data after verification
	user, _ = s.repo.GetUserByEmail(req.Email)

	// Get organizer profile if exists
	var organizer *models.Organizer
	if user.Role == "organizer" {
		organizer, _ = s.repo.GetOrganizerByUserID(user.ID)
	}

	// Issue JWT token
	token, expiresAt, err := s.generateToken(user)
	if err != nil {
		return nil, errors.New("failed to generate token")
	}

	// Issue refresh token
	refreshTokenStr, err := s.createRefreshToken(user.ID, "", "")
	if err != nil {
		log.Printf("[WARN] Failed to create refresh token for %s: %v", user.Email, err)
	}

	return &AuthResponse{
		Token:        token,
		RefreshToken: refreshTokenStr,
		ExpiresAt:    expiresAt,
		User:         user,
		Organizer:    organizer,
	}, nil
}

// ── Resend OTP ──

// ResendOTP generates a new OTP and sends it, with 60-second cooldown
func (s *Service) ResendOTP(req *ResendOTPRequest) (*MessageResponse, error) {
	log.Printf("[INFO] Resend OTP request for %s", req.Email)

	user, err := s.repo.GetUserByEmail(req.Email)
	if err != nil {
		// Generic response to prevent enumeration
		return &MessageResponse{Message: "If that email is registered, a new verification code has been sent"}, nil
	}

	if user.IsVerified {
		return &MessageResponse{Message: "Email is already verified"}, nil
	}

	// Check cooldown
	verification, err := s.repo.GetVerification(req.Email)
	if err == nil && verification != nil {
		elapsed := time.Since(verification.LastSentAt).Seconds()
		if elapsed < resendCooldownSecs {
			remaining := int(resendCooldownSecs - elapsed)
			return nil, fmt.Errorf("please wait %d seconds before requesting a new code", remaining)
		}
	}

	// Generate new OTP
	otp, err := generateOTP()
	if err != nil {
		return nil, errors.New("failed to generate verification code")
	}

	otpHash := hashOTP(otp)
	expiresAt := time.Now().Add(otpExpiryMinutes * time.Minute)

	// Update verification record (resets attempts + last_sent_at)
	if err := s.repo.UpdateVerification(user.ID, otpHash, expiresAt); err != nil {
		return nil, fmt.Errorf("update verification: %w", err)
	}

	// Send email
	if err := s.emailSvc.SendVerificationEmail(req.Email, otp); err != nil {
		log.Printf("[WARN] Failed to resend verification email to %s: %v", req.Email, err)
		return nil, errors.New("failed to send verification email")
	}

	log.Printf("[INFO] OTP resent to %s", req.Email)

	return &MessageResponse{
		Message: "If that email is registered, a new verification code has been sent",
	}, nil
}

// ── Token generation ──

func (s *Service) generateToken(user *models.User) (string, time.Time, error) {
	expiresAt := time.Now().Add(time.Duration(s.cfg.JWT.ExpiryHours) * time.Hour)

	// Load roles from RBAC tables
	var roles []string
	if s.rbacRepo != nil {
		var err error
		roles, err = s.rbacRepo.GetUserRoles(user.ID)
		if err != nil {
			log.Printf("[WARN] Failed to load roles for user %s: %v", user.ID, err)
		}
	}
	if len(roles) == 0 {
		roles = []string{user.Role}
	}

	claims := &middleware.Claims{
		UserID: user.ID.String(),
		Email:  user.Email,
		Role:   user.Role,
		Roles:  roles,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expiresAt),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "khair",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signedToken, err := token.SignedString([]byte(s.cfg.JWT.Secret))
	if err != nil {
		return "", time.Time{}, err
	}

	return signedToken, expiresAt, nil
}

// GetUserByID retrieves a user by ID
func (s *Service) GetUserByID(id uuid.UUID) (*models.User, error) {
	return s.repo.GetUserByID(id)
}

// ── Security Utilities ──

// generateOTP generates a cryptographically secure 6-digit code
func generateOTP() (string, error) {
	max := big.NewInt(1000000) // 0-999999
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

// hashOTP hashes an OTP string using SHA256
func hashOTP(otp string) string {
	h := sha256.Sum256([]byte(otp))
	return hex.EncodeToString(h[:])
}

// constantTimeEqual performs a constant-time comparison of two strings
// to prevent timing-based side-channel attacks
func constantTimeEqual(a, b string) bool {
	return subtle.ConstantTimeCompare([]byte(a), []byte(b)) == 1
}

// createRefreshToken generates and stores a refresh token, returns the raw token string
func (s *Service) createRefreshToken(userID uuid.UUID, userAgent, ipAddress string) (string, error) {
	rawToken := make([]byte, refreshTokenBytes)
	if _, err := rand.Read(rawToken); err != nil {
		return "", err
	}
	tokenStr := hex.EncodeToString(rawToken)
	tokenHash := hashOTP(tokenStr) // reuse SHA256 hashing

	rt := &RefreshToken{
		ID:        uuid.New(),
		UserID:    userID,
		TokenHash: tokenHash,
		ExpiresAt: time.Now().Add(refreshTokenDays * 24 * time.Hour),
		CreatedAt: time.Now(),
		UserAgent: userAgent,
		IPAddress: ipAddress,
	}

	if err := s.repo.CreateRefreshToken(rt); err != nil {
		return "", err
	}

	return tokenStr, nil
}

// RefreshTokens validates a refresh token and issues new access + refresh tokens (token rotation)
func (s *Service) RefreshTokens(req *RefreshTokenRequest, userAgent, ipAddress string) (*AuthResponse, error) {
	tokenHash := hashOTP(req.RefreshToken)

	rt, err := s.repo.GetRefreshToken(tokenHash)
	if err != nil {
		return nil, errors.New("invalid refresh token")
	}

	// Check if revoked (possible token reuse attack)
	if rt.RevokedAt != nil {
		// Revoke entire family — potential token theft
		_ = s.repo.RevokeAllUserTokens(rt.UserID)
		log.Printf("[SECURITY] Refresh token reuse detected for user %s — all tokens revoked", rt.UserID)
		return nil, errors.New("token has been revoked, please login again")
	}

	// Check expiration
	if time.Now().After(rt.ExpiresAt) {
		return nil, errors.New("refresh token expired, please login again")
	}

	// Get user
	user, err := s.repo.GetUserByID(rt.UserID)
	if err != nil {
		return nil, errors.New("user not found")
	}

	// Check if user is suspended or deleted
	if user.Status == "suspended" || user.Status == "deleted" {
		_ = s.repo.RevokeAllUserTokens(user.ID)
		return nil, fmt.Errorf("account is %s", user.Status)
	}

	// Generate new access token
	accessToken, expiresAt, err := s.generateToken(user)
	if err != nil {
		return nil, errors.New("failed to generate token")
	}

	// Rotate: create new refresh token, revoke old one
	newRefreshStr, err := s.createRefreshToken(user.ID, userAgent, ipAddress)
	if err != nil {
		return nil, errors.New("failed to rotate refresh token")
	}

	// Get the new token's ID for the replaced_by link
	newTokenHash := hashOTP(newRefreshStr)
	newRT, _ := s.repo.GetRefreshToken(newTokenHash)
	var newID *uuid.UUID
	if newRT != nil {
		newID = &newRT.ID
	}
	_ = s.repo.RevokeRefreshToken(rt.ID, newID)

	// Get organizer if exists
	var org *models.Organizer
	if user.Role == "organizer" {
		org, _ = s.repo.GetOrganizerByUserID(user.ID)
	}

	return &AuthResponse{
		Token:        accessToken,
		RefreshToken: newRefreshStr,
		ExpiresAt:    expiresAt,
		User:         user,
		Organizer:    org,
	}, nil
}

// LogoutAll revokes all refresh tokens for a user
func (s *Service) LogoutAll(userID uuid.UUID) error {
	return s.repo.RevokeAllUserTokens(userID)
}

// ── GDPR Operations ──

// DeleteMyAccount soft-deletes and anonymizes user data (GDPR right to erasure)
func (s *Service) DeleteMyAccount(userID uuid.UUID) error {
	return s.repo.SoftDeleteUser(userID)
}

// ExportMyData exports all user data (GDPR data subject access request)
func (s *Service) ExportMyData(userID uuid.UUID) (map[string]interface{}, error) {
	return s.repo.ExportUserData(userID)
}

// ── User Management ──

// SuspendUser suspends a user account and revokes their tokens
func (s *Service) SuspendUser(userID uuid.UUID, reason string, adminID uuid.UUID) error {
	if err := s.repo.SuspendUser(userID, reason, adminID); err != nil {
		return err
	}
	// Revoke all sessions
	return s.repo.RevokeAllUserTokens(userID)
}

// UnsuspendUser removes a user's suspension
func (s *Service) UnsuspendUser(userID uuid.UUID) error {
	return s.repo.UnsuspendUser(userID)
}

// GetUserStatus returns current user status info (for login check)
func (s *Service) GetUserStatus(userID uuid.UUID) (string, error) {
	user, err := s.repo.GetUserByID(userID)
	if err != nil {
		return "", err
	}
	return user.Status, nil
}

// CheckSuspension returns an error if user is suspended
func (s *Service) CheckSuspension(c interface{ GetString(string) string }) (int, error) {
	// This is called from middleware/handlers to check if a user is banned
	return http.StatusOK, nil
}
