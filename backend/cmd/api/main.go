package main

import (
	"context"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
	"github.com/redis/go-redis/v9"

	"github.com/khair/backend/internal/admin"
	"github.com/khair/backend/internal/ai"
	"github.com/khair/backend/internal/auth"
	"github.com/khair/backend/internal/event"
	"github.com/khair/backend/internal/location"
	"github.com/khair/backend/internal/mapservice"
	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/internal/organizer"
	"github.com/khair/backend/internal/trust"
	"github.com/khair/backend/internal/trust/audit"
	"github.com/khair/backend/internal/trust/moderation"
	"github.com/khair/backend/internal/trust/reporting"
	"github.com/khair/backend/internal/trust/score"
	"github.com/khair/backend/pkg/config"
	"github.com/khair/backend/pkg/database"
	"github.com/khair/backend/pkg/lifecycle"
	"github.com/khair/backend/pkg/logger"
	"github.com/khair/backend/pkg/middleware"

	// "github.com/khair/backend/pkg/ratelimit"
	"github.com/khair/backend/pkg/response"
)

func main() {
	// Load configuration
	cfg := config.Load()

	// Initialize structured logger
	appLogger := logger.New(logger.Config{
		Level:  cfg.Logger.Level,
		Pretty: cfg.Logger.Pretty,
	})

	appLogger.Info("Starting Khair API Server",
		logger.String("version", "1.0.0"),
		logger.String("port", cfg.Server.Port),
		logger.String("mode", cfg.Server.Mode),
	)

	// Set Gin mode
	gin.SetMode(cfg.Server.Mode)

	// Connect to database
	db, err := database.Connect(cfg.Database)
	if err != nil {
		appLogger.Fatal("Failed to connect to database", err)
	}
	// Note: database.Close() is handled by lifecycle manager
	// defer database.Close()

	// Apply production-ready connection pool settings
	lifecycle.ApplyPoolConfig(db, lifecycle.DefaultPoolConfig())

	// Run migrations
	if err := database.RunMigrations(db, "migrations"); err != nil {
		appLogger.Warn("Failed to run migrations", logger.String("error", err.Error()))
	} else {
		appLogger.Info("Database migrations completed")
	}

	// Connect to Redis
	redisClient := redis.NewClient(&redis.Options{
		Addr:     cfg.Redis.Addr,
		Password: cfg.Redis.Password,
		DB:       cfg.Redis.DB,
	})
	// Note: redisClient.Close() is handled by lifecycle manager
	// defer redisClient.Close()

	// Test Redis connection
	if _, err := redisClient.Ping(context.Background()).Result(); err != nil {
		appLogger.Warn("Redis connection failed (rate limiting disabled)",
			logger.String("error", err.Error()),
		)
	} else {
		appLogger.Info("Redis connection established")
	}

	// Initialize rate limiter
	// rateLimiter := ratelimit.NewLimiter(redisClient)

	// Initialize router
	router := gin.Default()

	// Apply global middleware
	router.Use(middleware.CORSMiddleware())
	router.Use(middleware.SecurityHeaders())

	// Health check endpoints (production-ready with DB/Redis checks)
	healthChecker := lifecycle.NewHealthChecker(db, redisClient)
	router.GET("/health", func(c *gin.Context) {
		response.Success(c, gin.H{"status": "healthy"})
	})
	router.GET("/healthz", healthChecker.LivenessHandler())
	router.GET("/readyz", healthChecker.ReadinessHandler())

	// API v1 routes
	v1 := router.Group("/api/v1")

	// Auth middleware
	authMiddleware := middleware.AuthMiddleware(cfg)
	adminMiddleware := middleware.AdminMiddleware()

	// Initialize repositories
	organizerRepo := organizer.NewRepository(db)
	eventRepo := event.NewRepository(db)

	// Initialize core services
	authService := auth.NewService(db, cfg)
	organizerService := organizer.NewService(db)
	eventService := event.NewService(db, &organizerRepoAdapter{repo: organizerRepo})
	mapService := mapservice.NewService(db)
	adminService := admin.NewService(db, &organizerRepoAdapter{repo: organizerRepo}, &eventRepoAdapter{repo: eventRepo})

	// Wrap *sql.DB with sqlx for trust services that require it
	sqlxDB := sqlx.NewDb(db, "postgres")

	// Initialize Trust & Safety services
	auditService := audit.NewService(sqlxDB)
	moderationService := moderation.NewService(sqlxDB)
	reportingService := reporting.NewService(sqlxDB, auditService)
	scoreService := score.NewService(sqlxDB, auditService)

	// Initialize location service
	locationService := location.NewService()

	// Initialize handlers
	authHandler := auth.NewHandler(authService)
	organizerHandler := organizer.NewHandler(organizerService)
	eventHandler := event.NewHandler(eventService, cfg)
	adminHandler := admin.NewHandler(adminService)
	mapHandler := mapservice.NewHandler(mapService)
	locationHandler := location.NewHandler(locationService)
	trustHandler := trust.NewHandler(auditService, moderationService, reportingService, scoreService)

	// Initialize AI services
	geminiClient := ai.NewClient(cfg.Gemini)
	interactionRepo := ai.NewInteractionRepository(db)
	rankingService := ai.NewRankingService(geminiClient, interactionRepo, db)
	descriptionService := ai.NewDescriptionService(geminiClient)
	aiHandler := ai.NewHandler(rankingService, descriptionService, interactionRepo, geminiClient)

	if geminiClient.IsEnabled() {
		appLogger.Info("AI Personalization enabled", logger.String("model", cfg.Gemini.Model))
	} else {
		appLogger.Warn("AI Personalization disabled (no GEMINI_API_KEY)")
	}

	// Register routes
	authHandler.RegisterRoutes(v1)
	organizerHandler.RegisterRoutes(v1, authMiddleware)
	eventHandler.RegisterRoutes(v1, authMiddleware)
	adminHandler.RegisterRoutes(v1, authMiddleware)
	mapHandler.RegisterRoutes(v1)
	locationHandler.RegisterRoutes(v1)
	trustHandler.RegisterRoutes(v1, authMiddleware, adminMiddleware)
	aiHandler.RegisterRoutes(v1, authMiddleware)

	// Apply rate limiting to sensitive endpoints
	// TODO: Apply rate limiting to sensitive endpoints within the handlers or via middleware injection
	// v1.POST("/events", rateLimiter.Middleware("event_create"))
	// v1.PUT("/events/:id", rateLimiter.Middleware("event_edit"))
	// v1.POST("/reports", rateLimiter.Middleware("report_submit"))

	// 404 handler
	router.NoRoute(func(c *gin.Context) {
		response.NotFound(c, "Endpoint not found")
	})

	// Create HTTP server with explicit timeouts
	addr := fmt.Sprintf(":%s", cfg.Server.Port)
	server := &http.Server{
		Addr:    addr,
		Handler: router,
	}

	// Initialize lifecycle manager for graceful shutdown
	manager := lifecycle.NewManager(server, db, redisClient)
	manager.Start()

	appLogger.Info("Server starting", logger.String("address", addr))

	// Start serving — blocks until server is shut down
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		appLogger.Fatal("Failed to start server", err)
	}

	// Wait for graceful shutdown to complete
	<-manager.Done()
	appLogger.Info("Server exited gracefully")
}

