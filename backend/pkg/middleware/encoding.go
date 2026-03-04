package middleware

import (
	"strings"

	"github.com/gin-gonic/gin"
)

// UTF8JSONMiddleware sets UTF-8 JSON content type by default for API responses.
// Handlers that return non-JSON content can override this header.
func UTF8JSONMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		path := c.Request.URL.Path
		if strings.HasPrefix(path, "/api/") || path == "/health" || path == "/healthz" || path == "/readyz" {
			c.Header("Content-Type", "application/json; charset=utf-8")
		}
		c.Next()
	}
}
