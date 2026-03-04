package security

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"io"
	"net/url"
	"regexp"
	"strings"
)

var (
	scriptPattern     = regexp.MustCompile(`(?i)<\s*script[^>]*>.*?<\s*/\s*script\s*>`)
	eventAttrPattern  = regexp.MustCompile(`(?i)\s+on\w+\s*=\s*["'][^"']*["']`)
	htmlTagPattern    = regexp.MustCompile(`<[^>]*>`)
	sqlPattern        = regexp.MustCompile(`(?i)(;\s*(DROP|DELETE|UPDATE|INSERT|ALTER|CREATE|EXEC|UNION)\b|--\s|/\*)`)
	dangerousURLParts = []string{
		"javascript:", "data:", "vbscript:",
	}
)

func SanitizeHTML(input string) string {
	result := scriptPattern.ReplaceAllString(input, "")
	result = eventAttrPattern.ReplaceAllString(result, "")
	result = htmlTagPattern.ReplaceAllString(result, "")
	return strings.TrimSpace(result)
}

func StripScripts(input string) string {
	return scriptPattern.ReplaceAllString(input, "")
}

func ValidateURL(rawURL string) bool {
	if rawURL == "" {
		return true
	}

	lower := strings.ToLower(rawURL)
	for _, dangerous := range dangerousURLParts {
		if strings.Contains(lower, dangerous) {
			return false
		}
	}

	parsed, err := url.Parse(rawURL)
	if err != nil {
		return false
	}

	if parsed.Scheme != "" && parsed.Scheme != "http" && parsed.Scheme != "https" {
		return false
	}

	return parsed.Host != ""
}

func PreventSQLInjection(input string) string {
	return sqlPattern.ReplaceAllString(input, "")
}

func SanitizeInput(input string) string {
	result := SanitizeHTML(input)
	result = PreventSQLInjection(result)
	return result
}

func EncryptMeetingLink(link string, key []byte) (string, error) {
	if link == "" {
		return "", nil
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonce := make([]byte, aesGCM.NonceSize())
	if _, err = io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}

	ciphertext := aesGCM.Seal(nonce, nonce, []byte(link), nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

func DecryptMeetingLink(encrypted string, key []byte) (string, error) {
	if encrypted == "" {
		return "", nil
	}

	ciphertext, err := base64.StdEncoding.DecodeString(encrypted)
	if err != nil {
		return "", err
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonceSize := aesGCM.NonceSize()
	if len(ciphertext) < nonceSize {
		return "", err
	}

	nonce, ciphertext := ciphertext[:nonceSize], ciphertext[nonceSize:]
	plaintext, err := aesGCM.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", err
	}

	return string(plaintext), nil
}
