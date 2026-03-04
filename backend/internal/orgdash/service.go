package orgdash

import (
	"database/sql"
	"errors"
	"time"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
)

// Service handles organization dashboard business logic
type Service struct {
	repo *Repository
}

// NewService creates a new orgdash service
func NewService(db *sql.DB) *Service {
	return &Service{repo: NewRepository(db)}
}

// GetRepository returns the repository for external use
func (s *Service) GetRepository() *Repository {
	return s.repo
}

// GetDashboardStats returns overview statistics
func (s *Service) GetDashboardStats(orgID uuid.UUID) (*models.DashboardStats, error) {
	return s.repo.GetDashboardStats(orgID)
}

// GetAnalytics returns full analytics data
func (s *Service) GetAnalytics(orgID uuid.UUID) (*models.AnalyticsData, error) {
	data := &models.AnalyticsData{}

	trend, err := s.repo.GetAttendanceTrend(orgID, 30)
	if err != nil {
		return nil, err
	}
	data.AttendanceTrend = trend

	gender, err := s.repo.GetGenderDistribution(orgID)
	if err != nil {
		return nil, err
	}
	data.GenderDist = gender

	age, err := s.repo.GetAgeDistribution(orgID)
	if err != nil {
		return nil, err
	}
	data.AgeDist = age

	popularity, err := s.repo.GetEventPopularity(orgID, 10)
	if err != nil {
		return nil, err
	}
	data.EventPopularity = popularity

	totalReserved, totalConfirmed, err := s.repo.GetConversionRate(orgID)
	if err != nil {
		return nil, err
	}
	data.TotalViews = totalReserved
	data.TotalJoins = totalConfirmed
	if totalReserved > 0 {
		data.ConversionRate = float64(totalConfirmed) / float64(totalReserved) * 100
	}

	return data, nil
}

// GetRecentActivity returns recent audit log entries
func (s *Service) GetRecentActivity(orgID uuid.UUID, limit int) ([]models.OrgAuditLog, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	return s.repo.GetRecentActivity(orgID, limit)
}

// LogAction logs an audit action
func (s *Service) LogAction(orgID, actorID uuid.UUID, action string, targetType *string, targetID *uuid.UUID, metadata interface{}, ipAddress *string) {
	_ = s.repo.LogAction(orgID, actorID, action, targetType, targetID, metadata, ipAddress)
}

// ── Event Management ──

// CreateEventRequest is the DTO for creating events
type CreateEventRequest struct {
	Title             string     `json:"title" binding:"required,min=3,max=255"`
	Description       *string    `json:"description"`
	EventType         string     `json:"event_type" binding:"required"`
	Language          *string    `json:"language"`
	Country           *string    `json:"country"`
	City              *string    `json:"city"`
	Address           *string    `json:"address"`
	Latitude          *float64   `json:"latitude"`
	Longitude         *float64   `json:"longitude"`
	StartDate         time.Time  `json:"start_date" binding:"required"`
	EndDate           *time.Time `json:"end_date"`
	ImageURL          *string    `json:"image_url"`
	Capacity          *int       `json:"capacity"`
	GenderRestriction *string    `json:"gender_restriction"`
	AgeMin            *int       `json:"age_min"`
	AgeMax            *int       `json:"age_max"`
}

// UpdateEventRequest is the DTO for updating events
type UpdateEventRequest struct {
	Title             *string    `json:"title"`
	Description       *string    `json:"description"`
	EventType         *string    `json:"event_type"`
	Language          *string    `json:"language"`
	Country           *string    `json:"country"`
	City              *string    `json:"city"`
	Address           *string    `json:"address"`
	Latitude          *float64   `json:"latitude"`
	Longitude         *float64   `json:"longitude"`
	StartDate         *time.Time `json:"start_date"`
	EndDate           *time.Time `json:"end_date"`
	ImageURL          *string    `json:"image_url"`
	Capacity          *int       `json:"capacity"`
	GenderRestriction *string    `json:"gender_restriction"`
	AgeMin            *int       `json:"age_min"`
	AgeMax            *int       `json:"age_max"`
}

