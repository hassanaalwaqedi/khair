package spiritualquote

import (
	"context"
	"database/sql"
	"errors"
	"sync"
	"time"

	"github.com/google/uuid"
)

type cachedQuote struct {
	quote     Quote
	expiresAt time.Time
}

// Service handles business logic for spiritual quotes.
type Service struct {
	repo  *Repository
	ttl   time.Duration
	mu    sync.RWMutex
	cache map[Location]cachedQuote
}

func NewService(repo *Repository) *Service {
	return &Service{
		repo:  repo,
		ttl:   2 * time.Minute,
		cache: make(map[Location]cachedQuote),
	}
}

func (s *Service) GetRandom(ctx context.Context, location Location) (*Quote, error) {
	if quote, ok := s.fromCache(location); ok {
		return &quote, nil
	}

	quote, err := s.repo.GetRandomByLocation(ctx, location)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrQuoteNotFound
		}
		return nil, err
	}

	s.toCache(location, *quote)
	return quote, nil
}

// ListByLocation returns all active quotes for a location (for the rotator).
func (s *Service) ListByLocation(ctx context.Context, location Location) ([]Quote, error) {
	return s.repo.ListByLocation(ctx, location)
}

// ListAll returns all quotes (admin).
func (s *Service) ListAll(ctx context.Context) ([]Quote, error) {
	return s.repo.ListAll(ctx)
}

// Create adds a new quote.
func (s *Service) Create(ctx context.Context, q *Quote) error {
	return s.repo.Create(ctx, q)
}

// Update modifies an existing quote.
func (s *Service) Update(ctx context.Context, q *Quote) error {
	return s.repo.Update(ctx, q)
}

// Delete removes a quote.
func (s *Service) Delete(ctx context.Context, id uuid.UUID) error {
	return s.repo.Delete(ctx, id)
}

func (s *Service) fromCache(location Location) (Quote, bool) {
	s.mu.RLock()
	entry, ok := s.cache[location]
	s.mu.RUnlock()
	if !ok || time.Now().After(entry.expiresAt) {
		if ok {
			s.mu.Lock()
			delete(s.cache, location)
			s.mu.Unlock()
		}
		return Quote{}, false
	}
	return entry.quote, true
}

func (s *Service) toCache(location Location, quote Quote) {
	s.mu.Lock()
	s.cache[location] = cachedQuote{
		quote:     quote,
		expiresAt: time.Now().Add(s.ttl),
	}
	s.mu.Unlock()
}
