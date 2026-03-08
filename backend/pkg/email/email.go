package email

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/smtp"
	"strconv"

	"github.com/khair/backend/pkg/config"
)

// EmailSender abstracts the email delivery mechanism.
type EmailSender interface {
	SendOTP(email string, otp string) error
	IsEnabled() bool
}

// Service wraps an EmailSender to maintain backward compatibility.
type Service struct {
	sender EmailSender
}

// NewService creates an email service using the configured provider.
// If SENDGRID_API_KEY is set, SendGrid is used; otherwise SMTP is used.
func NewService(cfg config.SMTPConfig) *Service {
	var sender EmailSender

	switch {
	case cfg.Host != "" && cfg.User != "":
		sender = &SMTPSender{cfg: cfg}
		log.Println("[INFO] Email provider: SMTP")
	case cfg.SendGridKey != "":
		sender = &SendGridSender{apiKey: cfg.SendGridKey, from: cfg.SendGridFrom}
		log.Println("[INFO] Email provider: SendGrid")
	default:
		sender = &NoOpSender{}
		log.Println("[WARN] Email provider: disabled (no SMTP or SendGrid configured)")
	}

	return &Service{sender: sender}
}

// IsEnabled returns true if the underlying sender is configured.
func (s *Service) IsEnabled() bool {
	return s.sender.IsEnabled()
}

// SendVerificationEmail sends a 6-digit OTP code via the configured provider.
func (s *Service) SendVerificationEmail(email string, code string) error {
	return s.sender.SendOTP(email, code)
}

func buildOTPEmail(code string) string {
	return fmt.Sprintf(`<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="text-align: center; padding: 20px; background: linear-gradient(135deg, #0d9488, #065f46); border-radius: 12px; margin-bottom: 24px;">
    <h1 style="color: #fff; margin: 0; font-size: 28px;">Khair</h1>
    <p style="color: #d1fae5; margin: 8px 0 0;">Email Verification | التحقق من البريد الإلكتروني</p>
  </div>

  <div style="padding: 24px; background: #f8fafc; border-radius: 12px;">
    <div style="text-align: center;">
      <p style="color: #374151; font-size: 16px; margin-bottom: 8px;">Assalamu Alaikum! Your verification code is:</p>
      <div style="font-size: 36px; font-weight: bold; letter-spacing: 8px; color: #0d9488; padding: 16px; background: #fff; border-radius: 8px; display: inline-block; border: 2px dashed #0d9488;">%s</div>
      <p style="color: #6b7280; font-size: 14px; margin-top: 16px;">This code will expire in <strong>10 minutes</strong>.</p>
      <p style="color: #ef4444; font-size: 13px; margin-top: 12px;">Never share this code with anyone. Khair staff will never ask for it.</p>
      <p style="color: #6b7280; font-size: 13px;">If you did not request this, please ignore this email.</p>
    </div>

    <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 18px 0;">

    <div dir="rtl" style="text-align: center;">
      <p style="color: #374151; font-size: 16px; margin-bottom: 8px;">رمز التحقق الخاص بك هو:</p>
      <div style="font-size: 36px; font-weight: bold; letter-spacing: 8px; color: #0d9488; padding: 16px; background: #fff; border-radius: 8px; display: inline-block; border: 2px dashed #0d9488;">%s</div>
      <p style="color: #6b7280; font-size: 14px; margin-top: 16px;">ينتهي هذا الرمز خلال <strong>10 دقائق</strong>.</p>
      <p style="color: #ef4444; font-size: 13px; margin-top: 12px;">لا تشارك هذا الرمز مع أي شخص. فريق خير لن يطلبه منك.</p>
      <p style="color: #6b7280; font-size: 13px;">إذا لم تطلب هذا الرمز، يمكنك تجاهل هذه الرسالة.</p>
    </div>
  </div>

  <p style="text-align: center; color: #9ca3af; font-size: 12px; margin-top: 24px;">&copy; Khair Platform</p>
</body>
</html>`, code, code)
}

// SMTPSender sends emails via SMTP.
type SMTPSender struct {
	cfg config.SMTPConfig
}

func (s *SMTPSender) IsEnabled() bool {
	return s.cfg.Host != "" && s.cfg.User != ""
}

func (s *SMTPSender) SendOTP(email string, otp string) error {
	subject := "Khair - Email Verification Code"
	body := buildOTPEmail(otp)

	from := s.cfg.From
	if from == "" {
		from = s.cfg.User
	}

	mime := "MIME-Version: 1.0\r\nContent-Type: text/html; charset=\"utf-8\"\r\n"
	msg := fmt.Sprintf("From: %s\r\nTo: %s\r\nSubject: %s\r\n%s\r\n%s", from, email, subject, mime, body)

	addr := s.cfg.Host + ":" + strconv.Itoa(s.cfg.Port)
	auth := smtp.PlainAuth("", s.cfg.User, s.cfg.Pass, s.cfg.Host)

	return smtp.SendMail(addr, auth, from, []string{email}, []byte(msg))
}

// SendGridSender sends emails via SendGrid API.
type SendGridSender struct {
	apiKey string
	from   string
}

func (s *SendGridSender) IsEnabled() bool {
	return s.apiKey != ""
}

func (s *SendGridSender) SendOTP(email string, otp string) error {
	body := buildOTPEmail(otp)

	from := s.from
	if from == "" {
		return fmt.Errorf("SENDGRID sender email (SMTP_FROM) is required")
	}

	payload := map[string]interface{}{
		"personalizations": []map[string]interface{}{
			{
				"to": []map[string]string{
					{"email": email},
				},
				"subject": "Khair - Email Verification Code",
			},
		},
		"from": map[string]string{
			"email": from,
			"name":  "Khair Platform",
		},
		"content": []map[string]string{
			{
				"type":  "text/html",
				"value": body,
			},
		},
	}

	jsonPayload, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal SendGrid payload: %w", err)
	}

	req, err := http.NewRequest(http.MethodPost, "https://api.sendgrid.com/v3/mail/send", bytes.NewBuffer(jsonPayload))
	if err != nil {
		return fmt.Errorf("failed to create SendGrid request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+s.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("SendGrid request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= http.StatusBadRequest {
		body, _ := io.ReadAll(resp.Body)
		log.Printf("[ERROR] SendGrid status %d: %s", resp.StatusCode, string(body))
		return fmt.Errorf("SendGrid returned status %d: %s", resp.StatusCode, string(body))
	}

	return nil
}

// NoOpSender is used when no email provider is configured.
type NoOpSender struct{}

func (n *NoOpSender) IsEnabled() bool { return false }

func (n *NoOpSender) SendOTP(email string, otp string) error {
	log.Printf("[WARN] Email disabled - OTP for %s would be: %s", email, otp)
	return fmt.Errorf("email service is not configured")
}
