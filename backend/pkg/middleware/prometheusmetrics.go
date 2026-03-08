package middleware

import (
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/khair/backend/pkg/metrics"
)

// PrometheusMetrics records HTTP request count and latency for every request.
func PrometheusMetrics() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()

		c.Next()

		duration := time.Since(start).Seconds()
		status := strconv.Itoa(c.Writer.Status())
		path := c.FullPath()
		if path == "" {
			path = "unknown"
		}
		method := c.Request.Method

		metrics.HTTPRequestsTotal.WithLabelValues(method, path, status).Inc()
		metrics.HTTPRequestDuration.WithLabelValues(method, path).Observe(duration)
	}
}
