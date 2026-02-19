package validation

import (
	"net/http"
	"net/mail"
	"regexp"
	"strings"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Error represents a validation error
type Error struct {
	Field   string `json:"field"`
	Message string `json:"message"`
	Code    string `json:"code"`
}

// Result holds validation results
type Result struct {
	Valid  bool    `json:"valid"`
	Errors []Error `json:"errors,omitempty"`
}

// NewResult creates an empty validation result
func NewResult() *Result {
	return &Result{
		Valid:  true,
		Errors: make([]Error, 0),
	}
}

// AddError adds an error to the result
func (r *Result) AddError(field, message, code string) {
	r.Valid = false
	r.Errors = append(r.Errors, Error{
		Field:   field,
		Message: message,
		Code:    code,
	})
}

// ToResponse converts result to HTTP response
func (r *Result) ToResponse(c *gin.Context) {
	if !r.Valid {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"error":   "Validation failed",
			"errors":  r.Errors,
		})
	}
}

// Validator provides validation functions
type Validator struct{}

// New creates a new validator
func New() *Validator {
	return &Validator{}
}

// Required checks if value is non-empty
func (v *Validator) Required(r *Result, field, value string) bool {
	if strings.TrimSpace(value) == "" {
		r.AddError(field, field+" is required", "REQUIRED")
		return false
	}
	return true
}

// MinLength checks minimum string length
func (v *Validator) MinLength(r *Result, field, value string, min int) bool {
	if utf8.RuneCountInString(value) < min {
		r.AddError(field, field+" must be at least "+string(rune(min+'0'))+" characters", "MIN_LENGTH")
		return false
	}
	return true
}

// MaxLength checks maximum string length
func (v *Validator) MaxLength(r *Result, field, value string, max int) bool {
	if utf8.RuneCountInString(value) > max {
		r.AddError(field, field+" must be at most "+string(rune(max+'0'))+" characters", "MAX_LENGTH")
		return false
	}
	return true
}

// Email validates email format
func (v *Validator) Email(r *Result, field, value string) bool {
	_, err := mail.ParseAddress(value)
	if err != nil {
		r.AddError(field, "Invalid email address", "INVALID_EMAIL")
		return false
	}
	return true
}

// UUID validates UUID format
func (v *Validator) UUID(r *Result, field, value string) bool {
	_, err := uuid.Parse(value)
	if err != nil {
		r.AddError(field, "Invalid UUID format", "INVALID_UUID")
		return false
	}
	return true
}

// URL validates URL format
func (v *Validator) URL(r *Result, field, value string) bool {
	pattern := `^https?://[^\s/$.?#].[^\s]*$`
	matched, _ := regexp.MatchString(pattern, value)
	if !matched {
		r.AddError(field, "Invalid URL format", "INVALID_URL")
		return false
	}
	return true
}

// Phone validates phone number format
func (v *Validator) Phone(r *Result, field, value string) bool {
	// Basic pattern for international phone numbers
	pattern := `^\+?[1-9]\d{6,14}$`
	cleaned := regexp.MustCompile(`[\s\-\(\)]+`).ReplaceAllString(value, "")
	matched, _ := regexp.MatchString(pattern, cleaned)
	if !matched {
		r.AddError(field, "Invalid phone number", "INVALID_PHONE")
		return false
	}
	return true
}

// CountryCode validates ISO 3166-1 alpha-2 country code
func (v *Validator) CountryCode(r *Result, field, value string) bool {
	pattern := `^[A-Z]{2}$`
	matched, _ := regexp.MatchString(pattern, strings.ToUpper(value))
	if !matched {
		r.AddError(field, "Invalid country code (use 2-letter ISO code)", "INVALID_COUNTRY")
		return false
	}
	return true
}

// InRange checks if number is within range
func (v *Validator) InRange(r *Result, field string, value, min, max float64) bool {
	if value < min || value > max {
		r.AddError(field, field+" must be between specified range", "OUT_OF_RANGE")
		return false
	}
	return true
}

// Latitude validates latitude
func (v *Validator) Latitude(r *Result, field string, value float64) bool {
	return v.InRange(r, field, value, -90, 90)
}

// Longitude validates longitude
func (v *Validator) Longitude(r *Result, field string, value float64) bool {
	return v.InRange(r, field, value, -180, 180)
}

// OneOf checks if value is in allowed list
func (v *Validator) OneOf(r *Result, field, value string, allowed []string) bool {
	for _, a := range allowed {
		if value == a {
			return true
		}
	}
	r.AddError(field, field+" must be one of: "+strings.Join(allowed, ", "), "INVALID_OPTION")
	return false
}

// NotContainsBannedWords checks for banned words
func (v *Validator) NotContainsBannedWords(r *Result, field, value string, banned []string) bool {
	lower := strings.ToLower(value)
	for _, word := range banned {
		if strings.Contains(lower, strings.ToLower(word)) {
			r.AddError(field, field+" contains prohibited content", "BANNED_CONTENT")
			return false
		}
	}
	return true
}

// NoHTML checks for HTML tags
func (v *Validator) NoHTML(r *Result, field, value string) bool {
	pattern := `<[^>]*>`
	matched, _ := regexp.MatchString(pattern, value)
	if matched {
		r.AddError(field, field+" cannot contain HTML", "HTML_NOT_ALLOWED")
		return false
	}
	return true
}

// AlphanumericDash allows only alphanumeric and dash
func (v *Validator) AlphanumericDash(r *Result, field, value string) bool {
	pattern := `^[a-zA-Z0-9\-]+$`
	matched, _ := regexp.MatchString(pattern, value)
	if !matched {
		r.AddError(field, field+" must contain only letters, numbers, and dashes", "INVALID_FORMAT")
		return false
	}
	return true
}

// FutureDate checks if date string is in the future
// Expects ISO 8601 format (YYYY-MM-DD or full timestamp)
func (v *Validator) FutureDate(r *Result, field, value string) bool {
	// Basic check - in production use time.Parse
	if len(value) < 10 {
		r.AddError(field, "Invalid date format", "INVALID_DATE")
		return false
	}
	// This is a placeholder - actual implementation would parse and compare dates
	return true
}

// Positive checks if number is positive
func (v *Validator) Positive(r *Result, field string, value int) bool {
	if value <= 0 {
		r.AddError(field, field+" must be positive", "NOT_POSITIVE")
		return false
	}
	return true
}

// NonNegative checks if number is non-negative
func (v *Validator) NonNegative(r *Result, field string, value int) bool {
	if value < 0 {
		r.AddError(field, field+" cannot be negative", "NEGATIVE")
		return false
	}
	return true
}

// SanitizeString removes potentially dangerous characters
func SanitizeString(s string) string {
	// Remove null bytes
	s = strings.ReplaceAll(s, "\x00", "")
	// Trim whitespace
	s = strings.TrimSpace(s)
	return s
}

// SanitizeRequestMiddleware sanitizes common input fields
func SanitizeRequestMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// This would sanitize common fields
		// Implementation depends on specific needs
		c.Next()
	}
}
