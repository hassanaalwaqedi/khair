package fcm

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"
)

// Client sends push notifications via Firebase Cloud Messaging HTTP v1 API.
type Client struct {
	serverKey  string
	httpClient *http.Client
}

// NewClient creates a new FCM client. Pass the FCM server key.
func NewClient(serverKey string) *Client {
	return &Client{
		serverKey: serverKey,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// IsEnabled returns true if the FCM server key is configured.
func (c *Client) IsEnabled() bool {
	return c.serverKey != ""
}

// Notification is the display notification payload.
type Notification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

// Message is an FCM message to send to a device token.
type Message struct {
	To           string            `json:"to"`
	Notification *Notification     `json:"notification,omitempty"`
	Data         map[string]string `json:"data,omitempty"`
}

// Response is the FCM API response.
type Response struct {
	Success int `json:"success"`
	Failure int `json:"failure"`
}

// SendToDevice sends a push notification to a single device token.
func (c *Client) SendToDevice(token, title, body string, data map[string]string) error {
	if !c.IsEnabled() {
		log.Printf("[FCM] Disabled — would send to %s: %s", token, title)
		return nil
	}

	msg := Message{
		To: token,
		Notification: &Notification{
			Title: title,
			Body:  body,
		},
		Data: data,
	}

	payload, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("fcm marshal: %w", err)
	}

	req, err := http.NewRequest(http.MethodPost, "https://fcm.googleapis.com/fcm/send", bytes.NewReader(payload))
	if err != nil {
		return fmt.Errorf("fcm request: %w", err)
	}
	req.Header.Set("Authorization", "key="+c.serverKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("fcm send: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("fcm status %d: %s", resp.StatusCode, string(respBody))
	}

	var fcmResp Response
	if err := json.NewDecoder(resp.Body).Decode(&fcmResp); err != nil {
		log.Printf("[FCM] Response decode error: %v", err)
	} else if fcmResp.Failure > 0 {
		log.Printf("[FCM] Partial failure: success=%d failure=%d", fcmResp.Success, fcmResp.Failure)
	}

	return nil
}

// SendToMultiple sends a push notification to multiple device tokens.
func (c *Client) SendToMultiple(tokens []string, title, body string, data map[string]string) {
	for _, token := range tokens {
		if err := c.SendToDevice(token, title, body, data); err != nil {
			log.Printf("[FCM] Error sending to %s: %v", token[:8]+"...", err)
		}
	}
}
