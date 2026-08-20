package reservation

import (
	"log"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
)

// sendStructuredJoinNotifications runs after ReserveSeat has committed. The
// notification service persists the localized record before this method sends
// the matching FCM preview.
func (h *Handler) sendStructuredJoinNotifications(userID, eventID uuid.UUID) {
	evt, err := h.eventSvc.GetByID(eventID)
	if err != nil {
		log.Printf("[NOTIFICATION] Failed to get event for join notification: %v", err)
		return
	}
	data := eventNotificationData(evt, eventID)

	if h.notifSvc == nil {
		return
	}

	attendeeCopy, err := h.notifSvc.CreateLocalized(userID, "event_join_confirmed", data)
	if err != nil {
		log.Printf("[NOTIFICATION] Failed to create user join notification: %v", err)
		return
	}
	if h.pushSvc != nil {
		h.pushSvc.SendToUser(userID, attendeeCopy.Title, attendeeCopy.Message, map[string]string{
			"type":     "event_join_confirmed",
			"event_id": eventID.String(),
		})
	}

	organizerUserID := h.getOrganizerUserID(evt.OrganizerID)
	if organizerUserID == uuid.Nil {
		return
	}
	organizerCopy, err := h.notifSvc.CreateLocalized(organizerUserID, "event_participant_joined", data)
	if err != nil {
		log.Printf("[NOTIFICATION] Failed to create organizer join notification: %v", err)
		return
	}
	if h.pushSvc != nil {
		h.pushSvc.SendToUser(organizerUserID, organizerCopy.Title, organizerCopy.Message, map[string]string{
			"type":     "event_participant_joined",
			"event_id": eventID.String(),
		})
	}
}

// eventNotificationData is a safe historical snapshot. It intentionally
// excludes the private address, online meeting URL, and join instructions.
func eventNotificationData(evt *models.EventWithOrganizer, eventID uuid.UUID) map[string]string {
	data := map[string]string{
		"entity_type":  "event",
		"entity_id":    eventID.String(),
		"event_id":     eventID.String(),
		"event_title":  evt.Title,
		"start_at":     evt.StartDate.Format(time.RFC3339),
		"timezone":     evt.Timezone,
		"event_type":   "in_person",
		"pricing_type": "free",
	}
	if location, err := time.LoadLocation(evt.Timezone); err == nil {
		data["event_local_start"] = evt.StartDate.In(location).Format("2006-01-02T15:04:05")
	} else {
		data["event_local_start"] = evt.StartDate.Format("2006-01-02T15:04:05")
	}
	if evt.IsOnline {
		data["event_type"] = "online"
	}
	if strings.TrimSpace(data["timezone"]) == "" {
		data["timezone"] = "UTC"
	}
	if evt.City != nil && strings.TrimSpace(*evt.City) != "" {
		data["public_location"] = strings.TrimSpace(*evt.City)
	}
	if evt.Pricing != nil && evt.Pricing.Type == "paid" {
		data["pricing_type"] = "paid"
		if evt.Pricing.AmountCents != nil && *evt.Pricing.AmountCents > 0 {
			data["price_minor"] = strconv.FormatInt(*evt.Pricing.AmountCents, 10)
		}
		if evt.Pricing.Currency != nil && strings.TrimSpace(*evt.Pricing.Currency) != "" {
			data["currency"] = strings.ToUpper(strings.TrimSpace(*evt.Pricing.Currency))
		}
		if evt.Pricing.PaymentMethod != nil {
			data["payment_method"] = *evt.Pricing.PaymentMethod
		}
	}
	return data
}
