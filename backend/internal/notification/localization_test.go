package notification

import (
	"strings"
	"testing"
)

func TestRenderEventJoinIsSingleLanguageAndPreservesTitle(t *testing.T) {
	data := map[string]string{"event_title": "SQL & Victor Database"}
	tests := []struct {
		name       string
		language   string
		wantTitle  string
		wantPhrase string
		notWant    string
	}{
		{name: "english", language: "en", wantTitle: "You're registered 🎉", wantPhrase: "You've successfully joined", notWant: "\u062a\u0645 \u062a\u0623\u0643\u064a\u062f"},
		{name: "arabic", language: "ar", wantTitle: "\u062a\u0645 \u062a\u0623\u0643\u064a\u062f \u0627\u0646\u0636\u0645\u0627\u0645\u0643 \U0001f389", wantPhrase: "\u0627\u0646\u0636\u0645\u0645\u062a \u0628\u0646\u062c\u0627\u062d", notWant: "You've successfully joined"},
		{name: "turkish", language: "tr", wantTitle: "Kaydınız onaylandı 🎉", wantPhrase: "başarıyla katıldınız", notWant: "You've successfully joined"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			copy := Render("event_join_confirmed", data, tt.language)
			if copy.Title != tt.wantTitle {
				t.Fatalf("title = %q, want %q", copy.Title, tt.wantTitle)
			}
			if !strings.Contains(copy.Message, tt.wantPhrase) {
				t.Fatalf("message %q does not contain %q", copy.Message, tt.wantPhrase)
			}
			if strings.Contains(copy.Message, tt.notWant) || strings.Contains(copy.Title, tt.notWant) {
				t.Fatalf("copy unexpectedly contains another language: %q / %q", copy.Title, copy.Message)
			}
			if !strings.Contains(copy.Message, data["event_title"]) {
				t.Fatalf("event title was not preserved in %q", copy.Message)
			}
		})
	}
}

func TestRenderWelcomeUsesRecipientLanguage(t *testing.T) {
	data := map[string]string{"first_name": "Hassan", "role": "member"}

	if got := Render("welcome", data, "ar"); !strings.Contains(got.Message, "Hassan") || !strings.Contains(got.Message, "\u064a\u0633\u0639\u062f\u0646\u0627") {
		t.Fatalf("Arabic welcome was not localized: %+v", got)
	}
	if got := Render("welcome", data, "tr"); !strings.Contains(got.Message, "Hassan") || !strings.Contains(got.Message, "etkinlikleri") {
		t.Fatalf("Turkish welcome was not localized: %+v", got)
	}
}

func TestRenderAdditionalTransactionalTypes(t *testing.T) {
	for _, language := range []string{"en", "ar", "tr"} {
		for _, notificationType := range []string{"verification_review", "organizer_application", "event_status", "account_status", "support_reply"} {
			data := map[string]string{"status": "approved", "event_title": "Event", "organizer_name": "Org", "reason": "Please update"}
			if notificationType == "account_status" {
				data["status"] = "suspended"
			}
			if got := Render(notificationType, data, language); got.Title == "" || got.Message == "" {
				t.Fatalf("%s/%s returned empty copy: %+v", language, notificationType, got)
			}
		}
	}
}

func TestRenderExternalRegistrationReminderUsesRecipientLanguage(t *testing.T) {
	data := map[string]string{"event_title": "Community workshop"}
	for _, language := range []string{"en", "ar", "tr"} {
		got := Render("external_registration_required", data, language)
		if got.Title == "" || got.Message == "" || !strings.Contains(got.Message, data["event_title"]) {
			t.Fatalf("%s reminder was incomplete: %+v", language, got)
		}
	}
	if got := Render("external_registration_required", data, "ar"); strings.Contains(got.Message, "You joined") {
		t.Fatalf("Arabic reminder leaked English copy: %+v", got)
	}
}

func TestRenderNeverLeaksPrivateReviewNotes(t *testing.T) {
	privateNote := "internal reviewer note: private document URL"
	for _, notificationType := range []string{"verification_review", "organizer_application", "event_status"} {
		copy := Render(notificationType, map[string]string{
			"status":         "rejected",
			"event_title":    "Event",
			"organizer_name": "Org",
			"reason":         privateNote,
			"notes":          privateNote,
		}, "en")
		if strings.Contains(copy.Title, privateNote) || strings.Contains(copy.Message, privateNote) {
			t.Fatalf("%s leaked a private reviewer note: %+v", notificationType, copy)
		}
	}
}

func TestRenderUnknownTypeReturnsNoGeneratedCopy(t *testing.T) {
	got := Render("legacy_type", map[string]string{"event_title": "Untouched"}, "ar")
	if got.Title != "" || got.Message != "" {
		t.Fatalf("unknown type should not invent copy: %+v", got)
	}
}

func TestNormalizeLanguageAcceptsLocaleVariants(t *testing.T) {
	if NormalizeLanguage("ar-SA") != "ar" || NormalizeLanguage("tr_TR") != "tr" || NormalizeLanguage("fr-FR") != "en" {
		t.Fatal("locale variants were not normalized to a supported language")
	}
}
