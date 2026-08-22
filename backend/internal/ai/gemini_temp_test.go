package ai

import (
	"context"
	"fmt"
	"testing"
	"os"

	"github.com/khair/backend/pkg/config"
)

func TestGeminiModels(t *testing.T) {
	apiKey := os.Getenv("GEMINI_API_KEY")
	if apiKey == "" {
		apiKey = "AQ.Ab8RN6LitgENUNI6LxminwqhLngZd55Xo0QBTs1YiT74sFpjyg"
	}
	
	models := []string{"gemini-3.5-flash", "gemini-3.6-flash"}
	
	for _, m := range models {
		cfg := config.GeminiConfig{
			APIKey: apiKey,
			Model: m,
			MaxTokens: 1024,
			Enabled: true,
		}
		
		client := NewClient(cfg)
		
		history := []GeminiContent{
			{Role: "user", Parts: []GeminiPart{{Text: "System Instructions: hello"}}},
			{Role: "model", Parts: []GeminiPart{{Text: "Understood"}}},
			{Role: "user", Parts: []GeminiPart{{Text: "What is your name?"}}},
		}
		
		reply, err := client.GenerateChat(context.Background(), history, 0.2)
		if err != nil {
			fmt.Printf("Model %s failed: %v\n", m, err)
			t.Errorf("Model %s failed: %v", m, err)
		} else {
			fmt.Printf("Model %s SUCCESS! Reply: %s\n", m, reply)
		}
	}
}
