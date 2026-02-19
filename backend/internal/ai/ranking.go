package ai

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
)

// RankingService handles AI-powered event ranking
type RankingService struct {
	client  *Client
	repo    *InteractionRepository
	eventDB *sql.DB
}

// NewRankingService creates a new ranking service
func NewRankingService(client *Client, repo *InteractionRepository, db *sql.DB) *RankingService {
	return &RankingService{
		client:  client,
		repo:    repo,
		eventDB: db,
	}
}

// EventScoreResult is the AI response for a single event score
type EventScoreResult struct {
	EventID string  `json:"event_id"`
	Score   float64 `json:"score"`
	Reason  string  `json:"reason"`
}

// RankingResponse is the AI response for the ranking task
type RankingResponse struct {
	Scores      []EventScoreResult `json:"scores"`
	Recommended []string           `json:"recommended"`
}

// RankEventsForUser scores and ranks events based on user behavior
func (s *RankingService) RankEventsForUser(ctx context.Context, userID uuid.UUID, events []models.EventWithOrganizer) (*RankingResponse, error) {
	if !s.client.IsEnabled() || len(events) == 0 {
		return nil, fmt.Errorf("AI ranking unavailable")
	}

	// Build user context from interaction history
	userContext, err := s.buildUserContext(userID)
	if err != nil {
		return nil, fmt.Errorf("build user context: %w", err)
	}

	// Build compact event list (only metadata, no PII)
	eventList := make([]map[string]interface{}, 0, len(events))
	for _, e := range events {
		eventList = append(eventList, map[string]interface{}{
			"id":         e.ID.String(),
			"title":      e.Title,
			"category":   e.EventType,
			"country":    safeStr(e.Country),
			"city":       safeStr(e.City),
			"language":   safeStr(e.Language),
			"organizer":  e.OrganizerName,
			"start_date": e.StartDate.Format("2006-01-02"),
		})
	}

	prompt := fmt.Sprintf(`You are an event recommendation engine. Score each event for a user.

USER CONTEXT:
%s

AVAILABLE EVENTS:
%s

TASK:
1. Score each event from 0.0 to 1.0 based on relevance to the user's interests, location, and behavior.
2. Pick the top 5 most recommended event IDs.
3. Provide a brief reason for each score.

Return ONLY a JSON object with this structure:
{
  "scores": [{"event_id": "...", "score": 0.85, "reason": "..."}],
  "recommended": ["event_id_1", "event_id_2", ...]
}`,
		mustJSON(userContext),
		mustJSON(eventList),
	)

	var result RankingResponse
	if err := s.client.GenerateJSON(ctx, prompt, 0.3, &result); err != nil {
		return nil, fmt.Errorf("AI ranking failed: %w", err)
	}

	// Cache the scores in the database
	for _, score := range result.Scores {
		eventID, err := uuid.Parse(score.EventID)
		if err != nil {
			continue
		}
		_ = s.repo.SaveEventScore(&EventScore{
			UserID:         userID,
			EventID:        eventID,
			RelevanceScore: score.Score,
			Reasoning:      score.Reason,
		})
	}

	return &result, nil
}

// GetRecommendedEvents returns AI-ranked event IDs for a user
func (s *RankingService) GetRecommendedEvents(ctx context.Context, userID uuid.UUID, limit int) ([]EventScore, error) {
	// First check cached scores
	scores, err := s.repo.GetTopScoredEvents(userID, limit)
	if err != nil {
		return nil, err
	}
	if len(scores) > 0 {
		return scores, nil
	}

	// No cached scores — trigger ranking for approved events
	events, err := s.getApprovedEvents(limit * 3) // Fetch more events to rank
	if err != nil {
		return nil, err
	}

	if len(events) == 0 {
		return nil, nil
	}

	result, err := s.RankEventsForUser(ctx, userID, events)
	if err != nil {
		log.Printf("AI ranking fallback: %v", err)
		return nil, nil // Graceful fallback
	}

	// Return top scores
	scores, _ = s.repo.GetTopScoredEvents(userID, limit)
	if scores == nil && result != nil {
		// Build from AI response directly
		for _, sr := range result.Scores {
			eid, err := uuid.Parse(sr.EventID)
			if err != nil {
				continue
			}
			scores = append(scores, EventScore{
				UserID:         userID,
				EventID:        eid,
				RelevanceScore: sr.Score,
				Reasoning:      sr.Reason,
			})
			if len(scores) >= limit {
				break
			}
		}
	}

	return scores, nil
}