// organizerRepoAdapter adapts organizer.Repository to event.OrganizerRepository interface
type organizerRepoAdapter struct {
	repo *organizer.Repository
}

func (a *organizerRepoAdapter) GetByID(id uuid.UUID) (*models.Organizer, error) {
	return a.repo.GetByID(id)
}

func (a *organizerRepoAdapter) GetByUserID(userID uuid.UUID) (*models.Organizer, error) {
	return a.repo.GetByUserID(userID)
}

func (a *organizerRepoAdapter) UpdateStatus(id uuid.UUID, status string, rejectionReason *string) error {
	return a.repo.UpdateStatus(id, status, rejectionReason)
}

func (a *organizerRepoAdapter) ListPending() ([]models.Organizer, error) {
	return a.repo.ListPending()
}

func (a *organizerRepoAdapter) ListAll() ([]models.Organizer, error) {
	return a.repo.ListAll()
}

// eventRepoAdapter adapts event.Repository to admin.EventRepository interface
type eventRepoAdapter struct {
	repo *event.Repository
}

func (a *eventRepoAdapter) GetByID(id uuid.UUID) (*models.EventWithOrganizer, error) {
	return a.repo.GetByID(id)
}

func (a *eventRepoAdapter) UpdateStatus(id uuid.UUID, status string, rejectionReason *string) error {
	return a.repo.UpdateStatus(id, status, rejectionReason)
}

func (a *eventRepoAdapter) ListPending() ([]models.EventWithOrganizer, error) {
	return a.repo.ListPending()
}
