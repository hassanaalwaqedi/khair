package notification

import (
	"context"
	"database/sql"
	"fmt"
	"strings"

	"github.com/google/uuid"
)

// LocalizedNotification is the server-side title/body used for the database
// record and for the push preview. Rich in-app presentation is resolved from
// the structured data by the client.
type LocalizedNotification struct {
	Title   string
	Message string
}

// NormalizeLanguage keeps notification delivery on the same supported
// language set as the profile and Flutter locale layers.
func NormalizeLanguage(language string) string {
	language = strings.ToLower(strings.TrimSpace(language))
	if separator := strings.IndexAny(language, "-_"); separator > 0 {
		language = language[:separator]
	}
	switch language {
	case "ar", "tr":
		return language
	default:
		return "en"
	}
}

// Render returns one-language system copy for a structured notification.
// User-generated values, such as event titles and organizer notes, are
// inserted unchanged and are never translated here.
func Render(notificationType string, data map[string]string, language string) LocalizedNotification {
	language = NormalizeLanguage(language)

	switch notificationType {
	case "event_join_confirmed", "event_joined":
		eventTitle := data["event_title"]
		switch language {
		case "ar":
			return LocalizedNotification{Title: "\u062a\u0645 \u062a\u0623\u0643\u064a\u062f \u0627\u0646\u0636\u0645\u0627\u0645\u0643 \U0001f389", Message: fmt.Sprintf("\u0627\u0646\u0636\u0645\u0645\u062a \u0628\u0646\u062c\u0627\u062d \u0625\u0644\u0649\n%s", eventTitle)}
		case "tr":
			return LocalizedNotification{Title: "Kayd\u0131n\u0131z onayland\u0131 \U0001f389", Message: fmt.Sprintf("%s etkinli\u011fine ba\u015far\u0131yla kat\u0131ld\u0131n\u0131z.", eventTitle)}
		default:
			return LocalizedNotification{Title: "You're registered \U0001f389", Message: fmt.Sprintf("You've successfully joined\n%s", eventTitle)}
		}

	case "event_participant_joined", "new_participant":
		eventTitle := data["event_title"]
		switch language {
		case "ar":
			return LocalizedNotification{Title: "\u0627\u0646\u0636\u0645 \u0645\u0634\u0627\u0631\u0643 \u062c\u062f\u064a\u062f", Message: fmt.Sprintf("\u0627\u0646\u0636\u0645 \u0645\u0634\u0627\u0631\u0643 \u062c\u062f\u064a\u062f \u0625\u0644\u0649 \u0641\u0639\u0627\u0644\u064a\u062a\u0643:\n%s", eventTitle)}
		case "tr":
			return LocalizedNotification{Title: "Yeni kat\u0131l\u0131mc\u0131 kat\u0131ld\u0131", Message: fmt.Sprintf("Etkinli\u011finize yeni bir kat\u0131l\u0131mc\u0131 kat\u0131ld\u0131:\n%s", eventTitle)}
		default:
			return LocalizedNotification{Title: "New participant joined", Message: fmt.Sprintf("A new participant joined your event:\n%s", eventTitle)}
		}

	case "welcome":
		firstName := data["first_name"]
		if strings.TrimSpace(firstName) == "" {
			firstName = map[string]string{"en": "there", "ar": "\u0628\u0643", "tr": "orada"}[language]
		}
		if isUnderReviewRole(data["role"]) {
			return renderWelcomeUnderReview(firstName, language)
		}
		switch language {
		case "ar":
			return LocalizedNotification{Title: "\u0645\u0631\u062d\u0628\u064b\u0627 \u0628\u0643 \u0641\u064a \u062e\u064a\u0631 \U0001f389", Message: fmt.Sprintf("\u0627\u0644\u0633\u0644\u0627\u0645 \u0639\u0644\u064a\u0643\u0645 %s\u060c\n\u064a\u0633\u0639\u062f\u0646\u0627 \u0627\u0646\u0636\u0645\u0627\u0645\u0643 \u0625\u0644\u0649 \u062e\u064a\u0631. \u0627\u0628\u062f\u0623 \u0628\u0627\u0643\u062a\u0634\u0627\u0641 \u0627\u0644\u0641\u0639\u0627\u0644\u064a\u0627\u062a \u0648\u0627\u0644\u0645\u062c\u062a\u0645\u0639\u0627\u062a \u0627\u0644\u062a\u064a \u062a\u0647\u0645\u0643.", firstName)}
		case "tr":
			return LocalizedNotification{Title: "Khair'e ho\u015f geldiniz \U0001f389", Message: fmt.Sprintf("%s, Khair'e ho\u015f geldiniz.\n\u0130lginizi \u00e7eken etkinlikleri ve topluluklar\u0131 ke\u015ffetmeye ba\u015flay\u0131n.", firstName)}
		default:
			return LocalizedNotification{Title: "Welcome to Khair \U0001f389", Message: fmt.Sprintf("Assalamu Alaikum %s,\nWe're glad you're here. Start discovering events and communities that interest you.", firstName)}
		}

	case "event_reminder":
		eventTitle := data["event_title"]
		label := localizedReminderLabel(data["reminder_label"], language)
		switch language {
		case "ar":
			return LocalizedNotification{Title: "\u062a\u0630\u0643\u064a\u0631 \u0628\u0627\u0644\u0641\u0639\u0627\u0644\u064a\u0629", Message: fmt.Sprintf("\u062a\u0628\u062f\u0623 \u0641\u0639\u0627\u0644\u064a\u0629 %s \u062e\u0644\u0627\u0644 %s.", eventTitle, label)}
		case "tr":
			return LocalizedNotification{Title: "Etkinlik hat\u0131rlat\u0131c\u0131s\u0131", Message: fmt.Sprintf("%s etkinli\u011fi %s i\u00e7inde ba\u015fl\u0131yor.", eventTitle, label)}
		default:
			return LocalizedNotification{Title: "Event reminder", Message: fmt.Sprintf("%s starts in %s.", eventTitle, label)}
		}
	case "event_updated":
		eventTitle := data["event_title"]
		switch language {
		case "ar":
			return LocalizedNotification{Title: "تم تحديث موعد الفعالية", Message: fmt.Sprintf("تم تغيير موعد %s. راجع تفاصيل الفعالية.", eventTitle)}
		case "tr":
			return LocalizedNotification{Title: "Etkinlik zamanı güncellendi", Message: fmt.Sprintf("%s etkinliğinin zamanı değişti. Ayrıntıları gözden geçirin.", eventTitle)}
		default:
			return LocalizedNotification{Title: "Event time updated", Message: fmt.Sprintf("The time for %s has changed. Review the event details.", eventTitle)}
		}
	case "event_cancelled":
		eventTitle := data["event_title"]
		switch language {
		case "ar":
			return LocalizedNotification{Title: "تم إلغاء الفعالية", Message: fmt.Sprintf("تم إلغاء %s. راجع تفاصيل الفعالية.", eventTitle)}
		case "tr":
			return LocalizedNotification{Title: "Etkinlik iptal edildi", Message: fmt.Sprintf("%s etkinliği iptal edildi. Ayrıntıları gözden geçirin.", eventTitle)}
		default:
			return LocalizedNotification{Title: "Event cancelled", Message: fmt.Sprintf("%s has been cancelled. Review the event details.", eventTitle)}
		}
	case "event_cancellation_requested":
		eventTitle := data["event_title"]
		startAt := data["start_at"]
		switch language {
		case "ar":
			return LocalizedNotification{Title: "طلب إلغاء فعالية", Message: fmt.Sprintf("طلب المنظم إلغاء الفعالية %s التي تبدأ في %s. يرجى مراجعة القرار.", eventTitle, startAt)}
		case "tr":
			return LocalizedNotification{Title: "Etkinlik iptal talebi", Message: fmt.Sprintf("Organizatör %s etkinliğinin iptal edilmesini istedi. Başlangıç: %s. Lütfen inceleyin.", eventTitle, startAt)}
		default:
			return LocalizedNotification{Title: "Event cancellation request", Message: fmt.Sprintf("The organizer requested cancellation of %s, starting %s. Please review it.", eventTitle, startAt)}
		}
	case "organizer_announcement":
		eventTitle := data["event_title"]
		switch language {
		case "ar":
			return LocalizedNotification{Title: "تحديث من منظم الفعالية", Message: fmt.Sprintf("يوجد تحديث جديد للفعالية %s. افتح خير لعرض التفاصيل.", eventTitle)}
		case "tr":
			return LocalizedNotification{Title: "Organizatörden etkinlik güncellemesi", Message: fmt.Sprintf("%s etkinliği için yeni bir güncelleme var. Ayrıntıları görmek için Khair'i açın.", eventTitle)}
		default:
			return LocalizedNotification{Title: "Event update from the organizer", Message: fmt.Sprintf("There is a new update for %s. Open Khair to view the details.", eventTitle)}
		}

	case "verification_review":
		return renderVerificationReview(data["status"], "", language)
	case "organizer_application":
		return renderOrganizerApplication(data["status"], data["organizer_name"], "", language)
	case "event_status":
		return renderEventStatus(data["status"], data["event_title"], "", language)
	case "account_status":
		return renderAccountStatus(data["status"], data["reason"], language)
	case "support_reply":
		switch language {
		case "ar":
			return LocalizedNotification{Title: "\u062f\u0639\u0645 \u062e\u064a\u0631", Message: "\u0644\u062f\u064a\u0643 \u0631\u062f \u062c\u062f\u064a\u062f \u0645\u0646 \u0641\u0631\u064a\u0642 \u0627\u0644\u062f\u0639\u0645."}
		case "tr":
			return LocalizedNotification{Title: "Khair Destek", Message: "Destek ekibimizden yeni bir yan\u0131t\u0131n\u0131z var."}
		default:
			return LocalizedNotification{Title: "Khair Support", Message: "You have a new reply from our support team."}
		}
	case "support_attachment":
		switch language {
		case "ar":
			return LocalizedNotification{Title: "\u062f\u0639\u0645 \u062e\u064a\u0631", Message: "\u0623\u0631\u0633\u0644 \u0641\u0631\u064a\u0642 \u0627\u0644\u062f\u0639\u0645 \u0645\u0631\u0641\u0642\u064b\u0627 \u0625\u0644\u0649 \u0645\u062d\u0627\u062f\u062b\u062a\u0643."}
		case "tr":
			return LocalizedNotification{Title: "Khair Destek", Message: "Destek ekibimiz görüşmenize bir ek gönderdi."}
		default:
			return LocalizedNotification{Title: "Khair Support", Message: "Our support team sent an attachment to your conversation."}
		}
	}

	return LocalizedNotification{}
}

