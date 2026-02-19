package security

import (
	"github.com/gin-gonic/gin"
)

// HeadersMiddleware adds security headers to all responses
func HeadersMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Prevent MIME type sniffing
		c.Header("X-Content-Type-Options", "nosniff")

		// Prevent clickjacking
		c.Header("X-Frame-Options", "DENY")

		// Enable XSS filter
		c.Header("X-XSS-Protection", "1; mode=block")

		// Referrer policy
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")

		// Content Security Policy
		c.Header("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'")

		// Permissions Policy (formerly Feature-Policy)
		c.Header("Permissions-Policy", "geolocation=(self), microphone=(), camera=()")

		// HSTS - only if running over HTTPS
		// In production, this should be set by the reverse proxy
		// c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")

		c.Next()
	}
}

// CORSMiddleware handles CORS
func CORSMiddleware(allowedOrigins []string) gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")

		// Check if origin is allowed
		allowed := false
		for _, o := range allowedOrigins {
			if o == "*" || o == origin {
				allowed = true
				break
			}
		}

		if allowed {
			c.Header("Access-Control-Allow-Origin", origin)
			c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
			c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization, X-Request-ID, X-Country-Code, X-Invite-Code")
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

// RateLimitHeadersMiddleware adds rate limit headers
func RateLimitHeadersMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Headers are set by rate limit middleware
		// This is a placeholder for additional processing if needed
		c.Next()
	}
}

// SecureResponseMiddleware ensures secure responses
func SecureResponseMiddleware(isProduction bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()

		// Hide internal errors in production
		if isProduction && c.Writer.Status() >= 500 {
			// Check if response hasn't been written yet
			if !c.Writer.Written() {
				c.JSON(500, gin.H{
					"success": false,
					"error":   "Internal server error",
					"code":    "INTERNAL_ERROR",
				})
			}
		}
	}
}
