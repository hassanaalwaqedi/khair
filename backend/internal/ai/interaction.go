package ai

import (
	"database/sql"
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// InteractionType defines valid interaction types
type InteractionType string

const (
	InteractionView   InteractionType = "view"
	InteractionJoin   InteractionType = "join"
	InteractionSave   InteractionType = "save"
	InteractionSearch InteractionType = "search"
	InteractionFilter InteractionType = "filter"
	InteractionClick  InteractionType = "click"
)

// UserInteraction represents a logged user behavior signal
type UserInteraction struct {
	ID              uuid.UUID       `json:"id"`
	UserID          uuid.UUID       `json:"user_id"`
	EventID         *uuid.UUID      `json:"event_id,omitempty"`
	InteractionType InteractionType `json:"interaction_type"`
	Metadata        json.RawMessage `json:"metadata,omitempty"`
	CreatedAt       time.Time       `json:"created_at"`
}

// UserAIProfile represents the invisible AI interest profile
type UserAIProfile struct {
	UserID               uuid.UUID       `json:"user_id"`
	TopCategories        json.RawMessage `json:"top_categories"`
	PreferredCountries   json.RawMessage `json:"preferred_countries"`
	ActiveHours          json.RawMessage `json:"active_hours"`
	SocialVsProfessional float64         `json:"social_vs_professional"`
	RawProfile           json.RawMessage `json:"raw_profile"`
	UpdatedAt            time.Time       `json:"updated_at"`
}

// EventScore represents a cached AI relevance score
type EventScore struct {
	UserID         uuid.UUID `json:"user_id"`
	EventID        uuid.UUID `json:"event_id"`
	RelevanceScore float64   `json:"relevance_score"`
	Reasoning      string    `json:"reasoning,omitempty"`
	CalculatedAt   time.Time `json:"calculated_at"`
}

// InteractionRepository handles database operations for interaction tracking
type InteractionRepository struct {
	db *sql.DB
}

// NewInteractionRepository creates a new interaction repository
func NewInteractionRepository(db *sql.DB) *InteractionRepository {
	return &InteractionRepository{db: db}
}

// LogInteraction stores a user interaction signal
func (r *InteractionRepository) LogInteraction(interaction *UserInteraction) error {
	query := `
		INSERT INTO user_interactions (id, user_id, event_id, interaction_type, metadata, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	interaction.ID = uuid.New()
	interaction.CreatedAt = time.Now()

	metadata := interaction.Metadata
	if metadata == nil {
		metadata = json.RawMessage(`{}`)
	}

	_, err := r.db.Exec(query,
		interaction.ID, interaction.UserID, interaction.EventID,
		interaction.InteractionType, metadata, interaction.CreatedAt,
	)
	return err
}

// GetRecentInteractions retrieves recent interactions for a user
func (r *InteractionRepository) GetRecentInteractions(userID uuid.UUID, limit int) ([]UserInteraction, error) {
	query := `
		SELECT id, user_id, event_id, interaction_type, metadata, created_at
		FROM user_interactions
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2
	`
	rows, err := r.db.Query(query, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var interactions []UserInteraction
	for rows.Next() {
		var i UserInteraction
		if err := rows.Scan(&i.ID, &i.UserID, &i.EventID, &i.InteractionType, &i.Metadata, &i.CreatedAt); err != nil {
			return nil, err
		}
		interactions = append(interactions, i)
	}
	return interactions, nil
}

// GetUserCategoryStats returns category counts from user interactions
func (r *InteractionRepository) GetUserCategoryStats(userID uuid.UUID) (map[string]int, error) {
	query := `
		SELECT e.event_type, COUNT(*) as cnt
		FROM user_interactions ui
		JOIN events e ON ui.event_id = e.id
		WHERE ui.user_id = $1 AND ui.event_id IS NOT NULL
		GROUP BY e.event_type
		ORDER BY cnt DESC
		LIMIT 10
	`
	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	stats := make(map[string]int)
	for rows.Next() {
		var category string
		var count int
		if err := rows.Scan(&category, &count); err != nil {
			return nil, err
		}
		stats[category] = count
	}
	return stats, nil
}

// GetUserCountryStats returns country counts from user interactions
func (r *InteractionRepository) GetUserCountryStats(userID uuid.UUID) (map[string]int, error) {
	query := `
		SELECT COALESCE(e.country, 'Unknown'), COUNT(*) as cnt
		FROM user_interactions ui
		JOIN events e ON ui.event_id = e.id
		WHERE ui.user_id = $1 AND ui.event_id IS NOT NULL AND e.country IS NOT NULL
		GROUP BY e.country
		ORDER BY cnt DESC
		LIMIT 10
	`
	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	stats := make(map[string]int)
	for rows.Next() {
		var country string
		var count int
		if err := rows.Scan(&country, &count); err != nil {
			return nil, err
		}
		stats[country] = count
	}
	return stats, nil
}

// GetRecentSearches returns recent search terms
func (r *InteractionRepository) GetRecentSearches(userID uuid.UUID, limit int) ([]string, error) {
	query := `
		SELECT DISTINCT metadata->>'query' as search_query
		FROM user_interactions
		WHERE user_id = $1 AND interaction_type = 'search' AND metadata->>'query' IS NOT NULL
		ORDER BY created_at DESC
		LIMIT $2
	`
	rows, err := r.db.Query(query, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var searches []string
	for rows.Next() {
		var q string
		if err := rows.Scan(&q); err != nil {
			return nil, err
		}
		if q != "" {
			searches = append(searches, q)
		}
	}
	return searches, nil
}

// SaveEventScore stores or updates an AI relevance score
func (r *InteractionRepository) SaveEventScore(score *EventScore) error {
	query := `
		INSERT INTO ai_event_scores (user_id, event_id, relevance_score, reasoning, calculated_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (user_id, event_id) DO UPDATE SET
			relevance_score = EXCLUDED.relevance_score,
			reasoning = EXCLUDED.reasoning,
			calculated_at = EXCLUDED.calculated_at
	`
	_, err := r.db.Exec(query, score.UserID, score.EventID, score.RelevanceScore, score.Reasoning, time.Now())
	return err
}

// GetTopScoredEvents returns the highest-scoring events for a user
func (r *InteractionRepository) GetTopScoredEvents(userID uuid.UUID, limit int) ([]EventScore, error) {
	query := `
		SELECT user_id, event_id, relevance_score, COALESCE(reasoning, ''), calculated_at
		FROM ai_event_scores
		WHERE user_id = $1
		ORDER BY relevance_score DESC
		LIMIT $2
	`
	rows, err := r.db.Query(query, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var scores []EventScore
	for rows.Next() {
		var s EventScore
		if err := rows.Scan(&s.UserID, &s.EventID, &s.RelevanceScore, &s.Reasoning, &s.CalculatedAt); err != nil {
			return nil, err
		}
		scores = append(scores, s)
	}
	return scores, nil
}

// SaveUserProfile stores or updates the AI profile for a user
func (r *InteractionRepository) SaveUserProfile(profile *UserAIProfile) error {
	query := `
		INSERT INTO user_profiles_ai (user_id, top_categories, preferred_countries, active_hours, social_vs_professional, raw_profile, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		ON CONFLICT (user_id) DO UPDATE SET
			top_categories = EXCLUDED.top_categories,
			preferred_countries = EXCLUDED.preferred_countries,
			active_hours = EXCLUDED.active_hours,
			social_vs_professional = EXCLUDED.social_vs_professional,
			raw_profile = EXCLUDED.raw_profile,
			updated_at = EXCLUDED.updated_at
	`
	_, err := r.db.Exec(query,
		profile.UserID, profile.TopCategories, profile.PreferredCountries,
		profile.ActiveHours, profile.SocialVsProfessional, profile.RawProfile,
		time.Now(),
	)
	return err
}

// GetUserProfile retrieves the AI profile for a user
func (r *InteractionRepository) GetUserProfile(userID uuid.UUID) (*UserAIProfile, error) {
	query := `
		SELECT user_id, top_categories, preferred_countries, active_hours,
		       social_vs_professional, raw_profile, updated_at
		FROM user_profiles_ai
		WHERE user_id = $1
	`
	profile := &UserAIProfile{}
	err := r.db.QueryRow(query, userID).Scan(
		&profile.UserID, &profile.TopCategories, &profile.PreferredCountries,
		&profile.ActiveHours, &profile.SocialVsProfessional, &profile.RawProfile,
		&profile.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return profile, nil
}
