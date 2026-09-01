package models

import (
	"database/sql"
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// PricingInfo represents the structured pricing for an event
type PricingInfo struct {
	Type          string  `json:"type"`                     // "free" or "paid"
	AmountCents   *int64  `json:"amount_cents,omitempty"`   // E.g., 500 for $5.00
	Currency      *string `json:"currency,omitempty"`       // ISO currency code (e.g., "USD")
	PaymentMethod *string `json:"payment_method,omitempty"` // E.g., "pay_at_venue"
}

// Role constants
const (
	RoleUser      = "user"
	RoleAdmin     = "admin"
	RoleOrganizer = "organizer"
)

// ValidRoles returns all valid user roles
func ValidRoles() []string {
	return []string{RoleUser, RoleOrganizer, RoleAdmin}
}

// User represents a user in the system
type User struct {
	ID           uuid.UUID  `json:"id"`
	Email        string     `json:"email"`
	PasswordHash string     `json:"-"`
	Role         string     `json:"role"`
	Status       string     `json:"status"`
	DisplayName  *string    `json:"display_name,omitempty"`
	Gender       *string    `json:"gender,omitempty"`
	Age          *int       `json:"age,omitempty"`
	IsVerified   bool       `json:"is_verified"`
	VerifiedAt   *time.Time `json:"verified_at,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
}

// Profile represents a user's extended profile
type Profile struct {
	ID                     uuid.UUID `json:"id"`
	UserID                 uuid.UUID `json:"user_id"`
	Bio                    *string   `json:"bio,omitempty"`
	Location               *string   `json:"location,omitempty"`
	City                   *string   `json:"city,omitempty"`
	Country                *string   `json:"country,omitempty"`
	AvatarURL              *string   `json:"avatar_url,omitempty"`
	PreferredLanguage      string    `json:"preferred_language"`
	ProfileCompletionScore int       `json:"profile_completion_score"`
	CreatedAt              time.Time `json:"created_at"`
	UpdatedAt              time.Time `json:"updated_at"`
}

// RegistrationDraft holds partial registration data for save-and-continue
type RegistrationDraft struct {
	ID          uuid.UUID       `json:"id"`
	Email       string          `json:"email"`
	CurrentStep int             `json:"current_step"`
	Role        *string         `json:"role,omitempty"`
	FormData    json.RawMessage `json:"form_data"`
	IPAddress   *string         `json:"-"`
	ExpiresAt   time.Time       `json:"expires_at"`
	CreatedAt   time.Time       `json:"created_at"`
	UpdatedAt   time.Time       `json:"updated_at"`
}

// RegistrationAuditLog tracks registration events
type RegistrationAuditLog struct {
	ID        uuid.UUID       `json:"id"`
	UserID    *uuid.UUID      `json:"user_id,omitempty"`
	Email     *string         `json:"email,omitempty"`
	Step      *int            `json:"step,omitempty"`
	Action    string          `json:"action"`
	Details   json.RawMessage `json:"details,omitempty"`
	IPAddress *string         `json:"-"`
	UserAgent *string         `json:"-"`
	CreatedAt time.Time       `json:"created_at"`
}

// Organizer represents an organization profile
type Organizer struct {
	ID                     uuid.UUID `json:"id"`
	UserID                 uuid.UUID `json:"user_id"`
	Name                   string    `json:"name"`
	Description            *string   `json:"description,omitempty"`
	Website                *string   `json:"website,omitempty"`
	Phone                  *string   `json:"phone,omitempty"`
	LogoURL                *string   `json:"logo_url,omitempty"`
	Status                 string    `json:"status"`
	RejectionReason        *string   `json:"rejection_reason,omitempty"`
	RegistrationNumber     *string   `json:"registration_number,omitempty"`
	OrganizationType       *string   `json:"organization_type,omitempty"`
	City                   *string   `json:"city,omitempty"`
	Country                *string   `json:"country,omitempty"`
	TrustLevel             string    `json:"trust_level"`
	ProfileCompletionScore int       `json:"profile_completion_score"`
	ContactEmail           *string   `json:"contact_email,omitempty"`
	CreatedAt              time.Time `json:"created_at"`
	UpdatedAt              time.Time `json:"updated_at"`
}

// Event represents an event
type Event struct {
	ID                               uuid.UUID    `json:"id"`
	OrganizerID                      uuid.UUID    `json:"organizer_id"`
	Title                            string       `json:"title"`
	Description                      *string      `json:"description,omitempty"`
	EventType                        string       `json:"event_type"`
	Category                         string       `json:"category"`
	Tags                             []string     `json:"tags,omitempty"`
	Language                         *string      `json:"language,omitempty"`
	Country                          *string      `json:"country,omitempty"`
	City                             *string      `json:"city,omitempty"`
	Address                          *string      `json:"address,omitempty"`
	Latitude                         *float64     `json:"latitude,omitempty"`
	Longitude                        *float64     `json:"longitude,omitempty"`
	StartDate                        time.Time    `json:"start_date"`
	EndDate                          *time.Time   `json:"end_date,omitempty"`
	ImageURL                         *string      `json:"image_url,omitempty"`
	Capacity                         *int         `json:"capacity,omitempty"`
	ReservedCount                    int          `json:"reserved_count"`
	GenderRestriction                *string      `json:"gender_restriction,omitempty"`
	AttendancePolicy                 string       `json:"attendance_policy"`
	AgeMin                           *int         `json:"age_min,omitempty"`
	AgeMax                           *int         `json:"age_max,omitempty"`
	Pricing                          *PricingInfo `json:"pricing,omitempty"`
	Status                           string       `json:"status"`
	IsPublished                      bool         `json:"is_published"`
	IsOnline                         bool         `json:"is_online"`
	OnlineLink                       *string      `json:"online_link,omitempty"`
	JoinInstructions                 *string      `json:"join_instructions,omitempty"`
	JoinLinkVisibleBeforeMinutes     int          `json:"join_link_visible_before_minutes"`
	VenueName                        *string      `json:"venue_name,omitempty"`
	OnlinePlatform                   *string      `json:"online_platform,omitempty"`
	RegistrationDeadline             *time.Time   `json:"registration_deadline,omitempty"`
	RegistrationMode                 string       `json:"registration_mode"`
	RegistrationRequired             bool         `json:"registration_required"`
	RegistrationType                 string       `json:"registration_type"`
	ExternalPlatformName             *string      `json:"external_platform_name,omitempty"`
	ExternalRegistrationURL          *string      `json:"external_registration_url,omitempty"`
	ExternalRegistrationInstructions *string      `json:"external_registration_instructions,omitempty"`
	RegistrationRequirements         *string      `json:"registration_requirements,omitempty"`
	ApplicationApprovalRequired      bool         `json:"application_approval_required"`
	Timezone                         string       `json:"timezone"`
	OrganizerGuidelines              *string      `json:"organizer_guidelines,omitempty"`
	RejectionReason                  *string      `json:"rejection_reason,omitempty"`
	ReviewedBy                       *uuid.UUID   `json:"reviewed_by,omitempty"`
	ReviewedAt                       *time.Time   `json:"reviewed_at,omitempty"`
	ApprovedAt                       *time.Time   `json:"approved_at,omitempty"`
	CreatedAt                        time.Time    `json:"created_at"`
	UpdatedAt                        time.Time    `json:"updated_at"`
}

// EventRegistration represents a user's event seat reservation
type EventRegistration struct {
	ID                        uuid.UUID  `json:"id"`
	UserID                    uuid.UUID  `json:"user_id"`
	EventID                   uuid.UUID  `json:"event_id"`
	Status                    string     `json:"status"`
	ReservedUntil             *time.Time `json:"reserved_until,omitempty"`
	Attended                  bool       `json:"attended"`
	EligibilityReviewRequired bool       `json:"eligibility_review_required,omitempty"`
	EligibilityReviewedAt     *time.Time `json:"eligibility_reviewed_at,omitempty"`
	CreatedAt                 time.Time  `json:"created_at"`
	UpdatedAt                 time.Time  `json:"updated_at"`
}

// EventWithOrganizer represents an event with organizer details
type EventWithOrganizer struct {
	Event
	OrganizerName string `json:"organizer_name"`
}

// EventUpdateRequest is an organizer-submitted replacement for an already
// approved event. The live event remains unchanged until an administrator
// approves the proposed snapshot.
type EventUpdateRequest struct {
	ID              uuid.UUID  `json:"id"`
	EventID         uuid.UUID  `json:"event_id"`
	OrganizerID     uuid.UUID  `json:"organizer_id"`
	ProposedEvent   Event      `json:"proposed_event"`
	Status          string     `json:"status"`
	RejectionReason *string    `json:"rejection_reason,omitempty"`
	RequestedBy     *uuid.UUID `json:"requested_by,omitempty"`
	ReviewedBy      *uuid.UUID `json:"reviewed_by,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	ReviewedAt      *time.Time `json:"reviewed_at,omitempty"`
}

// ── Organization Dashboard Models ──

// OrgRole constants for organization RBAC
const (
	OrgRoleOwner        = "owner"
	OrgRoleAdmin        = "admin"
	OrgRoleEventManager = "event_manager"
	OrgRoleViewer       = "viewer"
)

// OrgRoleLevel returns the permission level for a role (higher = more access)
func OrgRoleLevel(role string) int {
	switch role {
	case OrgRoleOwner:
		return 4
	case OrgRoleAdmin:
		return 3
	case OrgRoleEventManager:
		return 2
	case OrgRoleViewer:
		return 1
	default:
		return 0
	}
}

// OrganizationMember represents a user's membership in an organization
type OrganizationMember struct {
	ID             uuid.UUID `json:"id"`
	OrganizationID uuid.UUID `json:"organization_id"`
	UserID         uuid.UUID `json:"user_id"`
	Role           string    `json:"role"`
	JoinedAt       time.Time `json:"joined_at"`
	// Joined fields for display
	UserEmail   string  `json:"user_email,omitempty"`
	DisplayName *string `json:"display_name,omitempty"`
}

// OrgAuditLog represents an audit log entry for an organization
type OrgAuditLog struct {
	ID             uuid.UUID       `json:"id"`
	OrganizationID uuid.UUID       `json:"organization_id"`
	ActorID        uuid.UUID       `json:"actor_id"`
	Action         string          `json:"action"`
	TargetType     *string         `json:"target_type,omitempty"`
	TargetID       *uuid.UUID      `json:"target_id,omitempty"`
	Metadata       json.RawMessage `json:"metadata,omitempty"`
	IPAddress      *string         `json:"-"`
	CreatedAt      time.Time       `json:"created_at"`
	// Joined
	ActorEmail string `json:"actor_email,omitempty"`
}

// DashboardStats holds overview statistics for the org dashboard
type DashboardStats struct {
	TotalEvents            int     `json:"total_events"`
	UpcomingEvents         int     `json:"upcoming_events"`
	PastEvents             int     `json:"past_events"`
	TotalAttendees         int     `json:"total_attendees"`
	ConfirmedAttendees     int     `json:"confirmed_attendees"`
	EventFillRate          float64 `json:"event_fill_rate"`
	ProfileCompletionScore int     `json:"profile_completion_score"`
	TrustLevel             string  `json:"trust_level"`
}

// AnalyticsData holds analytics data for charts
type AnalyticsData struct {
	AttendanceTrend []TrendPoint       `json:"attendance_trend"`
	GenderDist      []DistributionItem `json:"gender_distribution"`
	AgeDist         []DistributionItem `json:"age_distribution"`
	EventPopularity []EventRanking     `json:"event_popularity"`
	ConversionRate  float64            `json:"conversion_rate"`
	TotalViews      int                `json:"total_views"`
	TotalJoins      int                `json:"total_joins"`
}

// TrendPoint is a single data point for trend charts
type TrendPoint struct {
	Date  string `json:"date"`
	Count int    `json:"count"`
}

// DistributionItem is a label+value pair for distribution charts
type DistributionItem struct {
	Label string `json:"label"`
	Count int    `json:"count"`
}

// EventRanking ranks events by attendance
type EventRanking struct {
	EventID       uuid.UUID `json:"event_id"`
	Title         string    `json:"title"`
	Capacity      *int      `json:"capacity,omitempty"`
	ReservedCount int       `json:"reserved_count"`
	AttendedCount int       `json:"attended_count"`
}

// AttendeeInfo is a joined view of an event registration with user details
type AttendeeInfo struct {
	RegistrationID uuid.UUID  `json:"registration_id"`
	UserID         uuid.UUID  `json:"user_id"`
	Email          string     `json:"email"`
	DisplayName    *string    `json:"display_name,omitempty"`
	Status         string     `json:"status"`
	Attended       bool       `json:"attended"`
	ReservedUntil  *time.Time `json:"reserved_until,omitempty"`
	RegisteredAt   time.Time  `json:"registered_at"`
}

// ── Geo & Verification Models ──

// Verification status constants
const (
	VerificationNone          = "none"
	VerificationPendingReview = "pending_review"
	VerificationVerified      = "verified"
	VerificationRejected      = "rejected"
)

// RoleRequiresVerification returns true if the role needs document verification
func RoleRequiresVerification(role string) bool {
	switch role {
	case RoleOrganizer:
		return true
	default:
		return false
	}
}

// Country represents a country record
type Country struct {
	ID        int       `json:"id"`
	Name      string    `json:"name"`
	ISOCode   string    `json:"iso_code"`
	ISO3Code  *string   `json:"iso3_code,omitempty"`
	PhoneCode string    `json:"phone_code"`
	FlagEmoji string    `json:"flag_emoji"`
	Region    string    `json:"region"`
	IsActive  bool      `json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
}

// UserGoal represents a user's selected goal
type UserGoal struct {
	ID        int       `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	GoalKey   string    `json:"goal_key"`
	CreatedAt time.Time `json:"created_at"`
}

// VerificationRequest represents an organizer verification submission
type VerificationRequest struct {
	ID               uuid.UUID  `json:"id"`
	UserID           uuid.UUID  `json:"user_id"`
	ProfileImagePath *string    `json:"profile_image_path,omitempty"`
	DocumentPath     *string    `json:"document_path,omitempty"`
	DocumentType     string     `json:"document_type"`
	Notes            *string    `json:"notes,omitempty"`
	Status           string     `json:"status"`
	ReviewedBy       *uuid.UUID `json:"reviewed_by,omitempty"`
	ReviewedAt       *time.Time `json:"reviewed_at,omitempty"`
	ReviewNotes      *string    `json:"review_notes,omitempty"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
}

// Unused import guard
var _ = sql.ErrNoRows
