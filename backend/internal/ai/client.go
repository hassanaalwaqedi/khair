package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/khair/backend/pkg/config"
)

// Client handles communication with the Gemini Flash API
type Client struct {
	apiKey     string
	model      string
	maxTokens  int
	httpClient *http.Client
	enabled    bool
}

// NewClient creates a new Gemini AI client
func NewClient(cfg config.GeminiConfig) *Client {
	return &Client{
		apiKey:    cfg.APIKey,
		model:     cfg.Model,
		maxTokens: cfg.MaxTokens,
		enabled:   cfg.Enabled,
		httpClient: &http.Client{
			Timeout: 60 * time.Second,
		},
	}
}

// IsEnabled returns whether the AI client is configured and ready
func (c *Client) IsEnabled() bool {
	return c.enabled && c.apiKey != ""
}

// ---------- Gemini REST API types ----------

// GeminiRequest is the top-level request body
type GeminiRequest struct {
	Contents         []GeminiContent        `json:"contents"`
	GenerationConfig GeminiGenerationConfig `json:"generationConfig,omitempty"`
}

// GeminiContent holds a single message turn
type GeminiContent struct {
	Parts []GeminiPart `json:"parts"`
}

// GeminiPart holds the text or inline data content
type GeminiPart struct {
	Text       string            `json:"text,omitempty"`
	InlineData *GeminiInlineData `json:"inline_data,omitempty"`
}

// GeminiInlineData holds base64-encoded file data
type GeminiInlineData struct {
	MimeType string `json:"mime_type"`
	Data     string `json:"data"`
}

// GeminiGenerationConfig controls output parameters
type GeminiGenerationConfig struct {
	Temperature      float64 `json:"temperature,omitempty"`
	MaxOutputTokens  int     `json:"maxOutputTokens,omitempty"`
	ResponseMimeType string  `json:"responseMimeType,omitempty"`
}

// GeminiResponse is the top-level response
type GeminiResponse struct {
	Candidates []GeminiCandidate `json:"candidates"`
}

// GeminiCandidate holds one generation candidate
type GeminiCandidate struct {
	Content GeminiContent `json:"content"`
}

// ---------- Core method ----------

// Generate sends a plain-text prompt to Gemini and returns a plain-text reply.
// Structured consumers should use GenerateJSON so the model is explicitly
// asked for JSON instead of making a user-facing chat reply look like JSON.
func (c *Client) Generate(ctx context.Context, prompt string, temperature float64) (string, error) {
	return c.generate(ctx, prompt, temperature, "")
}

// generate includes automatic retry with exponential backoff for 429
// rate-limit errors. responseMimeType is reserved for structured callers.
func (c *Client) generate(ctx context.Context, prompt string, temperature float64, responseMimeType string) (string, error) {
	if !c.IsEnabled() {
		return "", fmt.Errorf("gemini AI is not enabled (missing API key)")
	}

	url := fmt.Sprintf(
		"https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s",
		c.model, c.apiKey,
	)

	reqBody := GeminiRequest{
		Contents: []GeminiContent{
			{Parts: []GeminiPart{{Text: prompt}}},
		},
		GenerationConfig: GeminiGenerationConfig{
			Temperature:      temperature,
			MaxOutputTokens:  c.maxTokens,
			ResponseMimeType: responseMimeType,
		},
	}

	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("marshal request: %w", err)
	}

	// Retry up to 5 times for rate-limit (429) errors
	maxRetries := 5
	backoff := 2 * time.Second

	for attempt := 0; attempt <= maxRetries; attempt++ {
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
		if err != nil {
			return "", fmt.Errorf("create request: %w", err)
		}
		req.Header.Set("Content-Type", "application/json")

		resp, err := c.httpClient.Do(req)
		if err != nil {
			return "", fmt.Errorf("gemini request failed: %w", err)
		}

		respBody, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			return "", fmt.Errorf("read response: %w", err)
		}

		// Handle rate limiting with retry
		if resp.StatusCode == http.StatusTooManyRequests {
			if attempt < maxRetries {
				log.Printf("[AI] Rate limited (429), retrying in %v (attempt %d/%d)", backoff, attempt+1, maxRetries)
				select {
				case <-time.After(backoff):
					backoff *= 2 // exponential backoff
					continue
				case <-ctx.Done():
					return "", fmt.Errorf("request cancelled during rate-limit backoff")
				}
			}
			return "", fmt.Errorf("gemini API rate limited after %d retries", maxRetries)
		}

		if resp.StatusCode != http.StatusOK {
			return "", fmt.Errorf("gemini API error %d: %s", resp.StatusCode, string(respBody))
		}

		var geminiResp GeminiResponse
		if err := json.Unmarshal(respBody, &geminiResp); err != nil {
			return "", fmt.Errorf("unmarshal response: %w", err)
		}

		if len(geminiResp.Candidates) == 0 || len(geminiResp.Candidates[0].Content.Parts) == 0 {
			return "", fmt.Errorf("empty response from gemini")
		}

		return geminiResp.Candidates[0].Content.Parts[0].Text, nil
	}

	return "", fmt.Errorf("gemini API: exhausted retries")
}

