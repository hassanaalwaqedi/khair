package observability

import (
	"fmt"
	"net/http"
	"runtime/debug"
	"time"

	"github.com/gin-gonic/gin"
)

// RequestTracingMiddleware adds request ID and tracing to all requests
func RequestTracingMiddleware() gin.HandlerFunc {
	logger := Default()

	return func(c *gin.Context) {
		start := time.Now()

		// Generate or extract request ID
		requestID := c.GetHeader("X-Request-ID")
		if requestID == "" {
			requestID = GenerateRequestID()
		}

		// Generate trace ID
		traceID := c.GetHeader("X-Trace-ID")
		if traceID == "" {
			traceID = fmt.Sprintf("%s-%d", requestID, time.Now().UnixNano())
		}

		// Add to context
		ctx := WithRequestID(c.Request.Context(), requestID)
		ctx = WithTraceID(ctx, traceID)
		c.Request = c.Request.WithContext(ctx)

		// Set response headers
		c.Header("X-Request-ID", requestID)
		c.Header("X-Trace-ID", traceID)

		// Store in gin context for easy access
		c.Set("request_id", requestID)
		c.Set("trace_id", traceID)

		// Process request
		c.Next()

		// Calculate duration
		duration := time.Since(start)

		// Record metrics
		GetMetrics().RecordRequest(c.Request.Method, c.FullPath(), c.Writer.Status(), duration)

		// Log request
		logFields := map[string]interface{}{
			"request_id":  requestID,
			"trace_id":    traceID,
			"method":      c.Request.Method,
			"path":        c.Request.URL.Path,
			"status_code": c.Writer.Status(),
			"duration_ms": float64(duration.Milliseconds()),
			"ip":          c.ClientIP(),
		}

		if userID, exists := c.Get("userID"); exists {
			logFields["user_id"] = fmt.Sprintf("%v", userID)
		}

		// Log based on status code
		if c.Writer.Status() >= 500 {
			logger.Error("Request completed with server error", logFields)
		} else if c.Writer.Status() >= 400 {
			logger.Warn("Request completed with client error", logFields)
		} else if duration > 500*time.Millisecond {
			logger.Warn("Slow request detected", logFields)
		} else {
			logger.Info("Request completed", logFields)
		}
	}
}

// PanicRecoveryMiddleware recovers from panics and logs them
func PanicRecoveryMiddleware() gin.HandlerFunc {
	logger := Default()

	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				// Get stack trace
				stack := string(debug.Stack())

				// Get request ID if available
				requestID := ""
				if id, exists := c.Get("request_id"); exists {
					requestID = id.(string)
				}

				logger.Error("Panic recovered", map[string]interface{}{
					"request_id": requestID,
					"error":      fmt.Sprintf("%v", err),
					"stack":      stack,
					"method":     c.Request.Method,
					"path":       c.Request.URL.Path,
					"ip":         c.ClientIP(),
				})

				// Return 500 error
				c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{
					"success":    false,
					"error":      "Internal server error",
					"request_id": requestID,
				})
			}
		}()

		c.Next()
	}
}

// SlowQueryLogger wraps database queries to detect slow queries
type SlowQueryLogger struct {
	threshold time.Duration
	logger    *Logger
}

// NewSlowQueryLogger creates a new slow query logger
func NewSlowQueryLogger(threshold time.Duration) *SlowQueryLogger {
	return &SlowQueryLogger{
		threshold: threshold,
		logger:    Default(),
	}
}

// LogQuery logs a query if it exceeds the threshold
func (sql *SlowQueryLogger) LogQuery(query string, args []interface{}, duration time.Duration) {
	GetMetrics().RecordDBQuery(duration)

	if duration > sql.threshold {
		sql.logger.Warn("Slow query detected", map[string]interface{}{
			"component":   "database",
			"duration_ms": float64(duration.Milliseconds()),
			"query":       truncateString(query, 500),
			"args_count":  len(args),
		})
	}
}

// MetricsHandler returns a handler for the /metrics endpoint
func MetricsHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		metrics := GetMetrics().ToPrometheus()
		c.Header("Content-Type", "text/plain; version=0.0.4")
		c.String(http.StatusOK, metrics)
	}
}

// HealthHandler returns a handler for the /health endpoint
func HealthHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":    "healthy",
			"timestamp": time.Now().UTC().Format(time.RFC3339),
			"version":   "1.0.0",
		})
	}
}

// ReadinessHandler returns a handler for the /ready endpoint
func ReadinessHandler(dbCheck func() bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		dbHealthy := true
		if dbCheck != nil {
			dbHealthy = dbCheck()
		}

		if dbHealthy {
			c.JSON(http.StatusOK, gin.H{
				"status": "ready",
				"checks": gin.H{
					"database": "healthy",
				},
			})
		} else {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"status": "not ready",
				"checks": gin.H{
					"database": "unhealthy",
				},
			})
		}
	}
}

func truncateString(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}