func (s *Service) CreateLocalized(userID uuid.UUID, notificationType string, data map[string]string) (LocalizedNotification, error) {
	presentation, _, _, err := s.CreateLocalizedOnce(userID, notificationType, data, "")
	return presentation, err
}

// CreateLocalizedWithID persists one notification and returns the ID that must
// be attached to the matching FCM payload.
func (s *Service) CreateLocalizedWithID(userID uuid.UUID, notificationType string, data map[string]string) (LocalizedNotification, uuid.UUID, error) {
	presentation, id, _, err := s.CreateLocalizedOnce(userID, notificationType, data, "")
	return presentation, id, err
}

// CreateLocalizedOnce creates a localized notification only once for a
// per-user business-operation key. A retry receives the original ID and false.
func (s *Service) CreateLocalizedOnce(userID uuid.UUID, notificationType string, data map[string]string, dedupeKey string) (LocalizedNotification, uuid.UUID, bool, error) {
	presentation, err := s.LocalizeForUser(userID, notificationType, data)
	if err != nil {
		return LocalizedNotification{}, uuid.Nil, false, err
	}
	id, created, err := s.CreateTypedOnce(userID, presentation.Title, presentation.Message, notificationType, data, dedupeKey)
	if err != nil {
		return LocalizedNotification{}, uuid.Nil, false, err
	}
	return presentation, id, created, nil
}