// ListOrgEvents lists events for an organization
func (s *Service) ListOrgEvents(orgID uuid.UUID, status *string, page, pageSize int) ([]models.Event, int64, error) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}
	return s.repo.ListOrgEvents(orgID, status, page, pageSize)
}

// CreateEvent creates a new event for the organization
func (s *Service) CreateEvent(orgID uuid.UUID, req *CreateEventRequest) (*models.Event, error) {
	if req.Capacity != nil && *req.Capacity < 1 {
		return nil, errors.New("capacity must be at least 1")
	}
	if req.AgeMin != nil && req.AgeMax != nil && *req.AgeMin > *req.AgeMax {
		return nil, errors.New("age_min must be less than age_max")
	}

	ev := &models.Event{
		OrganizerID:       orgID,
		Title:             req.Title,
		Description:       req.Description,
		EventType:         req.EventType,
		Language:          req.Language,
		Country:           req.Country,
		City:              req.City,
		Address:           req.Address,
		Latitude:          req.Latitude,
		Longitude:         req.Longitude,
		StartDate:         req.StartDate,
		EndDate:           req.EndDate,
		ImageURL:          req.ImageURL,
		Capacity:          req.Capacity,
		GenderRestriction: req.GenderRestriction,
		AgeMin:            req.AgeMin,
		AgeMax:            req.AgeMax,
		Status:            "draft",
	}

	if err := s.repo.CreateEvent(ev); err != nil {
		return nil, err
	}
	return ev, nil
}

// UpdateEvent updates an existing event
func (s *Service) UpdateEvent(orgID uuid.UUID, eventID uuid.UUID, req *UpdateEventRequest) (*models.Event, error) {
	ev, err := s.repo.GetEventByID(eventID, orgID)
	if err != nil {
		return nil, errors.New("event not found")
	}

	if req.Title != nil {
		ev.Title = *req.Title
	}
	if req.Description != nil {
		ev.Description = req.Description
	}
	if req.EventType != nil {
		ev.EventType = *req.EventType
	}
	if req.Language != nil {
		ev.Language = req.Language
	}
	if req.Country != nil {
		ev.Country = req.Country
	}
	if req.City != nil {
		ev.City = req.City
	}
	if req.Address != nil {
		ev.Address = req.Address
	}
	if req.Latitude != nil {
		ev.Latitude = req.Latitude
	}
	if req.Longitude != nil {
		ev.Longitude = req.Longitude
	}
	if req.StartDate != nil {
		ev.StartDate = *req.StartDate
	}
	if req.EndDate != nil {
		ev.EndDate = req.EndDate
	}
	if req.ImageURL != nil {
		ev.ImageURL = req.ImageURL
	}
	if req.Capacity != nil {
		if *req.Capacity < ev.ReservedCount {
			return nil, errors.New("cannot reduce capacity below current reservations")
		}
		ev.Capacity = req.Capacity
	}
	if req.GenderRestriction != nil {
		ev.GenderRestriction = req.GenderRestriction
	}
	if req.AgeMin != nil {
		ev.AgeMin = req.AgeMin
	}
	if req.AgeMax != nil {
		ev.AgeMax = req.AgeMax
	}

	if err := s.repo.UpdateEvent(ev); err != nil {
		return nil, err
	}
	return ev, nil
}

// CancelEvent cancels an event
func (s *Service) CancelEvent(orgID, eventID uuid.UUID) error {
	_, err := s.repo.GetEventByID(eventID, orgID)
	if err != nil {
		return errors.New("event not found")
	}
	return s.repo.CancelEvent(eventID)
}

// DuplicateEvent creates a copy of an event
func (s *Service) DuplicateEvent(orgID, eventID uuid.UUID) (*models.Event, error) {
	return s.repo.DuplicateEvent(eventID, orgID)
}

// ── Members ──

// ListMembers lists organization members
func (s *Service) ListMembers(orgID uuid.UUID) ([]models.OrganizationMember, error) {
	return s.repo.ListMembers(orgID)
}

// AddMember adds a user to the organization by email
func (s *Service) AddMember(orgID uuid.UUID, email, role string) (*models.OrganizationMember, error) {
	// Validate role
	if models.OrgRoleLevel(role) == 0 {
		return nil, errors.New("invalid role")
	}
	if role == models.OrgRoleOwner {
		return nil, errors.New("cannot assign owner role via invitation")
	}

	userID, err := s.repo.FindUserByEmail(email)
	if err != nil {
		return nil, errors.New("user not found with that email")
	}

	return s.repo.AddMember(orgID, userID, role)
}

