package ai

import (
	"context"
	"fmt"
)

// DescriptionService handles AI-powered description optimization and category detection
type DescriptionService struct {
	client *Client
}

// NewDescriptionService creates a new description service
func NewDescriptionService(client *Client) *DescriptionService {
	return &DescriptionService{client: client}
}

// EnhancedDescription is the AI response for description optimization
type EnhancedDescription struct {
	Title          string   `json:"title"`
	Description    string   `json:"description"`
	ShortSummary   string   `json:"short_summary"`
	SuggestedTags  []string `json:"suggested_tags"`
	MissingDetails []string `json:"missing_details"`
}

// EnhanceDescription rewrites an event description professionally
func (s *DescriptionService) EnhanceDescription(ctx context.Context, title, rawDescription string, tags []string) (*EnhancedDescription, error) {
	if !s.client.IsEnabled() {
		return nil, fmt.Errorf("AI not enabled")
	}

	prompt := fmt.Sprintf(`You are a professional event copywriter. Enhance this event listing.

EVENT TITLE: %s
RAW DESCRIPTION: %s
TAGS: %v

TASK:
1. Rewrite the description professionally — improve clarity, emotional appeal, and readability.
2. Generate a short preview summary (max 120 characters).
3. Suggest missing details (e.g., agenda, prerequisites, dress code).
4. Suggest relevant tags if the provided list is incomplete.

Return ONLY a JSON object:
{
  "title": "improved title or same if good",
  "description": "professionally rewritten description",
  "short_summary": "120-char max preview",
  "suggested_tags": ["tag1", "tag2"],
  "missing_details": ["what's missing"]
}`, title, rawDescription, tags)

	var result EnhancedDescription
	if err := s.client.GenerateJSON(ctx, prompt, 0.5, &result); err != nil {
		return nil, fmt.Errorf("enhance description: %w", err)
	}

	return &result, nil
}

// CategoryDetection is the AI response for category detection
type CategoryDetection struct {
	Category   string   `json:"category"`
	Confidence float64  `json:"confidence"`
	Tags       []string `json:"tags"`
	Reasoning  string   `json:"reasoning"`
}

// DetectCategory auto-detects the event category from its description
func (s *DescriptionService) DetectCategory(ctx context.Context, title, description string) (*CategoryDetection, error) {
	if !s.client.IsEnabled() {
		return nil, fmt.Errorf("AI not enabled")
	}

	prompt := fmt.Sprintf(`You are an event classification engine.

EVENT TITLE: %s
DESCRIPTION: %s

VALID CATEGORIES: conference, workshop, seminar, festival, meetup, hackathon, webinar, networking, charity, sports

TASK:
1. Detect the most likely category from the valid list.
2. Rate your confidence (0.0 to 1.0).
3. Suggest 3-5 relevant tags.
4. Explain your reasoning briefly.

Return ONLY a JSON object:
{
  "category": "detected_category",
  "confidence": 0.9,
  "tags": ["tag1", "tag2", "tag3"],
  "reasoning": "brief explanation"
}`, title, description)

	var result CategoryDetection
	if err := s.client.GenerateJSON(ctx, prompt, 0.2, &result); err != nil {
		return nil, fmt.Errorf("detect category: %w", err)
	}

	return &result, nil
}
