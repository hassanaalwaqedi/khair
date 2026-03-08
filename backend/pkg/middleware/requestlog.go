package middleware

import (
	"log"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// RequestLogger returns a structured-logging middleware that attaches a unique
// request ID, records the authenticated user ID (if present), the HTTP method,
// path, latency, and response status for every request.
func RequestLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Generate a unique request ID
		requestID := uuid.New().String()
		c.Set("request_id", requestID)
		c.Header("X-Request-ID", requestID)

		start := time.Now()

		// Process request
		c.Next()

		// --- Post-request structured log ---
		latency := time.Since(start)
		status := c.Writer.Status()
		method := c.Request.Method
		path := c.Request.URL.Path

		// Extract user ID if authenticated
		userID := ""
		if uid, exists := c.Get("user_id"); exists {
			if id, ok := uid.(uuid.UUID); ok {
				userID = id.String()
			}
		}

		// Collect error messages from the handler chain
		errMsg := ""
		if len(c.Errors) > 0 {
			errMsg = c.Errors.String()
		}

		// Structured log entry
		if errMsg != "" {
			log.Printf("[ERROR] request_id=%s user_id=%s method=%s path=%s status=%d latency=%s error=%q",
				requestID, userID, method, path, status, latency, errMsg)
		} else if status >= 400 {
			log.Printf("[WARN]  request_id=%s user_id=%s method=%s path=%s status=%d latency=%s",
				requestID, userID, method, path, status, latency)
		} else {
			log.Printf("[INFO]  request_id=%s user_id=%s method=%s path=%s status=%d latency=%s",
				requestID, userID, method, path, status, latency)
		}
	}
}
