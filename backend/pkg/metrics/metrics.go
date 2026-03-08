package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

// ── HTTP metrics ──

// HTTPRequestsTotal counts HTTP requests by method, path, and status.
var HTTPRequestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
	Namespace: "khair",
	Name:      "http_requests_total",
	Help:      "Total HTTP requests processed",
}, []string{"method", "path", "status"})

// HTTPRequestDuration records request latency by method and path.
var HTTPRequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
	Namespace: "khair",
	Name:      "http_request_duration_seconds",
	Help:      "HTTP request duration in seconds",
	Buckets:   prometheus.DefBuckets,
}, []string{"method", "path"})

// ── WebSocket metrics ──

// WSConnectionsActive tracks the number of active WebSocket connections.
var WSConnectionsActive = promauto.NewGauge(prometheus.GaugeOpts{
	Namespace: "khair",
	Name:      "ws_connections_active",
	Help:      "Number of active WebSocket connections",
})

// ── Database metrics ──

// DBQueryDuration records database query latency by operation.
var DBQueryDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
	Namespace: "khair",
	Name:      "db_query_duration_seconds",
	Help:      "Database query duration in seconds",
	Buckets:   []float64{0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5},
}, []string{"operation"})

// ── Redis metrics ──

// RedisOpsTotal counts Redis operations by command.
var RedisOpsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
	Namespace: "khair",
	Name:      "redis_ops_total",
	Help:      "Total Redis operations",
}, []string{"command"})

// ── Job queue metrics ──

// JobsProcessedTotal counts background jobs processed by type and result.
var JobsProcessedTotal = promauto.NewCounterVec(prometheus.CounterOpts{
	Namespace: "khair",
	Name:      "jobs_processed_total",
	Help:      "Total background jobs processed",
}, []string{"type", "result"})
