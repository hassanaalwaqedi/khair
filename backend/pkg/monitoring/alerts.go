package monitoring

import (
	"context"
	"sync"
	"time"

	"github.com/khair/backend/pkg/observability"
)

// AlertLevel represents alert severity
type AlertLevel string

const (
	AlertInfo     AlertLevel = "info"
	AlertWarning  AlertLevel = "warning"
	AlertCritical AlertLevel = "critical"
)

// Alert represents an alert
type Alert struct {
	Name      string      `json:"name"`
	Level     AlertLevel  `json:"level"`
	Message   string      `json:"message"`
	Value     float64     `json:"value"`
	Threshold float64     `json:"threshold"`
	Timestamp time.Time   `json:"timestamp"`
	Resolved  bool        `json:"resolved"`
}

// AlertConfig defines alert thresholds
type AlertConfig struct {
	Name       string
	Threshold  float64
	Level      AlertLevel
	Message    string
	Comparator string // "gt" (greater than), "lt" (less than), "eq"
}

// DefaultAlertConfigs returns production alert configurations
func DefaultAlertConfigs() []AlertConfig {
	return []AlertConfig{
		{
			Name:       "high_error_rate",
			Threshold:  5.0, // 5%
			Level:      AlertCritical,
			Message:    "Error rate exceeds 5%",
			Comparator: "gt",
		},
		{
			Name:       "high_latency_p99",
			Threshold:  2000.0, // 2000ms
			Level:      AlertCritical,
			Message:    "P99 latency exceeds 2 seconds",
			Comparator: "gt",
		},
		{
			Name:       "db_connection_exhaustion",
			Threshold:  80.0, // 80%
			Level:      AlertWarning,
			Message:    "Database connection pool usage exceeds 80%",
			Comparator: "gt",
		},
		{
			Name:       "redis_connection_failure",
			Threshold:  1.0,
			Level:      AlertCritical,
			Message:    "Redis connection failure detected",
			Comparator: "eq",
		},
		{
			Name:       "slow_query_rate",
			Threshold:  10.0, // 10 slow queries per minute
			Level:      AlertWarning,
			Message:    "High slow query rate detected",
			Comparator: "gt",
		},
		{
			Name:       "low_cache_hit_rate",
			Threshold:  50.0, // 50%
			Level:      AlertInfo,
			Message:    "Cache hit rate below 50%",
			Comparator: "lt",
		},
	}
}

// AlertManager manages alerts
type AlertManager struct {
	configs []AlertConfig
	alerts  map[string]*Alert
	mu      sync.RWMutex
	logger  *observability.Logger
	
	// Alert handlers
	handlers []AlertHandler
}

// AlertHandler is called when an alert fires
type AlertHandler func(alert *Alert)

// NewAlertManager creates a new alert manager
func NewAlertManager(configs []AlertConfig) *AlertManager {
	return &AlertManager{
		configs:  configs,
		alerts:   make(map[string]*Alert),
		logger:   observability.Default(),
		handlers: make([]AlertHandler, 0),
	}
}

// AddHandler adds an alert handler
func (am *AlertManager) AddHandler(handler AlertHandler) {
	am.handlers = append(am.handlers, handler)
}

// Check evaluates a metric against configured thresholds
func (am *AlertManager) Check(name string, value float64) {
	for _, config := range am.configs {
		if config.Name != name {
			continue
		}

		triggered := false
		switch config.Comparator {
		case "gt":
			triggered = value > config.Threshold
		case "lt":
			triggered = value < config.Threshold
		case "eq":
			triggered = value == config.Threshold
		}

		am.mu.Lock()
		existing, exists := am.alerts[name]

		if triggered {
			if !exists || existing.Resolved {
				// New alert
				alert := &Alert{
					Name:      name,
					Level:     config.Level,
					Message:   config.Message,
					Value:     value,
					Threshold: config.Threshold,
					Timestamp: time.Now(),
					Resolved:  false,
				}
				am.alerts[name] = alert
				am.mu.Unlock()

				// Fire handlers
				am.fireAlert(alert)
				return
			}
		} else if exists && !existing.Resolved {
			// Alert resolved
			existing.Resolved = true
			am.mu.Unlock()

			am.logger.Info("Alert resolved", map[string]interface{}{
				"alert": name,
				"value": value,
			})
			return
		}
		am.mu.Unlock()
	}
}

func (am *AlertManager) fireAlert(alert *Alert) {
	// Log alert
	am.logger.Warn("Alert triggered", map[string]interface{}{
		"alert":     alert.Name,
		"level":     alert.Level,
		"message":   alert.Message,
		"value":     alert.Value,
		"threshold": alert.Threshold,
	})

	// Call handlers
	for _, handler := range am.handlers {
		go handler(alert)
	}
}

// GetActiveAlerts returns all active (non-resolved) alerts
func (am *AlertManager) GetActiveAlerts() []Alert {
	am.mu.RLock()
	defer am.mu.RUnlock()

	active := make([]Alert, 0)
	for _, alert := range am.alerts {
		if !alert.Resolved {
			active = append(active, *alert)
		}
	}
	return active
}

// MetricChecker periodically checks metrics against thresholds
type MetricChecker struct {
	manager  *AlertManager
	metrics  *observability.Metrics
	interval time.Duration
	stop     chan struct{}
}

// NewMetricChecker creates a new metric checker
func NewMetricChecker(manager *AlertManager, metrics *observability.Metrics, interval time.Duration) *MetricChecker {
	return &MetricChecker{
		manager:  manager,
		metrics:  metrics,
		interval: interval,
		stop:     make(chan struct{}),
	}
}

// Start begins periodic metric checking
func (mc *MetricChecker) Start(ctx context.Context) {
	ticker := time.NewTicker(mc.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			mc.check()
		case <-mc.stop:
			return
		case <-ctx.Done():
			return
		}
	}
}

// Stop stops the metric checker
func (mc *MetricChecker) Stop() {
	close(mc.stop)
}

func (mc *MetricChecker) check() {
	snapshot := mc.metrics.GetSnapshot()

	// Calculate error rate
	totalRequests := int64(0)
	totalErrors := int64(0)
	for _, count := range snapshot.RequestCount {
		totalRequests += count
	}
	for _, count := range snapshot.ErrorCount {
		totalErrors += count
	}
	if totalRequests > 0 {
		errorRate := float64(totalErrors) / float64(totalRequests) * 100
		mc.manager.Check("high_error_rate", errorRate)
	}

	// Check DB connection usage
	if snapshot.DBMaxConnections > 0 {
		usage := float64(snapshot.DBConnections) / float64(snapshot.DBMaxConnections) * 100
		mc.manager.Check("db_connection_exhaustion", usage)
	}

	// Check cache hit rate
	mc.manager.Check("low_cache_hit_rate", snapshot.CacheHitRate*100)
}

// LogAlertHandler logs alerts to the structured logger
func LogAlertHandler(logger *observability.Logger) AlertHandler {
	return func(alert *Alert) {
		fields := map[string]interface{}{
			"alert_name":  alert.Name,
			"alert_level": alert.Level,
			"value":       alert.Value,
			"threshold":   alert.Threshold,
		}

		switch alert.Level {
		case AlertCritical:
			logger.Error(alert.Message, fields)
		case AlertWarning:
			logger.Warn(alert.Message, fields)
		default:
			logger.Info(alert.Message, fields)
		}
	}
}