// UpdateMemberRole changes a member's role
func (s *Service) UpdateMemberRole(memberID uuid.UUID, newRole string) error {
	if models.OrgRoleLevel(newRole) == 0 {
		return errors.New("invalid role")
	}

	member, err := s.repo.GetMemberByID(memberID)
	if err != nil {
		return errors.New("member not found")
	}
	if member.Role == models.OrgRoleOwner {
		return errors.New("cannot change the owner's role")
	}
	if newRole == models.OrgRoleOwner {
		return errors.New("cannot promote to owner")
	}

	return s.repo.UpdateMemberRole(memberID, newRole)
}

// RemoveMember removes a member from the organization
func (s *Service) RemoveMember(memberID uuid.UUID) error {
	member, err := s.repo.GetMemberByID(memberID)
	if err != nil {
		return errors.New("member not found")
	}
	if member.Role == models.OrgRoleOwner {
		return errors.New("cannot remove the owner")
	}
	return s.repo.RemoveMember(memberID)
}

// ── Profile ──

// UpdateProfileRequest DTO for profile updates
type UpdateOrgProfileRequest struct {
	Name         *string `json:"name"`
	Description  *string `json:"description"`
	Website      *string `json:"website"`
	Phone        *string `json:"phone"`
	LogoURL      *string `json:"logo_url"`
	ContactEmail *string `json:"contact_email"`
	City         *string `json:"city"`
	Country      *string `json:"country"`
}

// GetProfile returns the org profile
func (s *Service) GetProfile(orgID uuid.UUID) (*models.Organizer, error) {
	org, err := s.repo.GetOrgProfile(orgID)
	if err != nil {
		return nil, err
	}
	org.ProfileCompletionScore = s.calculateCompletion(org)
	return org, nil
}

// UpdateProfile updates the org profile
func (s *Service) UpdateProfile(orgID uuid.UUID, req *UpdateOrgProfileRequest) (*models.Organizer, error) {
	org, err := s.repo.GetOrgProfile(orgID)
	if err != nil {
		return nil, errors.New("organization not found")
	}

	if req.Name != nil {
		org.Name = *req.Name
	}
	if req.Description != nil {
		org.Description = req.Description
	}
	if req.Website != nil {
		org.Website = req.Website
	}
	if req.Phone != nil {
		org.Phone = req.Phone
	}
	if req.LogoURL != nil {
		org.LogoURL = req.LogoURL
	}
	if req.ContactEmail != nil {
		org.ContactEmail = req.ContactEmail
	}
	if req.City != nil {
		org.City = req.City
	}
	if req.Country != nil {
		org.Country = req.Country
	}

	org.ProfileCompletionScore = s.calculateCompletion(org)

	if err := s.repo.UpdateOrgProfile(org); err != nil {
		return nil, err
	}

	// Auto-update trust level
	s.updateTrustLevel(orgID, org.ProfileCompletionScore)

	return org, nil
}

// calculateCompletion calculates profile completion percentage
func (s *Service) calculateCompletion(org *models.Organizer) int {
	score := 0
	total := 7

	if org.Name != "" {
		score++
	}
	if org.Description != nil && *org.Description != "" {
		score++
	}
	if org.City != nil && *org.City != "" {
		score++
	}
	if org.LogoURL != nil && *org.LogoURL != "" {
		score++
	}
	if org.ContactEmail != nil && *org.ContactEmail != "" {
		score++
	}
	if org.Website != nil && *org.Website != "" {
		score++
	}
	if org.Phone != nil && *org.Phone != "" {
		score++
	}

	return (score * 100) / total
}

// updateTrustLevel automatically updates trust level based on profile and activity
func (s *Service) updateTrustLevel(orgID uuid.UUID, completionScore int) {
	level := "basic"
	if completionScore >= 70 {
		level = "verified"
	}
	if completionScore >= 90 {
		level = "trusted"
	}
	_ = s.repo.UpdateTrustLevel(orgID, level)
}
