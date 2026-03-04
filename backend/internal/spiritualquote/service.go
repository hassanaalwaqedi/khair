package spiritualquote

import (
	"context"
	"database/sql"
	"errors"
	"sync"
	"time"
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
