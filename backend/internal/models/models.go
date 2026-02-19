package models

import (
	"time"

	"github.com/google/uuid"
)

// User represents a user in the system
type User struct {
	ID           uuid.UUID `json:"id"`
	Email        string    `json:"email"`
	PasswordHash string    `json:"-"`
	Role         string    `json:"role"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// Organizer represents an organization profile
type Organizer struct {
	ID              uuid.UUID  `json:"id"`
	UserID          uuid.UUID  `json:"user_id"`
	Name            string     `json:"name"`
	Description     *string    `json:"description,omitempty"`
	Website         *string    `json:"website,omitempty"`
	Phone           *string    `json:"phone,omitempty"`
	LogoURL         *string    `json:"logo_url,omitempty"`
	Status          string     `json:"status"`
	RejectionReason *string    `json:"rejection_reason,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

// Event represents an event
type Event struct {
	ID              uuid.UUID  `json:"id"`
	OrganizerID     uuid.UUID  `json:"organizer_id"`
	Title           string     `json:"title"`
	Description     *string    `json:"description,omitempty"`
	EventType       string     `json:"event_type"`
	Language        *string    `json:"language,omitempty"`
	Country         *string    `json:"country,omitempty"`
	City            *string    `json:"city,omitempty"`
	Address         *string    `json:"address,omitempty"`
	Latitude        *float64   `json:"latitude,omitempty"`
	Longitude       *float64   `json:"longitude,omitempty"`
	StartDate       time.Time  `json:"start_date"`
	EndDate         *time.Time `json:"end_date,omitempty"`
	ImageURL        *string    `json:"image_url,omitempty"`
	Status          string     `json:"status"`
	RejectionReason *string    `json:"rejection_reason,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

// EventWithOrganizer represents an event with organizer details
type EventWithOrganizer struct {
	Event
	OrganizerName string `json:"organizer_name"`
}
