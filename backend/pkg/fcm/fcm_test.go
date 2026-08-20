package fcm

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"golang.org/x/oauth2"
)

func TestAndroidPolicyUsesDeliberateChannels(t *testing.T) {
	tests := []struct {
		typeName string
		channel  string
		priority string
	}{
		{"event_reminder", "khair_reminders", "HIGH"},
		{"event_updated", "khair_updates", "HIGH"},
		{"event_cancelled", "khair_important", "HIGH"},
		{"support_reply", "khair_updates", "NORMAL"},
		{"general", "khair_general", "NORMAL"},
	}

	for _, tt := range tests {
		t.Run(tt.typeName, func(t *testing.T) {
			policy := androidPolicy(map[string]string{"type": tt.typeName, "event_id": "event-1"})
			if policy.channelID != tt.channel || policy.priority != tt.priority {
				t.Fatalf("policy = %#v, want channel=%s priority=%s", policy, tt.channel, tt.priority)
			}
		})
	}
}

func TestSendToDeviceUsesSystemTrayPayload(t *testing.T) {
	var received v1Message
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer test-access-token" {
			t.Fatalf("unexpected authorization header")
		}
		if err := json.NewDecoder(r.Body).Decode(&received); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"name":"projects/project/messages/1"}`))
	}))
	defer server.Close()

	client := &Client{
		projectID:  "project",
		httpClient: server.Client(),
		endpoint:   server.URL,
		tokenSrc:   oauth2.StaticTokenSource(&oauth2.Token{AccessToken: "test-access-token"}),
		enabled:    true,
	}
	err := client.SendToDevice("device-token", "Title", "Body", map[string]string{
		"type":            "event_reminder",
		"notification_id": "notification-1",
		"entity_type":     "event",
		"entity_id":       "event-1",
	})
	if err != nil {
		t.Fatalf("SendToDevice returned error: %v", err)
	}

	if received.Message.Notification == nil || received.Message.Notification.Title != "Title" {
		t.Fatalf("missing notification title: %#v", received.Message.Notification)
	}
	android := received.Message.Android
	if android == nil || android.Notification == nil {
		t.Fatalf("missing Android notification config: %#v", android)
	}
	if android.Notification.ChannelID != "khair_reminders" || android.Notification.Icon != "ic_stat_khair_notification" {
		t.Fatalf("unexpected Android tray configuration: %#v", android.Notification)
	}
	if received.Message.Data["notification_id"] != "notification-1" {
		t.Fatalf("notification ID was not preserved in data payload: %#v", received.Message.Data)
	}
}

func TestDisabledClientDoesNotPretendDelivery(t *testing.T) {
	client := &Client{}
	err := client.SendToDevice("device-token", "Title", "Body", nil)
	if !errorsIsConfiguration(err) {
		t.Fatalf("expected configuration failure, got %v", err)
	}
}

func TestClassifyResponseErrorRecognizesDeadTokens(t *testing.T) {
	err := classifyResponseError(http.StatusNotFound, []byte(`{"error":{"status":"UNREGISTERED","message":"Requested entity was not found."}}`))
	if !IsInvalidToken(err) {
		t.Fatalf("expected invalid token error, got %v", err)
	}
}

func errorsIsConfiguration(err error) bool {
	if err == nil {
		return false
	}
	var deliveryErr *DeliveryError
	return errors.As(err, &deliveryErr) && deliveryErr.Kind == FailureConfiguration
}