// LocalizeForUser resolves system copy using the recipient's stored Khair
// language without persisting a notification.
func (s *Service) LocalizeForUser(userID uuid.UUID, notificationType string, data map[string]string) (LocalizedNotification, error) {
	language := "en"
	var storedLanguage sql.NullString
	err := s.db.QueryRowContext(context.Background(), `
		SELECT COALESCE(p.preferred_language, 'en')
		FROM users u LEFT JOIN profiles p ON p.user_id = u.id
		WHERE u.id = $1`, userID).Scan(&storedLanguage)
	if err == nil && storedLanguage.Valid {
		language = NormalizeLanguage(storedLanguage.String)
	}
	presentation := Render(notificationType, data, language)
	if presentation.Title == "" || presentation.Message == "" {
		return LocalizedNotification{}, fmt.Errorf("no localized template for notification type %q", notificationType)
	}
	return presentation, nil
}

func isUnderReviewRole(role string) bool {
	switch role {
	case "sheikh", "organization", "community_organizer":
		return true
	default:
		return false
	}
}

func renderWelcomeUnderReview(firstName, language string) LocalizedNotification {
	switch language {
	case "ar":
		return LocalizedNotification{Title: "\u0645\u0631\u062d\u0628\u064b\u0627 \u0628\u0643 \u0641\u064a \u062e\u064a\u0631 \u2013 \u0627\u0644\u062d\u0633\u0627\u0628 \u0642\u064a\u062f \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629", Message: fmt.Sprintf("\u0627\u0644\u0633\u0644\u0627\u0645 \u0639\u0644\u064a\u0643\u0645 %s\u060c\n\u062d\u0633\u0627\u0628\u0643 \u0642\u064a\u062f \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u0645\u0646 \u0641\u0631\u064a\u0642 \u062e\u064a\u0631. \u0633\u0646\u062e\u0628\u0631\u0643 \u0639\u0646\u062f \u0627\u0643\u062a\u0645\u0627\u0644 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629.", firstName)}
	case "tr":
		return LocalizedNotification{Title: "Khair'e ho\u015f geldiniz \u2013 Hesab\u0131n\u0131z inceleniyor", Message: fmt.Sprintf("%s,\nHesab\u0131n\u0131z Khair ekibi taraf\u0131ndan inceleniyor. \u0130nceleme tamamland\u0131\u011f\u0131nda sizi bilgilendirece\u011fiz.", firstName)}
	default:
		return LocalizedNotification{Title: "Welcome to Khair \u2013 Account under review", Message: fmt.Sprintf("Assalamu Alaikum %s,\nYour account is under review by the Khair team. We will notify you when the review is complete.", firstName)}
	}
}

