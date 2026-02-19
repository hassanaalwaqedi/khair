package organizer

import (
	"database/sql"
	"errors"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
)

// Service handles organizer business logic
type Service struct {
	repo *Repository
}

// NewService creates a new organizer service
func NewService(db *sql.DB) *Service {
	return &Service{
		repo: NewRepository(db),
	}
}

// UpdateProfileRequest represents a request to update organizer profile
type UpdateProfileRequest struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
	Website     *string `json:"website"`
	Phone       *string `json:"phone"`
	LogoURL     *string `json:"logo_url"`
}

// GetRepository returns the repository for use by other services
func (s *Service) GetRepository() *Repository {
	return s.repo
}

// GetByID retrieves an organizer by ID
func (s *Service) GetByID(id uuid.UUID) (*models.Organizer, error) {
	return s.repo.GetByID(id)
}

// GetByUserID retrieves an organizer by user ID
func (s *Service) GetByUserID(userID uuid.UUID) (*models.Organizer, error) {
	return s.repo.GetByUserID(userID)
}

// GetMyProfile retrieves the organizer profile for the current user
func (s *Service) GetMyProfile(userID uuid.UUID) (*models.Organizer, error) {
	return s.repo.GetByUserID(userID)
}

// UpdateProfile updates the organizer profile
func (s *Service) UpdateProfile(userID uuid.UUID, req *UpdateProfileRequest) (*models.Organizer, error) {
	org, err := s.repo.GetByUserID(userID)
	if err != nil {
		return nil, errors.New("organizer profile not found")
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

	if err := s.repo.Update(org); err != nil {
		return nil, errors.New("failed to update profile")
	}

	return org, nil
}
