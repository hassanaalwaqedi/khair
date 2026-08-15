package sharing

import (
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/google/uuid"
)

func TestSocialPreviewPageIncludesShareMetadata(t *testing.T) {
	eventID := uuid.New()
	imageURL := "/api/v1/files/images/hackathon.png"
	service := &Service{frontendURL: "https://app.example"}
	page := service.socialPreviewPage(&EventShareData{
		EventID:     eventID,
		Title:       "AI Hackathon",
		Description: "Build useful things with your community.",
		ImageURL:    &imageURL,
		PublicURL:   "https://api.example/events/" + eventID.String(),
	})

	for _, expected := range []string{
		`property="og:title" content="AI Hackathon"`,
		`property="og:image" content="https://api.example/api/v1/files/images/hackathon.png"`,
		`name="twitter:card" content="summary_large_image"`,
		`rel="canonical" href="https://api.example/events/` + eventID.String() + `"`,
	} {
		if !strings.Contains(page, expected) {
			t.Fatalf("social preview is missing %q:\n%s", expected, page)
		}
	}
}

func TestPublicBaseURLUsesConfiguredOriginOrProxyHeaders(t *testing.T) {
	service := &Service{baseURL: "https://api.khair.example"}
	request := httptest.NewRequest("GET", "http://internal/events/test", nil)
	if got := service.publicBaseURL(request); got != "https://api.khair.example" {
		t.Fatalf("configured base URL = %q", got)
	}

	service.baseURL = ""
	request = httptest.NewRequest("GET", "http://internal/events/test", nil)
	request.Host = "localhost:8081"
	request.Header.Set("X-Forwarded-Proto", "https")
	if got := service.publicBaseURL(request); got != "https://localhost:8081" {
		t.Fatalf("proxied base URL = %q", got)
	}
}
