package sheikh

import "database/sql"

// Service handles sheikh directory business logic
type Service struct {
	repo *Repository
}

// NewService creates a new sheikh service
func NewService(db *sql.DB) *Service {
	return &Service{
		repo: NewRepository(db),
	}
}

// ListSheikhs returns all active sheikh profiles for public display
func (s *Service) ListSheikhs() ([]SheikhProfile, error) {
	return s.repo.ListPublicSheikhs()
}
