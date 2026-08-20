package push

import "testing"

func TestPublicFCMDataStripsPrivateFields(t *testing.T) {
	payload := publicFCMData(map[string]string{
		"notification_id": "notification-1",
		"type":            "event_rejected",
		"event_id":        "event-1",
		"reason":          "internal reviewer note",
		"notes":           "private document URL",
		"online_link":     "https://private.example",
	})

	if payload["notification_id"] != "notification-1" || payload["event_id"] != "event-1" {
		t.Fatalf("navigation metadata was lost: %#v", payload)
	}
	for _, privateKey := range []string{"reason", "notes", "online_link"} {
		if _, ok := payload[privateKey]; ok {
			t.Fatalf("private key %q leaked into FCM data: %#v", privateKey, payload)
		}
	}
}