// GenerateJSON sends a prompt and parses the JSON response into the target struct
func (c *Client) GenerateJSON(ctx context.Context, prompt string, temperature float64, target interface{}) error {
	text, err := c.generate(ctx, prompt, temperature, "application/json")
	if err != nil {
		return err
	}

	// Gemini sometimes wraps JSON in markdown blocks (e.g. ```json ... ```)
	cleanedText := strings.TrimSpace(text)
	if strings.HasPrefix(cleanedText, "```json") {
		cleanedText = strings.TrimPrefix(cleanedText, "```json")
		cleanedText = strings.TrimSuffix(cleanedText, "```")
	} else if strings.HasPrefix(cleanedText, "```") {
		cleanedText = strings.TrimPrefix(cleanedText, "```")
		cleanedText = strings.TrimSuffix(cleanedText, "```")
	}
	cleanedText = strings.TrimSpace(cleanedText)

	if err := json.Unmarshal([]byte(cleanedText), target); err != nil {
		return fmt.Errorf("parse AI JSON response: %w (raw: %s)", err, text)
	}

	return nil
}

// ─── Content Moderation ──────────────────────────────────

// TextModerationResult holds AI text moderation output
type TextModerationResult struct {
	Passed  bool   `json:"passed"`
	Warning string `json:"warning"`
}

// ModerateText checks text for profanity, racism, hate speech, or inappropriate content
func (c *Client) ModerateText(ctx context.Context, text string) (*TextModerationResult, error) {
	if !c.IsEnabled() {
		// If AI is disabled, allow all content
		return &TextModerationResult{Passed: true}, nil
	}

	prompt := fmt.Sprintf(`You are a content moderation AI for an Islamic community platform called "Khair".
Analyze the following text and determine if it contains:
- Profanity or vulgar language (in any language)
- Racism, hate speech, or discrimination
- Sexual or inappropriate content
- Violence or threats
- Insults or harassment

Text to analyze: "%s"

Respond in JSON:
{"passed": true/false, "warning": "explanation if failed, empty if passed"}

If the text is clean and appropriate, set passed=true and warning="".
If the text contains any violation, set passed=false and provide a clear, respectful warning message explaining why this content is not allowed. Keep the warning concise and user-friendly.`, text)

	var result TextModerationResult
	if err := c.GenerateJSON(ctx, prompt, 0.1, &result); err != nil {
		// On AI error, allow content (fail-open) but log
		return &TextModerationResult{Passed: true}, nil
	}

	return &result, nil
}

// ImageModerationResult holds AI image moderation output
type ImageModerationResult struct {
	Passed  bool   `json:"passed"`
	Warning string `json:"warning"`
}

// ModerateImage checks a base64-encoded image for inappropriate content
func (c *Client) ModerateImage(ctx context.Context, base64Data, mimeType string) (*ImageModerationResult, error) {
	if !c.IsEnabled() {
		return &ImageModerationResult{Passed: true}, nil
	}

	url := fmt.Sprintf(
		"https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s",
		c.model, c.apiKey,
	)

	reqBody := GeminiRequest{
		Contents: []GeminiContent{
			{
				Parts: []GeminiPart{
					{
						Text: `You are a content moderation AI for an Islamic community platform called "Khair".
Analyze the provided image and determine if it is appropriate for an Islamic community platform profile photo.

Check for:
- Nudity or sexually explicit content
- Violence or gore
- Drug or alcohol-related imagery
- Offensive symbols or hate symbols
- Any other inappropriate content for a family-friendly Islamic platform

Respond ONLY in JSON:
{"passed": true/false, "warning": "explanation if failed, empty if passed"}

If the image is appropriate (normal photos, landscapes, logos, etc.), set passed=true.
If inappropriate, set passed=false and provide a clear, respectful warning.`,
					},
					{
						InlineData: &GeminiInlineData{
							MimeType: mimeType,
							Data:     base64Data,
						},
					},
				},
			},
		},
		GenerationConfig: GeminiGenerationConfig{
			Temperature:      0.1,
			MaxOutputTokens:  256,
			ResponseMimeType: "application/json",
		},
	}

	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return &ImageModerationResult{Passed: true}, nil
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
	if err != nil {
		return &ImageModerationResult{Passed: true}, nil
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return &ImageModerationResult{Passed: true}, nil
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return &ImageModerationResult{Passed: true}, nil
	}

	if resp.StatusCode != http.StatusOK {
		return &ImageModerationResult{Passed: true}, nil
	}

	var geminiResp GeminiResponse
	if err := json.Unmarshal(respBody, &geminiResp); err != nil {
		return &ImageModerationResult{Passed: true}, nil
	}

	if len(geminiResp.Candidates) == 0 || len(geminiResp.Candidates[0].Content.Parts) == 0 {
		return &ImageModerationResult{Passed: true}, nil
	}

	var result ImageModerationResult
	if err := json.Unmarshal([]byte(geminiResp.Candidates[0].Content.Parts[0].Text), &result); err != nil {
		return &ImageModerationResult{Passed: true}, nil
	}

	return &result, nil
}
