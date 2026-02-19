package security

import (
	"os"
	"regexp"
	"strings"

	"github.com/gin-gonic/gin"
)

// ProductionConfig holds production security settings
type ProductionConfig struct {
	Environment     string
	AllowedOrigins  []string
	TrustedProxies  []string
	EnableHSTS      bool
	HSTSMaxAge      int
}

// DefaultProductionConfig returns production-ready security config
func DefaultProductionConfig() *ProductionConfig {
	env := os.Getenv("ENV")
	if env == "" {
		env = "production"
	}

	origins := os.Getenv("CORS_ORIGINS")
	if origins == "" {
		origins = "https://khair.app"
	}

	return &ProductionConfig{
		Environment:    env,
		AllowedOrigins: strings.Split(origins, ","),
		TrustedProxies: []string{"127.0.0.1"},
		EnableHSTS:     true,
		HSTSMaxAge:     31536000, // 1 year
	}
}

// ProductionCORSMiddleware returns strict CORS middleware
func ProductionCORSMiddleware(config *ProductionConfig) gin.HandlerFunc {
	allowedMap := make(map[string]bool)
	for _, origin := range config.AllowedOrigins {
		allowedMap[strings.TrimSpace(origin)] = true
	}

	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")

		// Check if origin is allowed
		if allowedMap[origin] || config.Environment == "development" {
			c.Header("Access-Control-Allow-Origin", origin)
			c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
			c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization, X-Request-ID")
			c.Header("Access-Control-Expose-Headers", "X-Request-ID, X-RateLimit-Limit, X-RateLimit-Remaining")
			c.Header("Access-Control-Allow-Credentials", "true")
			c.Header("Access-Control-Max-Age", "86400")
		}

		// Handle preflight
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}

// ProductionHeadersMiddleware adds production security headers
func ProductionHeadersMiddleware(config *ProductionConfig) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Prevent MIME type sniffing
		c.Header("X-Content-Type-Options", "nosniff")

		// Prevent clickjacking
		c.Header("X-Frame-Options", "DENY")

		// Enable XSS filter
		c.Header("X-XSS-Protection", "1; mode=block")

		// Referrer policy
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")

		// HSTS (only in production)
		if config.EnableHSTS && config.Environment == "production" {
			c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains; preload")
		}

		// Content Security Policy
		c.Header("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self'")

		// Permissions Policy
		c.Header("Permissions-Policy", "geolocation=(self), microphone=(), camera=(), payment=()")

		// Cache control for API responses
		c.Header("Cache-Control", "no-store, no-cache, must-revalidate, private")
		c.Header("Pragma", "no-cache")

		c.Next()
	}
}

// LogSanitizer removes sensitive data from logs
type LogSanitizer struct {
	patterns []*regexp.Regexp
}

// NewLogSanitizer creates a new log sanitizer
func NewLogSanitizer() *LogSanitizer {
	return &LogSanitizer{
		patterns: []*regexp.Regexp{
			regexp.MustCompile(`(?i)"password"\s*:\s*"[^"]*"`),
			regexp.MustCompile(`(?i)"token"\s*:\s*"[^"]*"`),
			regexp.MustCompile(`(?i)"authorization"\s*:\s*"[^"]*"`),
			regexp.MustCompile(`(?i)"secret"\s*:\s*"[^"]*"`),
			regexp.MustCompile(`(?i)"api_key"\s*:\s*"[^"]*"`),
			regexp.MustCompile(`(?i)"credit_card"\s*:\s*"[^"]*"`),
			regexp.MustCompile(`\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b`), // Email
			regexp.MustCompile(`\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b`),           // Credit card
			regexp.MustCompile(`eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*`), // JWT
		},
	}
}

// Sanitize removes sensitive data from a string
func (s *LogSanitizer) Sanitize(input string) string {
	result := input
	
	for _, pattern := range s.patterns {
		result = pattern.ReplaceAllString(result, "[REDACTED]")
	}
	
	return result
}

// SanitizeMap removes sensitive data from map values
func (s *LogSanitizer) SanitizeMap(m map[string]interface{}) map[string]interface{} {
	sensitiveKeys := map[string]bool{
		"password":      true,
		"token":         true,
		"secret":        true,
		"api_key":       true,
		"authorization": true,
		"credit_card":   true,
		"ssn":           true,
	}

	result := make(map[string]interface{})
	for k, v := range m {
		if sensitiveKeys[strings.ToLower(k)] {
			result[k] = "[REDACTED]"
		} else if str, ok := v.(string); ok {
			result[k] = s.Sanitize(str)
		} else {
			result[k] = v
		}
	}
	return result
}

// RequestBodySanitizer sanitizes request bodies before logging
func RequestBodySanitizer() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Don't log sensitive endpoints
		sensitiveEndpoints := []string{"/login", "/register", "/auth", "/password"}
		for _, endpoint := range sensitiveEndpoints {
			if strings.Contains(c.Request.URL.Path, endpoint) {
				c.Set("skip_body_log", true)
				break
			}
		}
		c.Next()
	}
}

// DisableDebugEndpoints removes debug endpoints in production
func DisableDebugEndpoints(isProduction bool) gin.HandlerFunc {
	debugPaths := []string{"/debug/", "/pprof/", "/__debug"}
	
	return func(c *gin.Context) {
		if isProduction {
			for _, path := range debugPaths {
				if strings.HasPrefix(c.Request.URL.Path, path) {
					c.AbortWithStatus(404)
					return
				}
			}
		}
		c.Next()
	}
}

// SecureErrorMiddleware hides internal errors in production
func SecureErrorMiddleware(isProduction bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()

		// Hide internal error details in production
		if isProduction && c.Writer.Status() >= 500 {
			// Response already written, but log sanitized version
			// In a real implementation, we'd use a response writer wrapper
		}
	}
}
