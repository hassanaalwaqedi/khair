package email

import (
	"strings"
	"testing"
)

func TestTemplatesUseConfiguredApprovedBrandLogo(t *testing.T) {
	service := &Service{brandLogoURL: "https://api.example/brand/khair-logo.png"}

	for _, templateName := range []string{"verification", "notification"} {
		html, err := service.loadTemplate(templateName, "en", map[string]string{
			"{{BRAND_LOGO_URL}}": service.brandLogoURL,
			"{{CODE}}":           "123456",
			"{{TITLE}}":          "Welcome",
			"{{BODY}}":           "Your Khair update",
		})
		if err != nil {
			t.Fatalf("load %s template: %v", templateName, err)
		}
		if !strings.Contains(html, service.brandLogoURL) {
			t.Errorf("%s template did not use the configured brand logo URL", templateName)
		}
		if strings.Contains(html, "khair.blob.core.windows.net") {
			t.Errorf("%s template retained the legacy blob logo URL", templateName)
		}
	}
}
