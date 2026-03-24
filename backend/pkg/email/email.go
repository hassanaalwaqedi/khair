package email

import (
	"bytes"
	"embed"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"

	"github.com/khair/backend/pkg/config"
)

//go:embed templates/*.html
var templateFS embed.FS

// Service handles email delivery via SendGrid.
type Service struct {
	apiKey string
	from   string
}

// NewService creates an email service using SendGrid.
// Returns a disabled service if no API key is configured.
func NewService(cfg config.EmailConfig) *Service {
	if cfg.SendGridKey == "" {
		log.Println("[WARN] Email provider: disabled (no SENDGRID_API_KEY)")
		return &Service{}
	}

	from := cfg.SendGridFrom
	if from == "" {
		from = "no-reply@khair.it.com"
	}

	log.Println("[INFO] Email provider: SendGrid")
	return &Service{
		apiKey: cfg.SendGridKey,
		from:   from,
	}
}

// IsEnabled returns true if SendGrid is configured.
func (s *Service) IsEnabled() bool {
	return s.apiKey != ""
}

// supportedLanguage normalises and validates the language code.
func supportedLanguage(lang string) string {
	lang = strings.ToLower(strings.TrimSpace(lang))
	switch lang {
	case "ar", "tr":
		return lang
	default:
		return "en"
	}
}

// ── Public Email Methods ─────────────────────────────────────────────────────

// SendVerificationEmail sends a branded verification code email in the given language.
func (s *Service) SendVerificationEmail(email, code, language string) error {
	if !s.IsEnabled() {
		log.Printf("[WARN] Email disabled — OTP for %s would be: %s", email, code)
		return fmt.Errorf("email service is not configured")
	}

	lang := supportedLanguage(language)

	subjects := map[string]string{
		"en": "Khair — Your Verification Code",
		"ar": "خير — رمز التحقق الخاص بك",
		"tr": "Khair — Doğrulama Kodunuz",
	}

	data := map[string]string{
		"{{CODE}}": code,
	}

	body, err := s.loadTemplate("verification", lang, data)
	if err != nil {
		return fmt.Errorf("load verification template: %w", err)
	}

	return s.sendEmail(email, subjects[lang], body)
}

// SendNotificationEmail sends a generic branded notification email.
func (s *Service) SendNotificationEmail(email, title, body, language string) error {
	if !s.IsEnabled() {
		log.Printf("[WARN] Email disabled — notification for %s: %s", email, title)
		return fmt.Errorf("email service is not configured")
	}

	lang := supportedLanguage(language)

	data := map[string]string{
		"{{TITLE}}": title,
		"{{BODY}}":  body,
	}

	htmlBody, err := s.loadTemplate("notification", lang, data)
	if err != nil {
		return fmt.Errorf("load notification template: %w", err)
	}

	return s.sendEmail(email, title, htmlBody)
}

// ── Template Loading ─────────────────────────────────────────────────────────

func (s *Service) loadTemplate(name, lang string, data map[string]string) (string, error) {
	filename := fmt.Sprintf("templates/%s_%s.html", name, lang)
	content, err := templateFS.ReadFile(filename)
	if err != nil {
		// Fallback to English
		filename = fmt.Sprintf("templates/%s_en.html", name)
		content, err = templateFS.ReadFile(filename)
		if err != nil {
			return "", fmt.Errorf("template %s not found: %w", filename, err)
		}
	}

	result := string(content)
	for placeholder, value := range data {
		result = strings.ReplaceAll(result, placeholder, value)
	}
	return result, nil
}

// ── SendGrid API ─────────────────────────────────────────────────────────────

func (s *Service) sendEmail(to, subject, htmlBody string) error {
	payload := map[string]interface{}{
		"personalizations": []map[string]interface{}{
			{
				"to":      []map[string]string{{"email": to}},
				"subject": subject,
			},
		},
		"from": map[string]string{
			"email": s.from,
			"name":  "Khair",
		},
		"content": []map[string]string{
			{
				"type":  "text/html",
				"value": htmlBody,
			},
		},
	}

	jsonPayload, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal SendGrid payload: %w", err)
	}

	req, err := http.NewRequest(http.MethodPost, "https://api.sendgrid.com/v3/mail/send", bytes.NewBuffer(jsonPayload))
	if err != nil {
		return fmt.Errorf("create SendGrid request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+s.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Printf("[ERROR] SendGrid request failed: %v", err)
		return fmt.Errorf("SendGrid request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= http.StatusBadRequest {
		respBody, _ := io.ReadAll(resp.Body)
		log.Printf("[ERROR] SendGrid status %d: %s", resp.StatusCode, string(respBody))
		return fmt.Errorf("SendGrid returned status %d: %s", resp.StatusCode, string(respBody))
	}

	log.Printf("[INFO] Email sent to %s (subject: %s, status: %d)", to, subject, resp.StatusCode)
	return nil
}
