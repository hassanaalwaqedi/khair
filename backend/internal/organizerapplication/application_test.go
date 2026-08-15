package organizerapplication

import (
	"testing"
	"time"
)

func TestValidateSubmissionAcceptsCompleteVerifiedApplication(t *testing.T) {
	now := time.Now().UTC()
	app := &Application{
		OrganizerType:        "community",
		PublicName:           "Istanbul Muslim Community",
		RepresentativeName:   "Hassan Alwaqedi",
		ContactEmail:         "hassan@example.com",
		ContactEmailVerified: true,
		CountryCode:          "TR",
		City:                 "Istanbul",
		Description:          "A community that brings neighbours together through thoughtful learning and service events.",
		PublicLogoKey:        "organizers/applications/a/logo/logo.png",
		EventPlan:            "We plan friendly community workshops, learning gatherings, and family events with accurate event information.",
		EventCategories:      []string{"community", "education"},
		GuidelinesVersion:    GuidelinesVersion,
		GuidelinesAcceptedAt: &now,
	}
	if err := validateSubmission(app, identity{Email: "hassan@example.com", Verified: true}); err != nil {
		t.Fatalf("expected complete application to validate, got %v", err)
	}
}

func TestValidateSubmissionRejectsUnverifiedAlternateContact(t *testing.T) {
	now := time.Now().UTC()
	app := &Application{
		OrganizerType: "individual", PublicName: "Hassan Events", RepresentativeName: "Hassan Alwaqedi",
		ContactEmail: "other@example.com", ContactEmailVerified: false, CountryCode: "TR", City: "Istanbul",
		Description:     "I have experience organizing safe, welcoming learning and community gatherings for people in Istanbul.",
		PublicLogoKey:   "organizers/applications/a/logo/avatar.png",
		EventPlan:       "Attendees can expect carefully planned workshops and community events with clear times, venues, and audience details.",
		EventCategories: []string{"workshop"}, GuidelinesVersion: GuidelinesVersion, GuidelinesAcceptedAt: &now,
	}
	if err := validateSubmission(app, identity{Email: "hassan@example.com", Verified: true}); err == nil {
		t.Fatal("expected alternate unverified contact email to be rejected")
	}
}

func TestValidateSubmissionRequiresRepresentativePhotoForIndividual(t *testing.T) {
	now := time.Now().UTC()
	app := &Application{
		OrganizerType: "individual", PublicName: "Hassan Events", RepresentativeName: "Hassan Alwaqedi",
		ContactEmail: "hassan@example.com", ContactEmailVerified: true, CountryCode: "TR", City: "Istanbul",
		Description:     "I organize safe, welcoming learning and community gatherings for people in Istanbul and nearby communities.",
		PublicLogoKey:   "organizers/applications/a/logo/avatar.png",
		EventPlan:       "Attendees can expect carefully planned workshops and community events with clear times, venues, and audience details.",
		EventCategories: []string{"workshop"}, GuidelinesVersion: GuidelinesVersion, GuidelinesAcceptedAt: &now,
	}
	if err := validateSubmission(app, identity{Email: "hassan@example.com", Verified: true}); err == nil {
		t.Fatal("expected individual application without representative photo to be rejected")
	}
	app.RepresentativePhotoKey = "organizers/applications/a/profile/avatar.png"
	if err := validateSubmission(app, identity{Email: "hassan@example.com", Verified: true}); err != nil {
		t.Fatalf("expected complete individual application to validate, got %v", err)
	}
}

func TestValidateDraftRejectsUnsafeLinksAndCategories(t *testing.T) {
	if err := validateDraft(DraftInput{Links: []Link{{Platform: "website", URL: "javascript:alert(1)"}}}); err == nil {
		t.Fatal("expected unsafe URL to be rejected")
	}
	if err := validateDraft(DraftInput{EventCategories: []string{"made_up"}}); err == nil {
		t.Fatal("expected unknown category to be rejected")
	}
	if err := validateDraft(DraftInput{Links: []Link{{Platform: "website", URL: "http://example.test"}}}); err == nil {
		t.Fatal("expected insecure HTTP link to be rejected")
	}
}

func TestPrivateS3StoreNeverFallsBackWhenUnconfigured(t *testing.T) {
	store := &S3Store{}
	if err := store.Put(t.Context(), "organizers/applications/a/verification/file.pdf", []byte("pdf"), "application/pdf"); err == nil {
		t.Fatal("expected an explicit storage configuration error")
	}
}
