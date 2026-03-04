package observability

import (
	"sync"
	"time"
)

// Metrics provides application metrics collection
type Metrics struct {
	mu sync.RWMutex

	// Request metrics
	requestCount    map[string]int64
	requestDuration map[string]*HistogramData
	errorCount      map[string]int64

	// Database metrics
	dbConnections      int64
	dbConnectionsMax   int64
	dbQueryDuration    *HistogramData
	slowQueryCount     int64
	slowQueryThreshold time.Duration

	// Cache metrics
	cacheHits   int64
	cacheMisses int64

	// Custom gauges
	gauges map[string]float64
}

// HistogramData stores histogram bucket data
type HistogramData struct {
	Count   int64
	Sum     float64
	Buckets map[float64]int64 // bucket upper bound -> count
}

// NewHistogram creates a new histogram with default buckets
func NewHistogram() *HistogramData {
	return &HistogramData{
		Buckets: map[float64]int64{
			0.005: 0, // 5ms
			0.01:  0, // 10ms
			0.025: 0, // 25ms
			0.05:  0, // 50ms
			0.1:   0, // 100ms
			0.25:  0, // 250ms
			0.5:   0, // 500ms
			1:     0, // 1s
			2.5:   0, // 2.5s
			5:     0, // 5s
			10:    0, // 10s
		},
	}
}

// Observe records a value in the histogram
func (h *HistogramData) Observe(value float64) {
	h.Count++
	h.Sum += value

	for bucket := range h.Buckets {
		if value <= bucket {
			h.Buckets[bucket]++
		}
	}
}

var (
	globalMetrics *Metrics
	metricsOnce   sync.Once
)

// GetMetrics returns the global metrics instance
func GetMetrics() *Metrics {
	metricsOnce.Do(func() {
		globalMetrics = &Metrics{
			requestCount:       make(map[string]int64),
			requestDuration:    make(map[string]*HistogramData),
			errorCount:         make(map[string]int64),
			dbQueryDuration:    NewHistogram(),
			slowQueryThreshold: 100 * time.Millisecond,
			gauges:             make(map[string]float64),
		}
	})
	return globalMetrics
}

// RecordRequest records a request metric
func (m *Metrics) RecordRequest(method, path string, statusCode int, duration time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()

	key := method + " " + path
	m.requestCount[key]++

	if _, ok := m.requestDuration[key]; !ok {
		m.requestDuration[key] = NewHistogram()
	}
	m.requestDuration[key].Observe(duration.Seconds())

	if statusCode >= 400 {
		errorKey := key + " " + string(rune(statusCode/100)) + "xx"
		m.errorCount[errorKey]++
	}
}

// RecordDBQuery records a database query metric
func (m *Metrics) RecordDBQuery(duration time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.dbQueryDuration.Observe(duration.Seconds())

	if duration > m.slowQueryThreshold {
		m.slowQueryCount++
	}
}

// SetDBConnections sets the current DB connection count
func (m *Metrics) SetDBConnections(current, max int64) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.dbConnections = current
	m.dbConnectionsMax = max
}

// RecordCacheHit records a cache hit
func (m *Metrics) RecordCacheHit() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.cacheHits++
}

// RecordCacheMiss records a cache miss
func (m *Metrics) RecordCacheMiss() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.cacheMisses++
}

// SetGauge sets a gauge value
func (m *Metrics) SetGauge(name string, value float64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.gauges[name] = value
}

// IncrementGauge increments a gauge value
func (m *Metrics) IncrementGauge(name string, delta float64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.gauges[name] += delta
}

// GetSnapshot returns a snapshot of current metrics
func (m *Metrics) GetSnapshot() MetricsSnapshot {
	m.mu.RLock()
	defer m.mu.RUnlock()

	snapshot := MetricsSnapshot{
		Timestamp:        time.Now().UTC(),
		RequestCount:     make(map[string]int64),
		ErrorCount:       make(map[string]int64),
		Gauges:           make(map[string]float64),
		DBConnections:    m.dbConnections,
		DBMaxConnections: m.dbConnectionsMax,
		SlowQueryCount:   m.slowQueryCount,
		CacheHits:        m.cacheHits,
		CacheMisses:      m.cacheMisses,
	}

	for k, v := range m.requestCount {
		snapshot.RequestCount[k] = v
	}
	for k, v := range m.errorCount {
		snapshot.ErrorCount[k] = v
	}
	for k, v := range m.gauges {
		snapshot.Gauges[k] = v
	}

	// Calculate cache hit rate
	total := m.cacheHits + m.cacheMisses
	if total > 0 {
		snapshot.CacheHitRate = float64(m.cacheHits) / float64(total)
	}

	return snapshot
}

// MetricsSnapshot is a point-in-time snapshot of metrics
type MetricsSnapshot struct {
	Timestamp        time.Time          `json:"timestamp"`
	RequestCount     map[string]int64   `json:"request_count"`
	ErrorCount       map[string]int64   `json:"error_count"`
	Gauges           map[string]float64 `json:"gauges"`
	DBConnections    int64              `json:"db_connections"`
	DBMaxConnections int64              `json:"db_max_connections"`
	SlowQueryCount   int64              `json:"slow_query_count"`
	CacheHits        int64              `json:"cache_hits"`
	CacheMisses      int64              `json:"cache_misses"`
	CacheHitRate     float64            `json:"cache_hit_rate"`
}

// ToPrometheus exports metrics in Prometheus format
func (m *Metrics) ToPrometheus() string {
	m.mu.RLock()
	defer m.mu.RUnlock()

	var output string

	// Request count
	output += "# HELP http_requests_total Total HTTP requests\n"
	output += "# TYPE http_requests_total counter\n"
	for key, count := range m.requestCount {
		output += "http_requests_total{endpoint=\"" + key + "\"} " + formatInt64(count) + "\n"
	}

	// Error count
	output += "# HELP http_errors_total Total HTTP errors\n"
	output += "# TYPE http_errors_total counter\n"
	for key, count := range m.errorCount {
		output += "http_errors_total{endpoint=\"" + key + "\"} " + formatInt64(count) + "\n"
	}

	// DB connections
	output += "# HELP db_connections_active Active database connections\n"
	output += "# TYPE db_connections_active gauge\n"
	output += "db_connections_active " + formatInt64(m.dbConnections) + "\n"

	output += "# HELP db_connections_max Maximum database connections\n"
	output += "# TYPE db_connections_max gauge\n"
	output += "db_connections_max " + formatInt64(m.dbConnectionsMax) + "\n"

	// Slow queries
	output += "# HELP db_slow_queries_total Total slow database queries\n"
	output += "# TYPE db_slow_queries_total counter\n"
	output += "db_slow_queries_total " + formatInt64(m.slowQueryCount) + "\n"

	// Cache
	output += "# HELP cache_hits_total Total cache hits\n"
	output += "# TYPE cache_hits_total counter\n"
	output += "cache_hits_total " + formatInt64(m.cacheHits) + "\n"

	output += "# HELP cache_misses_total Total cache misses\n"
	output += "# TYPE cache_misses_total counter\n"
	output += "cache_misses_total " + formatInt64(m.cacheMisses) + "\n"

	// Custom gauges
	for name, value := range m.gauges {
		output += "# HELP " + name + " Custom gauge metric\n"
		output += "# TYPE " + name + " gauge\n"
		output += name + " " + formatFloat64(value) + "\n"
	}

	return output
}

func formatInt64(v int64) string {
	return string(rune(v + '0'))
}

func formatFloat64(v float64) string {
	return string(rune(int(v) + '0'))
}