func renderLegacyWelcomeUnderReview(firstName, language string) LocalizedNotification {
	/* legacy implementation retained only as a migration reference.
		switch language {
		case "ar":
			return LocalizedNotification{Title: "\u0645\u0631\u062d\u0628\u064b\u0627 \u0628\u0643 \u0641\u064a \u062e\u064a\u0631 \u2013 \u0627\u0644\u062d\u0633\u0627\u0628 \u0642\u064a\u062f \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629", Message: fmt.Sprintf("\u0627\u0644\u0633\u0644\u0627\u0645 \u0639\u0644\u064a\u0643\u0645 %s\u060c\n\u062d\u0633\u0627\u0628\u0643 \u0642\u064a\u062f \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u0645\u0646 \u0641\u0631\u064a\u0642 \u062e\u064a\u0631. \u0633\u0646\u062e\u0628\u0631\u0643 \u0639\u0646\u062f \u0627\u0643\u062a\u0645\u0627\u0644 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629.", firstName)}
		case "tr":
			return LocalizedNotification{Title: "Khair'e ho\u015f geldiniz \u2013 Hesab\u0131n\u0131z inceleniyor", Message: fmt.Sprintf("%s,\nHesab\u0131n\u0131z Khair ekibi taraf\u0131ndan inceleniyor. \u0130nceleme tamamland\u0131\u011f\u0131nda sizi bilgilendirece\u011fiz.", firstName)}
		default:
			return LocalizedNotification{Title: "Welcome to Khair – Account under review", Message: fmt.Sprintf("Assalamu Alaikum %s,\nYour account is under review by the Khair team. We will notify you when the review is complete.", firstName)}
		}
	}

	*/
	return LocalizedNotification{}
}

