package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"net/http"
	"os"

	"github.com/gin-contrib/gzip"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
	"github.com/redis/go-redis/v9"

	"github.com/khair/backend/internal/admin"
	"github.com/khair/backend/internal/ai"
	"github.com/khair/backend/internal/analytics"
	"github.com/khair/backend/internal/attendee"
	"github.com/khair/backend/internal/auth"
	"github.com/khair/backend/internal/countries"
	"github.com/khair/backend/internal/discovery"
	"github.com/khair/backend/internal/event"
	"github.com/khair/backend/internal/growthanalytics"
	"github.com/khair/backend/internal/joinreg"
	"github.com/khair/backend/internal/launch"
	"github.com/khair/backend/internal/location"
	"github.com/khair/backend/internal/mapservice"
	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/internal/notification"
	"github.com/khair/backend/internal/organizer"
	"github.com/khair/backend/internal/orgdash"
	"github.com/khair/backend/internal/ownerposts"
	"github.com/khair/backend/internal/payment"
	"github.com/khair/backend/internal/push"
	"github.com/khair/backend/internal/rbac"
	"github.com/khair/backend/internal/referral"
	"github.com/khair/backend/internal/registration"
	"github.com/khair/backend/internal/reputation"
	"github.com/khair/backend/internal/reservation"
	"github.com/khair/backend/internal/review"
	"github.com/khair/backend/internal/sheikh"
	"github.com/khair/backend/internal/sharing"
	"github.com/khair/backend/internal/spiritualquote"
	"github.com/khair/backend/internal/sse"
	"github.com/khair/backend/internal/trust"
	"github.com/khair/backend/internal/trust/audit"
	"github.com/khair/backend/internal/trust/moderation"
	"github.com/khair/backend/internal/trust/reporting"
	"github.com/khair/backend/internal/trust/score"
	"github.com/khair/backend/internal/upload"
	"github.com/khair/backend/internal/verification"
	"github.com/khair/backend/internal/waitlist"
	"github.com/khair/backend/internal/ws"
	"github.com/khair/backend/pkg/cache"
	"github.com/khair/backend/pkg/config"
	"github.com/khair/backend/pkg/database"
	"github.com/khair/backend/pkg/fcm"
	"github.com/khair/backend/pkg/lifecycle"
	"github.com/khair/backend/pkg/logger"
	"github.com/khair/backend/pkg/middleware"

	"github.com/khair/backend/pkg/email"
	"github.com/khair/backend/pkg/ratelimit"
	"github.com/khair/backend/pkg/response"
	"github.com/khair/backend/pkg/security"

	"github.com/prometheus/client_golang/prometheus/promhttp"
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

	// Connect to Redis (TLS required for Azure Cache for Redis)
	redisOpts := &redis.Options{
		Addr:     cfg.Redis.Addr,
		Password: cfg.Redis.Password,
		DB:       cfg.Redis.DB,
	}
	if os.Getenv("REDIS_TLS") == "true" {
		redisOpts.TLSConfig = &tls.Config{
			InsecureSkipVerify: false,
		}
	}
	redisClient := redis.NewClient(redisOpts)
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
	rateLimiter := ratelimit.NewLimiter(redisClient)

	// Production security config
	secConfig := security.DefaultProductionConfig()

	// Initialize router
	router := gin.Default()

	// Set max multipart memory (8 MB)
	router.MaxMultipartMemory = 8 << 20

	// Apply global middleware
	router.Use(middleware.CORSMiddleware())
	router.Use(middleware.SecurityHeaders())
	router.Use(security.ProductionHeadersMiddleware(secConfig))
	router.Use(security.DisableDebugEndpoints(secConfig.Environment == "production"))
	router.Use(security.SecureErrorMiddleware(secConfig.Environment == "production"))
	router.Use(gzip.Gzip(gzip.DefaultCompression))
	router.Use(middleware.BodySizeLimit(middleware.MaxBodySize))
	router.Use(middleware.RequestLogger())
	router.Use(middleware.PrometheusMetrics())

	// Health check endpoints (production-ready with DB/Redis checks)
	healthChecker := lifecycle.NewHealthChecker(db, redisClient)
	router.GET("/health", func(c *gin.Context) {
		response.Success(c, gin.H{"status": "healthy"})
	})
	router.GET("/healthz", healthChecker.LivenessHandler())
	router.GET("/readyz", healthChecker.ReadinessHandler())

	// Prometheus metrics endpoint
	router.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// API v1 routes
	v1 := router.Group("/api/v1")

	// Auth middleware
	authMiddleware := middleware.AuthMiddleware(cfg)
	adminMiddleware := middleware.AdminOnly()

	// Initialize repositories
	organizerRepo := organizer.NewRepository(db)
	eventRepo := event.NewRepository(db)

	// Initialize email service
	emailSvc := email.NewService(cfg.SMTP)

	// Initialize RBAC
	rbacRepo := rbac.NewRepository(db)
	rbacService := rbac.NewService(rbacRepo)

	// Initialize core services
	authService := auth.NewService(db, cfg, emailSvc, rbacRepo, redisClient)
	organizerService := organizer.NewService(db)
	eventService := event.NewService(db, &organizerRepoAdapter{repo: organizerRepo})
	mapService := mapservice.NewService(db)
	registrationService := registration.NewService(db, cfg, emailSvc)

	notificationService := notification.NewService(db)
	cacheService := cache.NewService(redisClient)
	sseHub := sse.NewHub()
	adminService := admin.NewService(db, &organizerRepoAdapter{repo: organizerRepo}, &eventRepoAdapter{repo: eventRepo}, rbacService, notificationService, cacheService, sseHub)

	// WebSocket hub (Redis Pub/Sub for horizontal scaling)
	wsHub := ws.NewHub(redisClient, cfg.JWT.Secret)
	go wsHub.Run()

	// FCM push notifications
	fcmClient := fcm.NewClient(os.Getenv("FCM_SERVER_KEY"))
	pushService := push.NewService(db, fcmClient)

	// Analytics + Discovery
	analyticsService := analytics.NewService(db)
	discoveryService := discovery.NewService(db, redisClient)

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
	mapHandler := mapservice.NewHandler(mapService, cfg)
	eventHandler := event.NewHandler(eventService, mapHandler, cfg)
	adminHandler := admin.NewHandler(adminService, db, redisClient)
	locationHandler := location.NewHandler(locationService)
	trustHandler := trust.NewHandler(auditService, moderationService, reportingService, scoreService)
	registrationHandler := registration.NewHandler(registrationService)
	uploadHandler := upload.NewHandler(upload.DefaultConfig())

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

	// Rate limiters for sensitive endpoints
	registerRL := rateLimiter.Middleware("event_create") // 5 req/hr per IP
	verifyRL := rateLimiter.Middleware("report_submit")  // 10 req/hr per IP
	resendRL := rateLimiter.Middleware("report_submit")  // 10 req/hr per IP
	loginRL := rateLimiter.Middleware("default")         // 100 req/hr per IP

	// Register routes (with rate limiting on auth/registration)
	authHandler.RegisterRoutes(v1, loginRL, registerRL, verifyRL, resendRL)
	authHandler.RegisterProtectedRoutes(v1, authMiddleware) // /me/* GDPR + logout
	organizerHandler.RegisterRoutes(v1, authMiddleware)
	eventHandler.RegisterRoutes(v1, authMiddleware)
	adminHandler.RegisterRoutes(v1, authMiddleware)

	// SSE stream for real-time event updates
	v1.GET("/events/stream", sseHub.ServeHTTP)
	mapHandler.RegisterRoutes(v1, nil)
	locationHandler.RegisterRoutes(v1)
	trustHandler.RegisterRoutes(v1, authMiddleware, adminMiddleware)
	aiHandler.RegisterRoutes(v1, authMiddleware)
	registrationHandler.RegisterRoutes(v1, registerRL, verifyRL, resendRL)
	uploadHandler.RegisterRoutes(v1, authMiddleware)

	// WebSocket endpoint (JWT via query param)
	v1.GET("/ws", wsHub.HandleUpgrade)

	// Push notification device registration
	pushHandler := push.NewHandler(pushService)
	pushHandler.RegisterRoutes(v1, authMiddleware)

	// Analytics (admin-only)
	analyticsHandler := analytics.NewHandler(analyticsService)
	adminRoutes := v1.Group("/admin", authMiddleware, adminMiddleware)
	analyticsHandler.RegisterRoutes(adminRoutes)

	// Discovery (public)
	discoveryHandler := discovery.NewHandler(discoveryService)
	discoveryHandler.RegisterRoutes(v1)

	// ── Phase 4: Growth Engine ──

	// Referral system
	referralService := referral.NewService(db)
	referralHandler := referral.NewHandler(referralService)
	referralHandler.RegisterRoutes(v1, authMiddleware)

	// Event reviews (public read, auth write)
	reviewService := review.NewService(db)
	reviewHandler := review.NewHandler(reviewService)
	reviewHandler.RegisterRoutes(v1, authMiddleware)

	// Waitlist system
	waitlistService := waitlist.NewService(db)
	waitlistHandler := waitlist.NewHandler(waitlistService)
	waitlistHandler.RegisterRoutes(v1, authMiddleware)

	// Organizer reputation (public)
	reputationService := reputation.NewService(db)
	reputationHandler := reputation.NewHandler(reputationService)
	reputationHandler.RegisterRoutes(v1)

	// Social sharing + public event pages
	sharingService := sharing.NewService(db)
	sharingHandler := sharing.NewHandler(sharingService)
	sharingHandler.RegisterRoutes(v1)

	// Growth analytics (admin-only)
	growthService := growthanalytics.NewService(db)
	growthHandler := growthanalytics.NewHandler(growthService)
	growthHandler.RegisterRoutes(adminRoutes)

	// Notification API (auth required)
	notificationHandler := notification.NewHandler(notificationService)
	notificationHandler.RegisterRoutes(v1, authMiddleware)

	// Countries API (public, no auth)
	countriesRepo := countries.NewRepository(db)
	countriesHandler := countries.NewHandler(countriesRepo)
	countriesHandler.RegisterRoutes(v1)

	// Verification API (auth + admin)
	verificationRepo := verification.NewRepository(db)
	verificationHandler := verification.NewHandler(verificationRepo)
	verificationHandler.RegisterRoutes(v1, authMiddleware, adminMiddleware)

	// Payment API
	paymentRepo := payment.NewRepository(db)
	paymentService := payment.NewService(paymentRepo, payment.Config{
		CommissionRate: 0.10, // 10% platform fee
	})
	paymentHandler := payment.NewHandler(paymentService)
	paymentHandler.RegisterRoutes(v1, authMiddleware)

	// ── Previously Unregistered Modules ──

	// Reservation API (join/cancel events, availability)
	reservationService := reservation.NewService(db, cfg)
	reservationHandler := reservation.NewHandler(reservationService)
	reservationHandler.RegisterRoutes(v1, authMiddleware)

	// Join Registration API (2-step attendee sign-up)
	joinRegService := joinreg.NewService(db, cfg)
	joinRegHandler := joinreg.NewHandler(joinRegService)
	joinRegHandler.RegisterRoutes(v1, rateLimiter.Middleware("default"))

	// Sheikh Directory API (public)
	sheikhService := sheikh.NewService(db)
	sheikhHandler := sheikh.NewHandler(sheikhService)
	sheikhHandler.RegisterRoutes(v1)

	// Spiritual Quotes API (public)
	quoteRepo := spiritualquote.NewRepository(db)
	quoteService := spiritualquote.NewService(quoteRepo)
	quoteHandler := spiritualquote.NewHandler(quoteService)
	quoteHandler.RegisterRoutes(v1)
	quoteHandler.RegisterAdminRoutes(v1, authMiddleware, adminMiddleware)

	// Launch Control API (admin)
	launchService := launch.NewService(redisClient)
	launchHandler := launch.NewHandler(launchService)
	launchHandler.RegisterRoutes(v1, authMiddleware, adminMiddleware)

	// Organization Dashboard API
	orgdashService := orgdash.NewService(db)
	orgdashHandler := orgdash.NewHandler(orgdashService)

	orgRoutes := v1.Group("/org/:orgId")
	orgRoutes.Use(authMiddleware)
	orgRoutes.Use(func(c *gin.Context) {
		orgID, err := uuid.Parse(c.Param("orgId"))
		if err != nil {
			response.BadRequest(c, "Invalid organization ID")
			c.Abort()
			return
		}
		c.Set("org_id", orgID)
		c.Next()
	})
	{
		orgRoutes.GET("/dashboard", orgdashHandler.GetDashboard)
		orgRoutes.GET("/analytics", orgdashHandler.GetAnalytics)
		orgRoutes.GET("/activity", orgdashHandler.GetActivity)

		orgRoutes.GET("/events", orgdashHandler.ListEvents)
		orgRoutes.POST("/events", orgdashHandler.CreateEvent)
		orgRoutes.PUT("/events/:event_id", orgdashHandler.UpdateEvent)
		orgRoutes.DELETE("/events/:event_id", orgdashHandler.CancelEvent)
		orgRoutes.POST("/events/:event_id/duplicate", orgdashHandler.DuplicateEvent)

		orgRoutes.GET("/members", orgdashHandler.ListMembers)
		orgRoutes.POST("/members", orgdashHandler.AddMember)
		orgRoutes.PUT("/members/:member_id", orgdashHandler.UpdateMemberRole)
		orgRoutes.DELETE("/members/:member_id", orgdashHandler.RemoveMember)

		orgRoutes.GET("/profile", orgdashHandler.GetProfile)
		orgRoutes.PUT("/profile", orgdashHandler.UpdateProfile)
	}

	// Attendee Management API (under org routes)
	attendeeService := attendee.NewService(db)
	attendeeHandler := attendee.NewHandler(attendeeService)
	{
		orgRoutes.GET("/events/:event_id/attendees", attendeeHandler.ListAttendees)
		orgRoutes.PUT("/events/:event_id/attendees/:reg_id/attendance", attendeeHandler.MarkAttendance)
		orgRoutes.DELETE("/events/:event_id/attendees/:reg_id", attendeeHandler.RemoveAttendee)
		orgRoutes.GET("/events/:event_id/attendees/export", attendeeHandler.ExportCSV)
	}

	// Owner Posts API (public read + admin CRUD)
	ownerPostsService := ownerposts.NewService(db)
	ownerPostsHandler := ownerposts.NewHandler(ownerPostsService)
	ownerPostsHandler.RegisterRoutes(v1, authMiddleware, adminMiddleware)

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

func (a *organizerRepoAdapter) Create(org *models.Organizer) error {
	return a.repo.Create(org)
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

func (a *eventRepoAdapter) UpdateStatusWithReviewer(id uuid.UUID, status string, rejectionReason *string, reviewedBy uuid.UUID) error {
	return a.repo.UpdateStatusWithReviewer(id, status, rejectionReason, reviewedBy)
}

func (a *eventRepoAdapter) ListPending() ([]models.EventWithOrganizer, error) {
	return a.repo.ListPending()
}
