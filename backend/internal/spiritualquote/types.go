package spiritualquote

import (
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
)

const (
	MessageInvalidLocation = "invalid_quote_location"
	MessageQuoteNotFound   = "quote_not_found"
	MessageFetchFailed     = "failed_fetch_quote"
)

var (
	ErrInvalidLocation = errors.New(MessageInvalidLocation)
	ErrQuoteNotFound   = errors.New(MessageQuoteNotFound)
)

// Location defines where quotes should be shown.
type Location string

const (
	LocationDashboard Location = "dashboard"
	LocationHome      Location = "home"
	LocationLogin     Location = "login"
)

func ParseLocation(raw string) (Location, error) {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case string(LocationDashboard):
		return LocationDashboard, nil
	case string(LocationHome):
		return LocationHome, nil
	case string(LocationLogin):
		return LocationLogin, nil
	default:
		return "", ErrInvalidLocation
	}
}

func (l Location) filterColumn() (string, error) {
	switch l {
	case LocationDashboard:
		return "show_on_dashboard", nil
	case LocationHome:
		return "show_on_home", nil
	case LocationLogin:
		return "show_on_login", nil
	default:
		return "", ErrInvalidLocation
	}
}

// Quote is the persistence model for spiritual quotes.
type Quote struct {
	ID              uuid.UUID `json:"-"`
	Type            string    `json:"type"`
	TextAR          string    `json:"text_ar"`
	Source          string    `json:"source"`
	Reference       string    `json:"reference"`
	IsActive        bool      `json:"-"`
	ShowOnDashboard bool      `json:"-"`
	ShowOnHome      bool      `json:"-"`
	ShowOnLogin     bool      `json:"-"`
	CreatedAt       time.Time `json:"-"`
}
