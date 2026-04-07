package fcm

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"sync"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

// Client sends push notifications via Firebase Cloud Messaging HTTP v1 API.
type Client struct {
	projectID  string
	httpClient *http.Client
	tokenSrc   oauth2.TokenSource
	mu         sync.Mutex
	enabled    bool
}

// NewClient creates a new FCM v1 client from a service account JSON file path
// or raw JSON in the FCM_SERVICE_ACCOUNT env var.
// Falls back to legacy server key if FCM_SERVICE_ACCOUNT is not set.
func NewClient(serverKey string) *Client {
	c := &Client{
		httpClient: &http.Client{Timeout: 10 * time.Second},
	}

	// Try FCM v1 API first (service account)
	saJSON := os.Getenv("FCM_SERVICE_ACCOUNT")
	if saJSON == "" {
		// Try reading from file path env var
		saPath := os.Getenv("FCM_SERVICE_ACCOUNT_PATH")
		if saPath == "" {
			// Default: check current directory
			saPath = "firebase-service-account.json"
		}
		data, err := os.ReadFile(saPath)
		if err == nil {
			saJSON = string(data)
			log.Printf("[FCM] Loaded service account from: %s", saPath)
		}
	}

	if saJSON != "" {
		// Parse service account JSON to get project ID
		var saCfg struct {
			ProjectID string `json:"project_id"`
		}
		if err := json.Unmarshal([]byte(saJSON), &saCfg); err != nil {
			log.Printf("[FCM] Error parsing service account JSON: %v", err)
			return c
		}

		// Create OAuth2 token source with FCM scope
		creds, err := google.CredentialsFromJSON(
			oauth2.NoContext,
			[]byte(saJSON),
			"https://www.googleapis.com/auth/firebase.messaging",
		)
		if err != nil {
			log.Printf("[FCM] Error creating credentials: %v", err)
			return c
		}

		c.projectID = saCfg.ProjectID
		c.tokenSrc = creds.TokenSource
		c.enabled = true
		log.Printf("[FCM] v1 API initialized for project: %s", c.projectID)
		return c
	}

	// Legacy fallback (deprecated but kept for backwards compatibility)
	if serverKey != "" {
		log.Printf("[FCM] WARNING: Using legacy API which is DEPRECATED. Set FCM_SERVICE_ACCOUNT env var.")
		c.enabled = false // Legacy API is disabled by Google
	}

	return c
}

// IsEnabled returns true if FCM is properly configured.
func (c *Client) IsEnabled() bool {
	return c.enabled
}

// v1Message is the FCM v1 API message format.
type v1Message struct {
	Message struct {
		Token        string            `json:"token"`
		Notification *v1Notification   `json:"notification,omitempty"`
		Data         map[string]string `json:"data,omitempty"`
		Android      *androidConfig    `json:"android,omitempty"`
	} `json:"message"`
}

type v1Notification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type androidConfig struct {
	Priority     string              `json:"priority,omitempty"`
	Notification *androidNotifConfig `json:"notification,omitempty"`
}

type androidNotifConfig struct {
	ChannelID string `json:"channel_id,omitempty"`
	Sound     string `json:"sound,omitempty"`
}

// SendToDevice sends a push notification to a single device token using FCM v1 API.
func (c *Client) SendToDevice(token, title, body string, data map[string]string) error {
	if !c.enabled {
		log.Printf("[FCM] Disabled — would send to %s: %s", token[:min(8, len(token))], title)
		return nil
	}

	// Get OAuth2 access token
	c.mu.Lock()
	tok, err := c.tokenSrc.Token()
	c.mu.Unlock()
	if err != nil {
		return fmt.Errorf("fcm get token: %w", err)
	}

	// Build v1 message
	msg := v1Message{}
	msg.Message.Token = token
	msg.Message.Notification = &v1Notification{
		Title: title,
		Body:  body,
	}
	msg.Message.Data = data
	msg.Message.Android = &androidConfig{
		Priority: "high",
		Notification: &androidNotifConfig{
			ChannelID: "khair_notifications",
			Sound:     "default",
		},
	}

	payload, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("fcm marshal: %w", err)
	}

	url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", c.projectID)
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(payload))
	if err != nil {
		return fmt.Errorf("fcm request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+tok.AccessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("fcm send: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		log.Printf("[FCM] Error %d sending to %s: %s", resp.StatusCode, token[:min(8, len(token))], string(respBody))
		// If token is invalid/unregistered, don't return error (it's expected)
		if resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusBadRequest {
			return nil
		}
		return fmt.Errorf("fcm status %d: %s", resp.StatusCode, string(respBody))
	}

	return nil
}

// SendToMultiple sends a push notification to multiple device tokens.
func (c *Client) SendToMultiple(tokens []string, title, body string, data map[string]string) {
	for _, token := range tokens {
		if err := c.SendToDevice(token, title, body, data); err != nil {
			log.Printf("[FCM] Error sending to %s...: %v", token[:min(8, len(token))], err)
		}
	}
}