func renderVerificationReview(status, notes, language string) LocalizedNotification {
	var copy LocalizedNotification
	switch language {
	case "ar":
		switch status {
		case "approved":
			copy = LocalizedNotification{Title: "\u062a\u0645 \u0627\u0644\u062a\u062d\u0642\u0642 \u0645\u0646 \u0627\u0644\u062d\u0633\u0627\u0628 \u2705", Message: "\u062a\u0645 \u0627\u0644\u062a\u062d\u0642\u0642 \u0645\u0646 \u062d\u0633\u0627\u0628\u0643. \u064a\u0645\u0643\u0646\u0643 \u0627\u0644\u0622\u0646 \u0628\u062f\u0621 \u0627\u0644\u062a\u062f\u0631\u064a\u0633 \u0648\u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u0641\u0639\u0627\u0644\u064a\u0627\u062a."}
		case "rejected":
			copy = LocalizedNotification{Title: "\u062a\u0645 \u0631\u0641\u0636 \u0627\u0644\u062a\u062d\u0642\u0642 \u0645\u0646 \u0627\u0644\u062d\u0633\u0627\u0628 \u274c", Message: "\u062a\u0645 \u0631\u0641\u0636 \u0637\u0644\u0628 \u0627\u0644\u062a\u062d\u0642\u0642 \u0627\u0644\u062e\u0627\u0635 \u0628\u0643."}
		case "more_info_needed":
			copy = LocalizedNotification{Title: "\u0645\u0639\u0644\u0648\u0645\u0627\u062a \u0625\u0636\u0627\u0641\u064a\u0629 \u0645\u0637\u0644\u0648\u0628\u0629 \u26a0\ufe0f", Message: "\u064a\u0631\u062c\u0649 \u062a\u062d\u062f\u064a\u062b \u0645\u0633\u062a\u0646\u062f\u0627\u062a \u0627\u0644\u062a\u062d\u0642\u0642 \u0627\u0644\u062e\u0627\u0635\u0629 \u0628\u0643."}
		}
	case "tr":
		switch status {
		case "approved":
			copy = LocalizedNotification{Title: "Hesab\u0131n\u0131z do\u011fruland\u0131 \u2705", Message: "Hesab\u0131n\u0131z do\u011fruland\u0131. Art\u0131k e\u011fitim verebilir ve etkinlik olu\u015fturabilirsiniz."}
		case "rejected":
			copy = LocalizedNotification{Title: "Do\u011frulama reddedildi \u274c", Message: "Do\u011frulama ba\u015fvurunuz reddedildi."}
		case "more_info_needed":
			copy = LocalizedNotification{Title: "Ek bilgi gerekli \u26a0\ufe0f", Message: "L\u00fctfen do\u011frulama belgelerinizi g\u00fcncelleyin."}
		}
	default:
		switch status {
		case "approved":
			copy = LocalizedNotification{Title: "\u2705 Account verified", Message: "Your account has been verified. You can now start teaching and creating events."}
		case "rejected":
			copy = LocalizedNotification{Title: "\u274c Verification rejected", Message: "Your verification request was rejected."}
		case "more_info_needed":
			copy = LocalizedNotification{Title: "\u26a0\ufe0f Additional information required", Message: "Please update your verification documents."}
		}
	}
	if strings.TrimSpace(notes) != "" && copy.Message != "" {
		prefix := map[string]string{"en": "Reason:", "ar": "\u0627\u0644\u0633\u0628\u0628:", "tr": "Not:"}[language]
		if status == "more_info_needed" {
			prefix = map[string]string{"en": "Note:", "ar": "\u0645\u0644\u0627\u062d\u0638\u0629:", "tr": "Not:"}[language]
		}
		copy.Message = strings.TrimSpace(copy.Message + " " + prefix + " " + notes)
	}
	return copy
}

