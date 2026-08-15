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

// EnhanceOptions contains metadata for AI generation
type EnhanceOptions struct {
	Category  string
	EventType string
	Language  string
	City      string
	Audience  string
	Tags      []string
}

// EnhanceDescription rewrites or generates an event description professionally
func (s *DescriptionService) EnhanceDescription(ctx context.Context, title, rawDescription string, opts EnhanceOptions) (*EnhancedDescription, error) {
	if !s.client.IsEnabled() {
		return nil, fmt.Errorf("AI not enabled")
	}

	langInstruction := "Generate the response in English."
	if opts.Language != "" {
		langInstruction = fmt.Sprintf("CRITICAL: You MUST write the description and summary in %s. Do not use English unless the requested language is English.", opts.Language)
	}

	taskInstruction := "1. Rewrite the description professionally — improve clarity, emotional appeal, and readability."
	if rawDescription == "" {
		taskInstruction = "1. Generate a compelling, professional event description from scratch based on the title and provided metadata."
	}

	prompt := fmt.Sprintf(`You are a professional event copywriter. Enhance or create this event listing.

EVENT TITLE: %s
RAW DESCRIPTION: %s
CATEGORY: %s
EVENT TYPE: %s
CITY: %s
AUDIENCE: %s
TAGS: %v

%s

KHAIR ORGANIZER STANDARDS (STRICT COMPLIANCE):
Descriptions MUST NOT promote:
- Explicit sexual content
- Alcohol or drug promotion
- Gambling
- Hate speech
- Extremist/violent advocacy
- Fraudulent fundraising
- Illegal activities
If the title or description violates these standards, politely refuse in the description field.

TASK:
%s
2. Generate a short preview summary (max 120 characters).
3. Suggest missing details (e.g., agenda, prerequisites, dress code).
4. Suggest up to 5 relevant tags (only alphanumeric and hyphens).

Return ONLY a JSON object:
{
  "title": "improved title or same if good",
  "description": "professionally rewritten/generated description",
  "short_summary": "120-char max preview",
  "suggested_tags": ["tag1", "tag2"],
  "missing_details": ["what's missing"]
}`, title, rawDescription, opts.Category, opts.EventType, opts.City, opts.Audience, opts.Tags, langInstruction, taskInstruction)

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

VALID CATEGORIES: community, charity, workshop, conference, seminar, lectures, meetup, festival, webinar, retreat, family, youth, knowledge, quran, networking, hackathon, sports, technology, education, business, entrepreneurship, career, health, wellness, arts, culture, environment, volunteering, food, travel, entertainment, parenting, other

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
