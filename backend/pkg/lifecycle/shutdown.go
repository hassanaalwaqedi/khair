package lifecycle

import (
	"context"
	"database/sql"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/khair/backend/pkg/observability"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
)

// Manager handles application lifecycle
type Manager struct {
	server       *http.Server
	db           *sql.DB
	redis        *redis.Client
	logger       *observability.Logger
	shutdownOnce sync.Once
	done         chan struct{}

	// Graceful shutdown config
	ShutdownTimeout time.Duration
	DrainTimeout    time.Duration
}

// NewManager creates a new lifecycle manager
func NewManager(server *http.Server, db *sql.DB, redisClient *redis.Client) *Manager {
	return &Manager{
		server:          server,
		db:              db,
		redis:           redisClient,
		logger:          observability.Default(),
		done:            make(chan struct{}),
		ShutdownTimeout: 30 * time.Second,
		DrainTimeout:    10 * time.Second,
	}
}

// Start begins listening for shutdown signals
func (m *Manager) Start() {
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM, syscall.SIGQUIT)

	go func() {
		sig := <-sigChan
		m.logger.Info("Received shutdown signal", map[string]interface{}{
			"signal": sig.String(),
		})
		m.Shutdown()
	}()
}

// Shutdown performs graceful shutdown
func (m *Manager) Shutdown() {
	m.shutdownOnce.Do(func() {
		m.logger.Info("Starting graceful shutdown...")

		// Create shutdown context with timeout
		ctx, cancel := context.WithTimeout(context.Background(), m.ShutdownTimeout)
		defer cancel()

		// Phase 1: Stop accepting new connections
		m.logger.Info("Phase 1: Stopping new connections...")
		if err := m.server.Shutdown(ctx); err != nil {
			m.logger.Error("Server shutdown error", map[string]interface{}{
				"error": err.Error(),
			})
		}

		// Phase 2: Wait for in-flight requests to drain
		m.logger.Info("Phase 2: Draining in-flight requests...")
		time.Sleep(m.DrainTimeout)

		// Phase 3: Close database connections
		m.logger.Info("Phase 3: Closing database connections...")
		if m.db != nil {
			if err := m.db.Close(); err != nil {
				m.logger.Error("Database close error", map[string]interface{}{
					"error": err.Error(),
				})
			}
		}

		// Phase 4: Close Redis connection
		m.logger.Info("Phase 4: Closing Redis connection...")
		if m.redis != nil {
			if err := m.redis.Close(); err != nil {
				m.logger.Error("Redis close error", map[string]interface{}{
					"error": err.Error(),
				})
			}
		}

		m.logger.Info("Graceful shutdown complete")
		close(m.done)
	})
}

// Done returns channel that closes when shutdown is complete
func (m *Manager) Done() <-chan struct{} {
	return m.done
}

// HealthChecker provides health check functionality
type HealthChecker struct {
	db     *sql.DB
	redis  *redis.Client
	logger *observability.Logger
}

// NewHealthChecker creates a new health checker
func NewHealthChecker(db *sql.DB, redisClient *redis.Client) *HealthChecker {
	return &HealthChecker{
		db:     db,
		redis:  redisClient,
		logger: observability.Default(),
	}
}

// HealthResponse represents health check response
type HealthResponse struct {
	Status    string           `json:"status"`
	Timestamp string           `json:"timestamp"`
	Version   string           `json:"version"`
	Checks    map[string]Check `json:"checks"`
}

// Check represents individual service check
type Check struct {
	Status  string `json:"status"`
	Latency string `json:"latency,omitempty"`
	Error   string `json:"error,omitempty"`
}

// LivenessHandler returns basic liveness check
func (h *HealthChecker) LivenessHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":    "alive",
			"timestamp": time.Now().UTC().Format(time.RFC3339),
		})
	}
}

// ReadinessHandler checks if service is ready to accept traffic
func (h *HealthChecker) ReadinessHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
		defer cancel()

		response := HealthResponse{
			Status:    "ready",
			Timestamp: time.Now().UTC().Format(time.RFC3339),
			Version:   "1.0.0",
			Checks:    make(map[string]Check),
		}

		allHealthy := true

		// Check database
		dbCheck := h.checkDatabase(ctx)
		response.Checks["database"] = dbCheck
		if dbCheck.Status != "healthy" {
			allHealthy = false
		}

		// Check Redis
		redisCheck := h.checkRedis(ctx)
		response.Checks["redis"] = redisCheck
		if redisCheck.Status != "healthy" {
			allHealthy = false
		}

		if !allHealthy {
			response.Status = "degraded"
			c.JSON(http.StatusServiceUnavailable, response)
			return
		}

		c.JSON(http.StatusOK, response)
	}
}

func (h *HealthChecker) checkDatabase(ctx context.Context) Check {
	start := time.Now()

	if h.db == nil {
		return Check{Status: "unhealthy", Error: "database not configured"}
	}

	if err := h.db.PingContext(ctx); err != nil {
		return Check{
			Status: "unhealthy",
			Error:  err.Error(),
		}
	}

	return Check{
		Status:  "healthy",
		Latency: time.Since(start).String(),
	}
}

func (h *HealthChecker) checkRedis(ctx context.Context) Check {
	start := time.Now()

	if h.redis == nil {
		return Check{Status: "unhealthy", Error: "redis not configured"}
	}

	if err := h.redis.Ping(ctx).Err(); err != nil {
		return Check{
			Status: "unhealthy",
			Error:  err.Error(),
		}
	}

	return Check{
		Status:  "healthy",
		Latency: time.Since(start).String(),
	}
}

// DatabasePoolConfig configures database connection pool
type DatabasePoolConfig struct {
	MaxOpenConns    int
	MaxIdleConns    int
	ConnMaxLifetime time.Duration
	ConnMaxIdleTime time.Duration
}

// DefaultPoolConfig returns production-ready pool config
func DefaultPoolConfig() *DatabasePoolConfig {
	return &DatabasePoolConfig{
		MaxOpenConns:    25,
		MaxIdleConns:    10,
		ConnMaxLifetime: 5 * time.Minute,
		ConnMaxIdleTime: 1 * time.Minute,
	}
}

// ApplyPoolConfig applies pool configuration to database
func ApplyPoolConfig(db *sql.DB, config *DatabasePoolConfig) {
	db.SetMaxOpenConns(config.MaxOpenConns)
	db.SetMaxIdleConns(config.MaxIdleConns)
	db.SetConnMaxLifetime(config.ConnMaxLifetime)
	db.SetConnMaxIdleTime(config.ConnMaxIdleTime)
}
