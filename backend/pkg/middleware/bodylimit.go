package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/khair/backend/pkg/response"
)

const (
	// MaxBodySize is the maximum allowed request body size (8 MB).
	MaxBodySize = 8 << 20 // 8 * 1024 * 1024 = 8388608
)

// BodySizeLimit returns a middleware that rejects requests with bodies larger
// than the given limit. It sets http.MaxBytesReader on every incoming request
// so that the Gin JSON binder will return an error for oversized payloads.
func BodySizeLimit(maxBytes int64) gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Request.Body != nil {
			c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBytes)
		}
		c.Next()

		// If the reader hit the limit, Gin's ShouldBindJSON will have already
		// returned an error. However, if the handler read directly from body
		// and the limit was exceeded, the status might already be set. We
		// check for the sentinel error type after the handler chain.
		if c.IsAborted() {
			return
		}
		for _, err := range c.Errors {
			if err.Err != nil && err.Err.Error() == "http: request body too large" {
				c.AbortWithStatusJSON(http.StatusRequestEntityTooLarge, response.Response{
					Success: false,
					Error:   "request body too large",
				})
				return
			}
		}
	}
}
