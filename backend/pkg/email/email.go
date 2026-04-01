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

// Service handles email delivery via Resend or SendGrid.
type Service struct {
	provider  string // "resend" or "sendgrid"
	apiKey    string
	fromEmail string
	fromName  string
}

// NewService creates an email service using the configured provider.
// Returns a disabled service if no API key is configured.
func NewService(cfg config.EmailConfig) *Service {
	switch cfg.Provider {
	case "resend":
		if cfg.ResendKey == "" {
			log.Println("[WARN] Email provider: disabled (no RESEND_API_KEY)")
			return &Service{}
		}
		log.Printf("[INFO] Email provider: Resend (from: %s)", cfg.FromEmail)
		return &Service{
			provider:  "resend",
			apiKey:    cfg.ResendKey,
			fromEmail: cfg.FromEmail,
			fromName:  cfg.FromName,
		}

	default: // "sendgrid"
		if cfg.SendGridKey == "" {
			log.Println("[WARN] Email provider: disabled (no SENDGRID_API_KEY)")
			return &Service{}
		}
		from := cfg.SendGridFrom
		if from == "" {
			from = cfg.FromEmail
		}
		log.Printf("[INFO] Email provider: SendGrid (from: %s)", from)
		return &Service{
			provider:  "sendgrid",
			apiKey:    cfg.SendGridKey,
			fromEmail: from,
			fromName:  cfg.FromName,
		}
	}
}

// IsEnabled returns true if an email provider is configured.
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

// ── Email Dispatch ───────────────────────────────────────────────────────────

func (s *Service) sendEmail(to, subject, htmlBody string) error {
	plainText := stripHTML(htmlBody)

	switch s.provider {
	case "resend":
		return s.sendViaResend(to, subject, htmlBody, plainText)
	default:
		return s.sendViaSendGrid(to, subject, htmlBody, plainText)
	}
}

// ── Resend API ───────────────────────────────────────────────────────────────

func (s *Service) sendViaResend(to, subject, htmlBody, plainText string) error {
	from := fmt.Sprintf("%s <%s>", s.fromName, s.fromEmail)

	payload := map[string]interface{}{
		"from":    from,
		"to":      []string{to},
		"subject": subject,
		"html":    htmlBody,
		"text":    plainText,
	}

	jsonPayload, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal Resend payload: %w", err)
	}

	req, err := http.NewRequest(http.MethodPost, "https://api.resend.com/emails", bytes.NewBuffer(jsonPayload))
	if err != nil {
		return fmt.Errorf("create Resend request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+s.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Printf("[ERROR] Resend request failed: %v", err)
		return fmt.Errorf("Resend request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode >= http.StatusBadRequest {
		log.Printf("[ERROR] Resend status %d to %s: %s", resp.StatusCode, to, string(respBody))
		return fmt.Errorf("Resend returned status %d: %s", resp.StatusCode, string(respBody))
	}

	log.Printf("[INFO] Email sent via Resend to %s (subject: %s, status: %d)", to, subject, resp.StatusCode)
	return nil
}

// ── SendGrid API (fallback) ──────────────────────────────────────────────────

func (s *Service) sendViaSendGrid(to, subject, htmlBody, plainText string) error {
	payload := map[string]interface{}{
		"personalizations": []map[string]interface{}{
			{
				"to":      []map[string]string{{"email": to}},
				"subject": subject,
			},
		},
		"from": map[string]string{
			"email": s.fromEmail,
			"name":  s.fromName,
		},
		"reply_to": map[string]string{
			"email": s.fromEmail,
			"name":  s.fromName,
		},
		"content": []map[string]string{
			{
				"type":  "text/plain",
				"value": plainText,
			},
			{
				"type":  "text/html",
				"value": htmlBody,
			},
		},
		"categories": []string{"verification"},
		"tracking_settings": map[string]interface{}{
			"click_tracking": map[string]bool{
				"enable": false,
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

	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode >= http.StatusBadRequest {
		log.Printf("[ERROR] SendGrid status %d to %s: %s", resp.StatusCode, to, string(respBody))
		return fmt.Errorf("SendGrid returned status %d: %s", resp.StatusCode, string(respBody))
	}

	log.Printf("[INFO] Email sent via SendGrid to %s (subject: %s, status: %d)", to, subject, resp.StatusCode)
	return nil
}

// ── Helpers ──────────────────────────────────────────────────────────────────

// stripHTML removes HTML tags to produce a plain-text version for email.
func stripHTML(html string) string {
	var result strings.Builder
	inTag := false
	for _, r := range html {
		switch {
		case r == '<':
			inTag = true
		case r == '>':
			inTag = false
		case !inTag:
			result.WriteRune(r)
		}
	}
	text := result.String()
	lines := strings.Split(text, "\n")
	var cleaned []string
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed != "" {
			cleaned = append(cleaned, trimmed)
		}
	}
	return strings.Join(cleaned, "\n")
}