func renderLegacyVerificationReview(status, notes, language string) LocalizedNotification {
	/* legacy implementation retained only as a migration reference.
		var copy LocalizedNotification
		switch language {
		case "ar":
			switch status {
			case "approved":
				copy = LocalizedNotification{Title: "\u062a\u0645 \u0627\u0644\u062a\u062d\u0642\u0642 \u0645\u0646 \u0627\u0644\u062d\u0633\u0627\u0628 \u2705", Message: "\u062a\u0645 \u0627\u0644\u062a\u062d\u0642\u0642 \u0645\u0646 \u062d\u0633\u0627\u0628\u0643. \u064a\u0645\u0643\u0646\u0643 \u0627\u0644\u0622\u0646 \u0628\u062f\u0621 \u0627\u0644\u062a\u062f\u0631\u064a\u0633 \u0648\u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u0641\u0639\u0627\u0644\u064a\u0627\u062a."}
			case "rejected":
				copy = LocalizedNotification{Title: "\u062a\u0645 \u0631\u0641\u0636 \u0627\u0644\u062a\u062d\u0642\u0642 \u0645\u0646 \u0627\u0644\u062d\u0633\u0627\u0628 \u274c", Message: "\u062a\u0645 \u0631\u0641\u0636 \u0637\u0644\u0628 \u0627\u0644\u062a\u062d\u0642\u0642 \u0627\u0644\u062e\u0627\u0635 \u0628\u0643."}
			case "more_info_needed":
				copy = LocalizedNotification{Title: "\u0645\u0639\u0644\u0648\u0645\u0627\u062a \u0625\u0636\u0627\u0641\u064a\u0629 \u0645\u0637\u0644\u0648\u0628\u0629 \u26a0\ufe0f", Message: "\u064a\u0631\u062c\u0649 \u062a\u062d\u062f\u064a\u062b \u0645\u0633\u062a\u0646\u062f\u0627\u062a \u0627\u0644\u062a\u062d\u0642\u0642 \u0627\u0644\u062e\u0627\u0635\u0629 \u0628\u0643."}
			}
		case "tr":
			switch status {
			case "approved":
				copy = LocalizedNotification{Title: "Hesab\u0131n\u0131z do\u011fruland\u0131 \u2705", Message: "Hesab\u0131n\u0131z do\u011fruland\u0131. Art\u0131k e\u011fitim verebilir ve etkinlik olu\u015fturabilirsiniz."}
			case "rejected":
				copy = LocalizedNotification{Title: "Do\u011frulama reddedildi \u274c", Message: "Do\u011frulama ba\u015fvurunuz reddedildi."}
			case "more_info_needed":
				copy = LocalizedNotification{Title: "Ek bilgi gerekli \u26a0\ufe0f", Message: "L\u00fctfen do\u011frulama belgelerinizi g\u00fcncelleyin."}
			}
		default:
			switch status {
			case "approved":
				copy = LocalizedNotification{Title: "✅ Account verified", Message: "Your account has been verified. You can now start teaching and creating events."}
			case "rejected":
				copy = LocalizedNotification{Title: "❌ Verification rejected", Message: "Your verification request was rejected."}
			case "more_info_needed":
				copy = LocalizedNotification{Title: "⚠️ Additional information required", Message: "Please update your verification documents."}
			}
		}
		if strings.TrimSpace(notes) != "" && copy.Message != "" {
			prefix := map[string]string{"en": "Reason:", "ar": "\u0627\u0644\u0633\u0628\u0628:", "tr": "Not:"}[language]
			if status == "more_info_needed" {
				prefix = map[string]string{"en": "Note:", "ar": "\u0645\u0644\u0627\u062d\u0638\u0629:", "tr": "Not:"}[language]
			}
			copy.Message = strings.TrimSpace(copy.Message + " " + prefix + " " + notes)
		}
		return copy
	}

	*/
	return LocalizedNotification{}
}

