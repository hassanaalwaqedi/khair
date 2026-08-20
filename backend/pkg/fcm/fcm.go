// Package fcm sends trusted, server-originated Firebase Cloud Messaging
// notifications. Client applications never receive these credentials.
package fcm

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

var ErrNotConfigured = errors.New("fcm is not configured")

// FailureKind lets callers distinguish permanent token failures from
// transient delivery failures.
type FailureKind string

const (
	FailureConfiguration FailureKind = "configuration"
	FailureInvalidToken  FailureKind = "invalid_token"
	FailureTransient     FailureKind = "transient"
	FailurePermanent     FailureKind = "permanent"
)

// DeliveryError is intentionally safe to log: it never includes device
// tokens, notification bodies, OAuth tokens, or service-account data.
type DeliveryError struct {
	Kind       FailureKind
	StatusCode int
	Err        error
}

func (e *DeliveryError) Error() string {
	if e.StatusCode > 0 {
		return fmt.Sprintf("fcm %s failure (http %d): %v", e.Kind, e.StatusCode, e.Err)
	}
	return fmt.Sprintf("fcm %s failure: %v", e.Kind, e.Err)
}

func (e *DeliveryError) Unwrap() error { return e.Err }

// IsInvalidToken reports whether Firebase rejected a token permanently.
func IsInvalidToken(err error) bool {
	var deliveryErr *DeliveryError
	return errors.As(err, &deliveryErr) && deliveryErr.Kind == FailureInvalidToken
}

// IsTransient reports whether one bounded retry is appropriate.
func IsTransient(err error) bool {
	var deliveryErr *DeliveryError
	return errors.As(err, &deliveryErr) && deliveryErr.Kind == FailureTransient
}

// DeliveryResult is returned to the trusted push service so it can deactivate
// invalid tokens. The token must never be written to logs.
type DeliveryResult struct {
	Token    string
	Attempts int
	Err      error
}

// Client sends push notifications via Firebase Cloud Messaging HTTP v1 API.
type Client struct {
	projectID  string
	httpClient *http.Client
	tokenSrc   oauth2.TokenSource
	endpoint   string
	mu         sync.Mutex
	enabled    bool
	initErr    error
}

// NewClient initializes Firebase HTTP v1 using the FCM_SERVICE_ACCOUNT secret.
// A file path is accepted only for explicit local development, never as a
// production fallback. Legacy server keys are deliberately not read.
func NewClient() *Client {
	c := &Client{
		httpClient: &http.Client{Timeout: 10 * time.Second},
		endpoint:   "https://fcm.googleapis.com",
	}

	saJSON := strings.TrimSpace(os.Getenv("FCM_SERVICE_ACCOUNT"))
	if saJSON == "" && !isProduction() {
		if saPath := strings.TrimSpace(os.Getenv("FCM_SERVICE_ACCOUNT_PATH")); saPath != "" {
			data, err := os.ReadFile(saPath)
			if err != nil {
				c.initErr = fmt.Errorf("read FCM service-account path: %w", err)
				log.Printf("[FCM] disabled: service-account path could not be read")
				return c
			}
			saJSON = string(data)
		}
	}

	if saJSON == "" {
		c.initErr = ErrNotConfigured
		log.Printf("[FCM] disabled: FCM_SERVICE_ACCOUNT is not configured")
		return c
	}

	var saCfg struct {
		ProjectID string `json:"project_id"`
	}
	if err := json.Unmarshal([]byte(saJSON), &saCfg); err != nil || strings.TrimSpace(saCfg.ProjectID) == "" {
		c.initErr = errors.New("invalid FCM service-account JSON")
		log.Printf("[FCM] disabled: FCM_SERVICE_ACCOUNT is not valid service-account JSON")
		return c
	}

	creds, err := google.CredentialsFromJSON(
		oauth2.NoContext,
		[]byte(saJSON),
		"https://www.googleapis.com/auth/firebase.messaging",
	)
	if err != nil {
		c.initErr = fmt.Errorf("create FCM credentials: %w", err)
		log.Printf("[FCM] disabled: service-account credentials could not be initialized")
		return c
	}

	c.projectID = saCfg.ProjectID
	c.tokenSrc = creds.TokenSource
	c.enabled = true
	log.Printf("[FCM] HTTP v1 initialized for project %s", c.projectID)
	return c
}

func isProduction() bool {
	return strings.EqualFold(os.Getenv("ENV"), "production") ||
		strings.EqualFold(os.Getenv("GIN_MODE"), "release")
}

// IsEnabled returns true only when Firebase credentials have been initialized.
func (c *Client) IsEnabled() bool { return c != nil && c.enabled }

// ConfigurationError is safe to expose in startup diagnostics.
func (c *Client) ConfigurationError() error {
	if c == nil {
		return ErrNotConfigured
	}
	return c.initErr
}

// v1Message is the FCM HTTP v1 API message format.
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
	CollapseKey  string              `json:"collapse_key,omitempty"`
	Notification *androidNotifConfig `json:"notification,omitempty"`
}

type androidNotifConfig struct {
	ChannelID            string `json:"channel_id,omitempty"`
	Icon                 string `json:"icon,omitempty"`
	Color                string `json:"color,omitempty"`
	Visibility           string `json:"visibility,omitempty"`
	NotificationPriority string `json:"notification_priority,omitempty"`
}

type androidDeliveryPolicy struct {
	channelID            string
	priority             string
	notificationPriority string
	collapseKey          string
}