// SmartSearch uses AI to interpret search intent and return relevant event IDs
func (s *RankingService) SmartSearch(ctx context.Context, userID uuid.UUID, query string, events []models.EventWithOrganizer) ([]string, error) {
	if !s.client.IsEnabled() || query == "" {
		return nil, fmt.Errorf("AI search unavailable")
	}

	// Build compact event list
	eventList := make([]map[string]interface{}, 0, len(events))
	for _, e := range events {
		desc := ""
		if e.Description != nil {
			desc = *e.Description
			if len(desc) > 100 {
				desc = desc[:100]
			}
		}
		eventList = append(eventList, map[string]interface{}{
			"id":       e.ID.String(),
			"title":    e.Title,
			"category": e.EventType,
			"country":  safeStr(e.Country),
			"city":     safeStr(e.City),
			"desc":     desc,
		})
	}

	prompt := fmt.Sprintf(`You are a smart event search engine. The user searched for: "%s"

AVAILABLE EVENTS:
%s

TASK:
1. Understand the user's intent (fix typos, expand keywords, infer category/country).
2. Return the event IDs that best match the query, ordered by relevance.
3. Return ONLY a JSON object:
{
  "matched_ids": ["id1", "id2", ...],
  "interpreted_query": "what you understood the user meant"
}`, query, mustJSON(eventList))

	var result struct {
		MatchedIDs       []string `json:"matched_ids"`
		InterpretedQuery string   `json:"interpreted_query"`
	}

	if err := s.client.GenerateJSON(ctx, prompt, 0.2, &result); err != nil {
		return nil, err
	}

	return result.MatchedIDs, nil
}

// buildUserContext aggregates user interactions into a context object
func (s *RankingService) buildUserContext(userID uuid.UUID) (map[string]interface{}, error) {
	categoryStats, err := s.repo.GetUserCategoryStats(userID)
	if err != nil {
		categoryStats = map[string]int{}
	}

	countryStats, err := s.repo.GetUserCountryStats(userID)
	if err != nil {
		countryStats = map[string]int{}
	}

	recentSearches, err := s.repo.GetRecentSearches(userID, 5)
	if err != nil {
		recentSearches = []string{}
	}

	recentInteractions, err := s.repo.GetRecentInteractions(userID, 10)
	if err != nil {
		recentInteractions = []UserInteraction{}
	}

	// Build compact interaction summary
	recentSummary := make([]map[string]string, 0, len(recentInteractions))
	for _, i := range recentInteractions {
		summary := map[string]string{
			"type": string(i.InteractionType),
		}
		if i.EventID != nil {
			summary["event_id"] = i.EventID.String()
		}
		recentSummary = append(recentSummary, summary)
	}

	return map[string]interface{}{
		"top_categories":      categoryStats,
		"preferred_countries": countryStats,
		"recent_searches":     recentSearches,
		"recent_interactions": recentSummary,
	}, nil
}

// getApprovedEvents fetches approved events from the database
func (s *RankingService) getApprovedEvents(limit int) ([]models.EventWithOrganizer, error) {
	query := `
		SELECT e.id, e.organizer_id, e.title, e.description, e.event_type, e.language,
		       e.country, e.city, e.address, e.latitude, e.longitude, e.start_date, e.end_date,
		       e.image_url, e.status, e.rejection_reason, e.created_at, e.updated_at,
		       o.name as organizer_name
		FROM events e
		JOIN organizers o ON e.organizer_id = o.id
		WHERE e.status = 'approved' AND e.start_date >= NOW()
		ORDER BY e.start_date ASC
		LIMIT $1
	`
	rows, err := s.eventDB.Query(query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var events []models.EventWithOrganizer
	for rows.Next() {
		var event models.EventWithOrganizer
		err := rows.Scan(
			&event.ID, &event.OrganizerID, &event.Title, &event.Description, &event.EventType,
			&event.Language, &event.Country, &event.City, &event.Address, &event.Latitude,
			&event.Longitude, &event.StartDate, &event.EndDate, &event.ImageURL, &event.Status,
			&event.RejectionReason, &event.CreatedAt, &event.UpdatedAt, &event.OrganizerName,
		)
		if err != nil {
			return nil, err
		}
		events = append(events, event)
	}
	return events, nil
}

// --- Helpers ---

func safeStr(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func mustJSON(v interface{}) string {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return "{}"
	}
	return string(b)
}