func renderOrganizerApplication(status, organizerName, reason, language string) LocalizedNotification {
	if organizerName == "" {
		organizerName = "Khair"
	}
	switch language {
	case "ar":
		switch status {
		case "submitted":
			return LocalizedNotification{Title: "\u0637\u0644\u0628 \u0645\u0646\u0638\u0645 \u062c\u062f\u064a\u062f", Message: "\u064a\u0648\u062c\u062f \u0637\u0644\u0628 \u0645\u0646\u0638\u0645 \u062c\u062f\u064a\u062f \u062c\u0627\u0647\u0632 \u0644\u0644\u0645\u0631\u0627\u062c\u0639\u0629."}
		case "approved":
			return LocalizedNotification{Title: "\u062a\u0645\u062a \u0627\u0644\u0645\u0648\u0627\u0641\u0642\u0629 \u0639\u0644\u0649 \u0637\u0644\u0628 \u0627\u0644\u0645\u0646\u0638\u0645", Message: fmt.Sprintf("\u062a\u0645\u062a \u0627\u0644\u0645\u0648\u0627\u0641\u0642\u0629 \u0639\u0644\u0649 \u0637\u0644\u0628 \u0627\u0644\u0645\u0646\u0638\u0645 \u0644\u0640 %s. \u064a\u0645\u0643\u0646\u0643 \u0627\u0644\u0622\u0646 \u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u0641\u0639\u0627\u0644\u064a\u0627\u062a \u0648\u0625\u062f\u0627\u0631\u062a\u0647\u0627.", organizerName)}
		case "needs_revision":
			return LocalizedNotification{Title: "\u064a\u062d\u062a\u0627\u062c \u0637\u0644\u0628 \u0627\u0644\u0645\u0646\u0638\u0645 \u0625\u0644\u0649 \u062a\u0639\u062f\u064a\u0644\u0627\u062a", Message: fmt.Sprintf("\u064a\u062d\u062a\u0627\u062c \u0637\u0644\u0628 \u0627\u0644\u0645\u0646\u0638\u0645 \u0644\u0640 %s \u0625\u0644\u0649 \u062a\u0639\u062f\u064a\u0644\u0627\u062a: %s", organizerName, reason)}
		case "rejected":
			return LocalizedNotification{Title: "\u062a\u062d\u062f\u064a\u062b \u0628\u0634\u0623\u0646 \u0637\u0644\u0628 \u0627\u0644\u0645\u0646\u0638\u0645", Message: fmt.Sprintf("\u064a\u062d\u062a\u0627\u062c \u0637\u0644\u0628 \u0627\u0644\u0645\u0646\u0638\u0645 \u0644\u0640 %s \u0625\u0644\u0649 \u0627\u0646\u062a\u0628\u0627\u0647\u0643: %s", organizerName, reason)}
		}
	case "tr":
		switch status {
		case "submitted":
			return LocalizedNotification{Title: "Yeni organizat\u00f6r ba\u015fvurusu", Message: "\u0130ncelenmeye haz\u0131r yeni bir organizat\u00f6r ba\u015fvurusu var."}
		case "approved":
			return LocalizedNotification{Title: "Organizat\u00f6r ba\u015fvurusu onayland\u0131", Message: fmt.Sprintf("%s i\u00e7in organizat\u00f6r ba\u015fvurunuz onayland\u0131. Art\u0131k etkinlik olu\u015fturabilir ve y\u00f6netebilirsiniz.", organizerName)}
		case "needs_revision":
			return LocalizedNotification{Title: "Organizat\u00f6r ba\u015fvurusunda de\u011fi\u015fiklik gerekiyor", Message: fmt.Sprintf("%s i\u00e7in organizat\u00f6r ba\u015fvurunuzda de\u011fi\u015fiklik gerekiyor: %s", organizerName, reason)}
		case "rejected":
			return LocalizedNotification{Title: "Organizat\u00f6r ba\u015fvurusu g\u00fcncellendi", Message: fmt.Sprintf("%s i\u00e7in organizat\u00f6r ba\u015fvurunuzun ilgilenilmesi gerekiyor: %s", organizerName, reason)}
		}
	default:
		switch status {
		case "submitted":
			return LocalizedNotification{Title: "New organizer application", Message: "A new organizer application is ready for review."}
		case "approved":
			return LocalizedNotification{Title: "Application approved", Message: fmt.Sprintf("Your organizer application for %q has been approved. You can now create and manage events.", organizerName)}
		case "needs_revision":
			return LocalizedNotification{Title: "Organizer application needs changes", Message: fmt.Sprintf("Your organizer application for %q needs changes: %s", organizerName, reason)}
		case "rejected":
			return LocalizedNotification{Title: "Application update", Message: fmt.Sprintf("Your organizer application for %q requires attention: %s", organizerName, reason)}
		}
	}
	return LocalizedNotification{}
}

