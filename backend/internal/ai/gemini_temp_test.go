package ai

import "testing"

func TestGeminiModels(t *testing.T) {
	// Network/model smoke tests run only in a separately configured CI job.
	// Never embed provider keys or make the unit suite depend on live AI.
	t.Skip("live Gemini smoke test is disabled in the unit suite")
}
