package ai

import (
	"context"
	"errors"
	"fmt"
	"testing"

	"github.com/khair/backend/pkg/config"
)

func TestNewClientUsesStableDefaultModel(t *testing.T) {
	client := NewClient(config.GeminiConfig{APIKey: "  test-key  ", Enabled: true})

	if got, want := client.Model(), config.DefaultGeminiModel; got != want {
		t.Fatalf("Model() = %q, want %q", got, want)
	}
	if !client.IsEnabled() {
		t.Fatal("client should be enabled with a non-empty API key")
	}
}

func TestFailureCategoryDoesNotExposeProviderResponse(t *testing.T) {
	cases := []struct {
		name string
		err  error
		want string
	}{
		{name: "missing key", err: errors.New("gemini AI is not enabled (missing API key)"), want: "not_configured"},
		{name: "forbidden", err: errors.New("gemini API error 403: provider response"), want: "authentication_or_permission"},
		{name: "model", err: errors.New("gemini API error 404: provider response"), want: "model_not_found"},
		{name: "rate limited", err: errors.New("gemini API rate limited after 5 retries"), want: "rate_limited"},
		{name: "timeout", err: fmt.Errorf("gemini request failed: %w", context.DeadlineExceeded), want: "timeout"},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := FailureCategory(tc.err); got != tc.want {
				t.Fatalf("FailureCategory() = %q, want %q", got, tc.want)
			}
		})
	}
}