func renderEventStatus(status, eventTitle, reason, language string) LocalizedNotification {
	if eventTitle == "" {
		eventTitle = "your event"
	}
	switch language {
	case "ar":
		switch status {
		case "approved", "published":
			return LocalizedNotification{Title: "\u062a\u0645\u062a \u0627\u0644\u0645\u0648\u0627\u0641\u0642\u0629 \u0639\u0644\u0649 \u0627\u0644\u0641\u0639\u0627\u0644\u064a\u0629", Message: fmt.Sprintf("\u062a\u0645\u062a \u0627\u0644\u0645\u0648\u0627\u0641\u0642\u0629 \u0639\u0644\u0649 \u0641\u0639\u0627\u0644\u064a\u062a\u0643 %q \u0648\u0623\u0635\u0628\u062d\u062a \u0638\u0627\u0647\u0631\u0629 \u0644\u0644\u0645\u0633\u062a\u062e\u062f\u0645\u064a\u0646.", eventTitle)}
		case "rejected":
			return LocalizedNotification{Title: "\u062a\u062d\u062f\u064a\u062b \u0628\u0634\u0623\u0646 \u0627\u0644\u0641\u0639\u0627\u0644\u064a\u0629", Message: fmt.Sprintf("\u062a\u062d\u062a\u0627\u062c \u0641\u0639\u0627\u0644\u064a\u062a\u0643 %q \u0625\u0644\u0649 \u0627\u0646\u062a\u0628\u0627\u0647\u0643: %s", eventTitle, reason)}
		case "needs_revision":
			return LocalizedNotification{Title: "\u0637\u064f\u0644\u0628 \u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0641\u0639\u0627\u0644\u064a\u0629", Message: fmt.Sprintf("\u062a\u062d\u062a\u0627\u062c \u0641\u0639\u0627\u0644\u064a\u062a\u0643 %q \u0625\u0644\u0649 \u062a\u0639\u062f\u064a\u0644\u0627\u062a: %s", eventTitle, reason)}
		}
	case "tr":
		switch status {
		case "approved", "published":
			return LocalizedNotification{Title: "Etkinlik onayland\u0131", Message: fmt.Sprintf("%q etkinli\u011finiz onayland\u0131 ve art\u0131k kullan\u0131c\u0131lar taraf\u0131ndan g\u00f6r\u00fclebilir.", eventTitle)}
		case "rejected":
			return LocalizedNotification{Title: "Etkinlik g\u00fcncellendi", Message: fmt.Sprintf("%q etkinli\u011finizin ilgilenilmesi gerekiyor: %s", eventTitle, reason)}
		case "needs_revision":
			return LocalizedNotification{Title: "Etkinlik i\u00e7in d\u00fczeltme istendi", Message: fmt.Sprintf("%q etkinli\u011finizde d\u00fczeltmeler gerekiyor: %s", eventTitle, reason)}
		}
	default:
		switch status {
		case "approved", "published":
			return LocalizedNotification{Title: "Event approved", Message: fmt.Sprintf("Your event %q has been approved and is now visible to users.", eventTitle)}
		case "rejected":
			return LocalizedNotification{Title: "Event update", Message: fmt.Sprintf("Your event %q requires attention: %s", eventTitle, reason)}
		case "needs_revision":
			return LocalizedNotification{Title: "Event revision requested", Message: fmt.Sprintf("Your event %q needs revisions: %s", eventTitle, reason)}
		}
	}
	return LocalizedNotification{}
}

func renderAccountStatus(status, reason, language string) LocalizedNotification {
	switch status {
	case "suspended":
		switch language {
		case "ar":
			return LocalizedNotification{Title: "\u062a\u0645 \u062a\u0639\u0644\u064a\u0642 \u0627\u0644\u062d\u0633\u0627\u0628", Message: fmt.Sprintf("\u062a\u0645 \u062a\u0639\u0644\u064a\u0642 \u062d\u0633\u0627\u0628\u0643. \u0627\u0644\u0633\u0628\u0628: %s", reason)}
		case "tr":
			return LocalizedNotification{Title: "Hesap ask\u0131ya al\u0131nd\u0131", Message: fmt.Sprintf("Hesab\u0131n\u0131z ask\u0131ya al\u0131nd\u0131. Neden: %s", reason)}
		default:
			return LocalizedNotification{Title: "Account suspended", Message: fmt.Sprintf("Your account has been suspended. Reason: %s", reason)}
		}
	case "restored":
		switch language {
		case "ar":
			return LocalizedNotification{Title: "\u062a\u0645\u062a \u0627\u0633\u062a\u0639\u0627\u062f\u0629 \u0627\u0644\u062d\u0633\u0627\u0628", Message: "\u062a\u0645 \u0631\u0641\u0639 \u062a\u0639\u0644\u064a\u0642 \u062d\u0633\u0627\u0628\u0643. \u064a\u0645\u0643\u0646\u0643 \u0627\u0644\u0622\u0646 \u0627\u0644\u0648\u0635\u0648\u0644 \u0625\u0644\u0649 \u062c\u0645\u064a\u0639 \u0627\u0644\u0645\u064a\u0632\u0627\u062a."}
		case "tr":
			return LocalizedNotification{Title: "Hesap geri y\u00fcklendi", Message: "Hesap k\u0131s\u0131tlaman\u0131z kald\u0131r\u0131ld\u0131. Art\u0131k t\u00fcm \u00f6zelliklere eri\u015febilirsiniz."}
		default:
			return LocalizedNotification{Title: "Account restored", Message: "Your account suspension has been lifted. You can now access all features."}
		}
	}
	return LocalizedNotification{}
}

func localizedReminderLabel(label, language string) string {
	switch language {
	case "ar":
		switch label {
		case "24 hours":
			return "24 \u0633\u0627\u0639\u0629"
		case "2 hours":
			return "\u0633\u0627\u0639\u062a\u064a\u0646"
		}
	case "tr":
		switch label {
		case "24 hours":
			return "24 saat"
		case "2 hours":
			return "2 saat"
		}
	}
	return label
}
