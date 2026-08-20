package reservation

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/khair/backend/internal/models"
)

func TestEventNotificationDataExcludesPrivateFields(t *testing.T) {
	address := "Private street 42"
	meetingURL := "https://meet.example/private"
	instructions := "Use the private link in your account"
	city := "Istanbul"
	amount := int64(1250)
	currency := "try"
	paymentMethod := "at_venue"

	data := eventNotificationData(&models.EventWithOrganizer{
		Event: models.Event{
			ID:               uuid.New(),
			Title:            "SQL & Victor Database",
			StartDate:        time.Date(2026, time.August, 21, 16, 0, 0, 0, time.UTC),
			Timezone:         "Europe/Istanbul",
			IsOnline:         true,
			City:             &city,
			Address:          &address,
			OnlineLink:       &meetingURL,
			JoinInstructions: &instructions,
			Pricing:          &models.PricingInfo{Type: "paid", AmountCents: &amount, Currency: &currency, PaymentMethod: &paymentMethod},
		},
	}, uuid.New())

	for _, key := range []string{"address", "online_link", "join_instructions", "meeting_url"} {
		if _, ok := data[key]; ok {
			t.Fatalf("private field %q leaked into notification data: %#v", key, data)
		}
	}
	if data["event_type"] != "online" || data["pricing_type"] != "paid" || data["public_location"] != city {
		t.Fatalf("safe event metadata missing: %#v", data)
	}
	if data["price_minor"] != "1250" || data["currency"] != "TRY" || data["payment_method"] != paymentMethod {
		t.Fatalf("safe pricing metadata missing: %#v", data)
	}
}
