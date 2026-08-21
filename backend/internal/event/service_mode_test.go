package event

import "testing"

func TestNormalizeEventMode(t *testing.T) {
	tests := []struct {
		name          string
		eventType     string
		isOnline      bool
		wantEventType string
		wantIsOnline  bool
	}{
		{
			name:          "online type takes precedence over stale false flag",
			eventType:     "online",
			isOnline:      false,
			wantEventType: "online",
			wantIsOnline:  true,
		},
		{
			name:          "in-person type is normalized to offline",
			eventType:     "in-person",
			isOnline:      true,
			wantEventType: "offline",
			wantIsOnline:  false,
		},
		{
			name:          "legacy type keeps explicit mode",
			eventType:     "workshop",
			isOnline:      true,
			wantEventType: "workshop",
			wantIsOnline:  true,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			gotEventType, gotIsOnline := normalizeEventMode(test.eventType, test.isOnline)
			if gotEventType != test.wantEventType || gotIsOnline != test.wantIsOnline {
				t.Fatalf("normalizeEventMode(%q, %t) = (%q, %t), want (%q, %t)", test.eventType, test.isOnline, gotEventType, gotIsOnline, test.wantEventType, test.wantIsOnline)
			}
		})
	}
}