// androidPolicy keeps notification visibility and urgency deliberate. Channel
// importance is ultimately controlled by the user in Android Settings.
func androidPolicy(data map[string]string) androidDeliveryPolicy {
	notifType := data["type"]
	entityID := data["entity_id"]
	if entityID == "" {
		entityID = data["event_id"]
	}

	policy := androidDeliveryPolicy{
		channelID:            "khair_general",
		priority:             "NORMAL",
		notificationPriority: "PRIORITY_DEFAULT",
	}

	switch notifType {
	case "event_reminder":
		policy.channelID = "khair_reminders"
		policy.priority = "HIGH"
		policy.notificationPriority = "PRIORITY_HIGH"
	case "event_updated":
		policy.channelID = "khair_updates"
		policy.priority = "HIGH"
	case "event_cancelled", "organizer_approved", "organizer_rejected",
		"organizer_revision_requested", "event_approved", "event_rejected",
		"event_revision_requested", "verification_review", "account_suspended":
		policy.channelID = "khair_important"
		policy.priority = "HIGH"
		policy.notificationPriority = "PRIORITY_HIGH"
	case "event_join_confirmed", "event_participant_joined", "support_reply",
		"support_attachment", "organizer_announcement":
		policy.channelID = "khair_updates"
	}

	if entityID != "" && (notifType == "event_updated" || notifType == "event_reminder") {
		policy.collapseKey = notifType + ":" + entityID
	}
	return policy
}

// SendToDevice sends a push notification to a single device token using FCM v1.
// A single bounded retry is used only for transient failures.
func (c *Client) SendToDevice(token, title, body string, data map[string]string) error {
	return c.sendToDevice(token, title, body, data).Err
}

func (c *Client) sendToDevice(token, title, body string, data map[string]string) DeliveryResult {
	if !c.IsEnabled() {
		return DeliveryResult{Token: token, Attempts: 1, Err: &DeliveryError{Kind: FailureConfiguration, Err: ErrNotConfigured}}
	}

	result := DeliveryResult{Token: token}
	for attempt := 1; attempt <= 2; attempt++ {
		result.Attempts = attempt
		err := c.sendOnce(token, title, body, data)
		if err == nil {
			return result
		}
		result.Err = err
		if !IsTransient(err) || attempt == 2 {
			return result
		}
		time.Sleep(200 * time.Millisecond)
	}
	return result
}

func (c *Client) sendOnce(token, title, body string, data map[string]string) error {
	c.mu.Lock()
	tok, err := c.tokenSrc.Token()
	c.mu.Unlock()
	if err != nil {
		return &DeliveryError{Kind: FailureTransient, Err: fmt.Errorf("obtain OAuth token: %w", err)}
	}

	policy := androidPolicy(data)
	msg := v1Message{}
	msg.Message.Token = token
	msg.Message.Notification = &v1Notification{Title: title, Body: body}
	msg.Message.Data = data
	msg.Message.Android = &androidConfig{
		Priority:    policy.priority,
		CollapseKey: policy.collapseKey,
		Notification: &androidNotifConfig{
			ChannelID:            policy.channelID,
			Icon:                 "ic_stat_khair_notification",
			Color:                "#F43F75",
			Visibility:           "PRIVATE",
			NotificationPriority: policy.notificationPriority,
		},
	}

	payload, err := json.Marshal(msg)
	if err != nil {
		return &DeliveryError{Kind: FailurePermanent, Err: fmt.Errorf("marshal message: %w", err)}
	}

	url := fmt.Sprintf("%s/v1/projects/%s/messages:send", strings.TrimRight(c.endpoint, "/"), c.projectID)
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(payload))
	if err != nil {
		return &DeliveryError{Kind: FailurePermanent, Err: fmt.Errorf("build request: %w", err)}
	}
	req.Header.Set("Authorization", "Bearer "+tok.AccessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return &DeliveryError{Kind: FailureTransient, Err: fmt.Errorf("send request: %w", err)}
	}
	defer resp.Body.Close()

	if resp.StatusCode >= http.StatusOK && resp.StatusCode < http.StatusMultipleChoices {
		return nil
	}
	responseBody, _ := io.ReadAll(io.LimitReader(resp.Body, 16<<10))
	return classifyResponseError(resp.StatusCode, responseBody)
}

type fcmErrorResponse struct {
	Error struct {
		Status  string `json:"status"`
		Message string `json:"message"`
	} `json:"error"`
}

func classifyResponseError(statusCode int, body []byte) error {
	var response fcmErrorResponse
	_ = json.Unmarshal(body, &response)
	status := strings.ToUpper(response.Error.Status)
	message := strings.ToLower(response.Error.Message)

	if status == "UNREGISTERED" ||
		(status == "INVALID_ARGUMENT" && strings.Contains(message, "registration token")) {
		return &DeliveryError{Kind: FailureInvalidToken, StatusCode: statusCode, Err: errors.New("token rejected by Firebase")}
	}
	if statusCode == http.StatusTooManyRequests || statusCode >= http.StatusInternalServerError ||
		status == "UNAVAILABLE" || status == "INTERNAL" {
		return &DeliveryError{Kind: FailureTransient, StatusCode: statusCode, Err: errors.New("Firebase service unavailable")}
	}
	return &DeliveryError{Kind: FailurePermanent, StatusCode: statusCode, Err: errors.New("Firebase rejected message")}
}

// SendToMultiple sends a push to each registered device and returns per-device
// outcomes so the push service can retire invalid registrations.
func (c *Client) SendToMultiple(tokens []string, title, body string, data map[string]string) []DeliveryResult {
	results := make([]DeliveryResult, 0, len(tokens))
	for _, token := range tokens {
		results = append(results, c.sendToDevice(token, title, body, data))
	}
	return results
}
