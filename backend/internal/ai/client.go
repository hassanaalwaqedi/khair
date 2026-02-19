package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
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
			Timeout: 30 * time.Second,
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

// GeminiPart holds the text content
type GeminiPart struct {
	Text string `json:"text"`
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

// Generate sends a structured prompt to Gemini and returns the text response
func (c *Client) Generate(ctx context.Context, prompt string, temperature float64) (string, error) {
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
			ResponseMimeType: "application/json",
		},
	}

	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("gemini request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("read response: %w", err)
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

// GenerateJSON sends a prompt and parses the JSON response into the target struct
func (c *Client) GenerateJSON(ctx context.Context, prompt string, temperature float64, target interface{}) error {
	text, err := c.Generate(ctx, prompt, temperature)
	if err != nil {
		return err
	}

	if err := json.Unmarshal([]byte(text), target); err != nil {
		return fmt.Errorf("parse AI JSON response: %w (raw: %s)", err, text)
	}

	return nil
}
