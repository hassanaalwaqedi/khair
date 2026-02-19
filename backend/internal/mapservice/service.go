package mapservice

import (
	"database/sql"

	"github.com/khair/backend/internal/models"
)

// Service handles map-related business logic
type Service struct {
	repo *Repository
}

// NewService creates a new map service
func NewService(db *sql.DB) *Service {
	return &Service{
		repo: NewRepository(db),
	}
}

// FindNearby finds events near a location
func (s *Service) FindNearby(filter *NearbyFilter) ([]models.EventWithOrganizer, error) {
	// Set defaults
	if filter.Limit <= 0 || filter.Limit > 100 {
		filter.Limit = 50
	}
	if filter.RadiusKm <= 0 {
		filter.RadiusKm = 10 // Default 10km radius
	}
	if filter.RadiusKm > 500 {
		filter.RadiusKm = 500 // Max 500km radius
	}

	return s.repo.FindNearby(filter)
}

// FindInBounds finds events within a bounding box
func (s *Service) FindInBounds(filter *BoundsFilter) ([]models.EventWithOrganizer, error) {
	// Set defaults
	if filter.Limit <= 0 || filter.Limit > 100 {
		filter.Limit = 50
	}

	return s.repo.FindInBounds(filter)
}
