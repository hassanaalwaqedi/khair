package middleware

import (
	"github.com/gin-gonic/gin"
)

// SecurityHeaders returns a middleware that sets security-related HTTP headers
func SecurityHeaders() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Content Security Policy - restrict resource loading to prevent XSS
		// Adjust directives based on your actual resource needs
		c.Header("Content-Security-Policy",
			"default-src 'self'; "+
				"script-src 'self' 'unsafe-inline'; "+
				"style-src 'self' 'unsafe-inline'; "+
				"img-src 'self' data: https:; "+
				"font-src 'self' data:; "+
				"connect-src 'self'")

		// Strict-Transport-Security - force HTTPS (only add if running over HTTPS)
		// Uncomment in production with HTTPS:
		// c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")

		// X-Frame-Options - prevent clickjacking
		c.Header("X-Frame-Options", "DENY")

		// X-Content-Type-Options - prevent MIME sniffing
		c.Header("X-Content-Type-Options", "nosniff")

		// X-XSS-Protection - enable browser XSS protection (legacy but good practice)
		c.Header("X-XSS-Protection", "1; mode=block")

		// Referrer-Policy - control referrer information
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")

		// Permissions-Policy - restrict browser features
		c.Header("Permissions-Policy", "geolocation=(), microphone=(), camera=()")

		c.Next()
	}
}
