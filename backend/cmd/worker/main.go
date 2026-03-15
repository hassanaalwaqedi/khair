package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
	"github.com/redis/go-redis/v9"

	"github.com/khair/backend/internal/ai"
	"github.com/khair/backend/internal/notification"
	"github.com/khair/backend/internal/push"
	"github.com/khair/backend/internal/trust/audit"
	"github.com/khair/backend/internal/trust/score"
	"github.com/khair/backend/pkg/config"
	"github.com/khair/backend/pkg/database"
	"github.com/khair/backend/pkg/email"
	"github.com/khair/backend/pkg/fcm"
	"github.com/khair/backend/pkg/jobqueue"
)

func main() {
	log.Println("[WORKER] Starting Khair background worker...")

	// Load configuration (same as API server)
	cfg := config.Load()

	// Connect to PostgreSQL (for notification writes)
	db, err := database.Connect(cfg.Database)
	if err != nil {
		log.Fatalf("[WORKER] Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Connect to Redis
	redisClient := redis.NewClient(&redis.Options{
		Addr:     cfg.Redis.Addr,
		Password: cfg.Redis.Password,
		DB:       cfg.Redis.DB,
	})
	if err := redisClient.Ping(context.Background()).Err(); err != nil {
		log.Fatalf("[WORKER] Failed to connect to Redis: %v", err)
	}
	defer redisClient.Close()

	// Initialize services used by the worker
	emailSvc := email.NewService(cfg.SMTP)
	notifSvc := notification.NewService(db)
	queue := jobqueue.NewQueue(redisClient)

	// Initialize trust score and AI services
	sqlxDB := sqlx.NewDb(db, "postgres")
	auditSvc := audit.NewService(sqlxDB)
	scoreSvc := score.NewService(sqlxDB, auditSvc)
	geminiClient := ai.NewClient(cfg.Gemini)
	interactionRepo := ai.NewInteractionRepository(db)
	rankingSvc := ai.NewRankingService(geminiClient, interactionRepo, db)

	// Initialize FCM push service for reminders
	fcmClient := fcm.NewClient(os.Getenv("FCM_SERVER_KEY"))
	pushSvc := push.NewService(db, fcmClient)

	// Graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		sig := <-sigChan
		log.Printf("[WORKER] Received signal %v, shutting down...", sig)
		cancel()
	}()

	log.Printf("[WORKER] Listening on queues: %v", jobqueue.AllQueues())

	// Main processing loop — periodic trust recalculation + event reminders
	trustTicker := time.NewTicker(12 * time.Hour)
	defer trustTicker.Stop()
	reminderTicker := time.NewTicker(30 * time.Minute)
	defer reminderTicker.Stop()

	// Run reminders immediately on startup
	go sendEventReminders(db, notifSvc, pushSvc)

	for {
		select {
		case <-ctx.Done():
			log.Println("[WORKER] Shutdown complete.")
			return
		case <-trustTicker.C:
			log.Println("[WORKER] Running periodic trust score recalculation...")
			recalculateAllTrustScores(db, scoreSvc)
		case <-reminderTicker.C:
			log.Println("[WORKER] Checking for upcoming event reminders...")
			sendEventReminders(db, notifSvc, pushSvc)
		default:
		}

		job, queueName, err := queue.Dequeue(ctx, 5*time.Second, jobqueue.AllQueues()...)
		if err != nil {
			if ctx.Err() != nil {
				log.Println("[WORKER] Shutdown complete.")
				return
			}
			log.Printf("[WORKER] Dequeue error: %v", err)
			time.Sleep(1 * time.Second)
			continue
		}

		if job == nil {
			continue // timeout, no job
		}

		log.Printf("[WORKER] Processing job %s (type=%s) from %s", job.ID, job.Type, queueName)

		if err := processJob(job, emailSvc, notifSvc, scoreSvc, rankingSvc); err != nil {
			log.Printf("[WORKER] Job %s failed: %v", job.ID, err)

			// Retry with exponential backoff
			retried, retryErr := queue.Retry(ctx, job)
			if retryErr != nil {
				log.Printf("[WORKER] Failed to retry job %s: %v", job.ID, retryErr)
			}
			if !retried {
				log.Printf("[WORKER] Job %s permanently failed after %d attempts", job.ID, job.RetryCount)
			}
		} else {
			log.Printf("[WORKER] Job %s completed successfully", job.ID)
		}
	}
}

func processJob(job *jobqueue.Job, emailSvc *email.Service, notifSvc *notification.Service, scoreSvc *score.Service, rankingSvc *ai.RankingService) error {
	switch job.Type {
	case jobqueue.JobSendEmail:
		return handleSendEmail(job, emailSvc)
	case jobqueue.JobCreateNotification:
		return handleCreateNotification(job, notifSvc)
	case jobqueue.JobRecalculateTrustScore:
		return handleRecalculateTrustScore(job, scoreSvc)
	case jobqueue.JobAIRecommendation:
		return handleAIRecommendation(job, rankingSvc)
	default:
		return fmt.Errorf("unknown job type: %s", job.Type)
	}
}

func handleSendEmail(job *jobqueue.Job, emailSvc *email.Service) error {
	var payload jobqueue.SendEmailPayload
	if err := json.Unmarshal(job.Payload, &payload); err != nil {
		return fmt.Errorf("unmarshal email payload: %w", err)
	}

	if payload.Template == "verification" && payload.OTP != "" {
		return emailSvc.SendVerificationEmail(payload.To, payload.OTP)
	}

	log.Printf("[WORKER] Email job to=%s subject=%q (no handler for generic emails yet)", payload.To, payload.Subject)
	return nil
}

func handleCreateNotification(job *jobqueue.Job, notifSvc *notification.Service) error {
	var payload jobqueue.CreateNotificationPayload
	if err := json.Unmarshal(job.Payload, &payload); err != nil {
		return fmt.Errorf("unmarshal notification payload: %w", err)
	}

	userID, err := uuid.Parse(payload.UserID)
	if err != nil {
		return fmt.Errorf("parse user ID: %w", err)
	}

	return notifSvc.Create(userID, payload.Title, payload.Message)
}

func handleRecalculateTrustScore(job *jobqueue.Job, scoreSvc *score.Service) error {
	var payload jobqueue.RecalculateTrustScorePayload
	if err := json.Unmarshal(job.Payload, &payload); err != nil {
		return fmt.Errorf("unmarshal trust score payload: %w", err)
	}

	organizerID, err := uuid.Parse(payload.UserID)
	if err != nil {
		return fmt.Errorf("parse organizer ID: %w", err)
	}

	score, err := scoreSvc.RecalculateScore(context.Background(), organizerID)
	if err != nil {
		return fmt.Errorf("recalculate trust score: %w", err)
	}

	log.Printf("[WORKER] Trust score recalculated for organizer %s: score=%d", organizerID, score.TrustScore)
	return nil
}

func handleAIRecommendation(job *jobqueue.Job, rankingSvc *ai.RankingService) error {
	var payload jobqueue.AIRecommendationPayload
	if err := json.Unmarshal(job.Payload, &payload); err != nil {
		return fmt.Errorf("unmarshal AI recommendation payload: %w", err)
	}

	userID, err := uuid.Parse(payload.UserID)
	if err != nil {
		return fmt.Errorf("parse user ID: %w", err)
	}

	recs, err := rankingSvc.GetRecommendedEvents(context.Background(), userID, 20)
	if err != nil {
		return fmt.Errorf("generate AI recommendations: %w", err)
	}

	log.Printf("[WORKER] Generated %d AI recommendations for user %s", len(recs), userID)
	return nil
}

// recalculateAllTrustScores recalculates trust scores for all organizers
func recalculateAllTrustScores(db *sql.DB, scoreSvc *score.Service) {
	rows, err := db.Query(`SELECT id FROM organizers WHERE status = 'approved'`)
	if err != nil {
		log.Printf("[WORKER] Failed to list organizers for trust recalculation: %v", err)
		return
	}
	defer rows.Close()

	var count int
	for rows.Next() {
		var orgID uuid.UUID
		if err := rows.Scan(&orgID); err != nil {
			continue
		}
		if _, err := scoreSvc.RecalculateScore(context.Background(), orgID); err != nil {
			log.Printf("[WORKER] Trust recalc failed for organizer %s: %v", orgID, err)
		} else {
			count++
		}
	}
	log.Printf("[WORKER] Trust score recalculation complete: %d organizers updated", count)
}

// sendEventReminders sends notifications for events starting in 24h and 2h
func sendEventReminders(db *sql.DB, notifSvc *notification.Service, pushSvc *push.Service) {
	now := time.Now().UTC()

	// Check for 24-hour reminders (events starting between 23.5h and 24.5h from now)
	sendRemindersForWindow(db, notifSvc, pushSvc, now.Add(23*time.Hour+30*time.Minute), now.Add(24*time.Hour+30*time.Minute), "24 hours")

	// Check for 2-hour reminders (events starting between 1.5h and 2.5h from now)
	sendRemindersForWindow(db, notifSvc, pushSvc, now.Add(90*time.Minute), now.Add(150*time.Minute), "2 hours")
}

func sendRemindersForWindow(db *sql.DB, notifSvc *notification.Service, pushSvc *push.Service, windowStart, windowEnd time.Time, label string) {
	// Find events starting in this window
	rows, err := db.Query(`
		SELECT e.id, e.title
		FROM events e
		WHERE e.status IN ('approved', 'published')
		  AND e.start_date >= $1
		  AND e.start_date < $2
	`, windowStart, windowEnd)
	if err != nil {
		log.Printf("[WORKER] Reminder query error: %v", err)
		return
	}
	defer rows.Close()

	for rows.Next() {
		var eventID uuid.UUID
		var title string
		if err := rows.Scan(&eventID, &title); err != nil {
			continue
		}

		// Get all registered attendees for this event
		attendees, err := db.Query(`
			SELECT user_id FROM event_registrations
			WHERE event_id = $1 AND status IN ('confirmed', 'reserved')
		`, eventID)
		if err != nil {
			log.Printf("[WORKER] Reminder attendee query error for event %s: %v", eventID, err)
			continue
		}

		var count int
		for attendees.Next() {
			var userID uuid.UUID
			if err := attendees.Scan(&userID); err != nil {
				continue
			}

			remTitle := "Event Reminder"
			remMsg := fmt.Sprintf("Your event \"%s\" starts in %s.", title, label)

			if notifSvc != nil {
				_ = notifSvc.Create(userID, remTitle, remMsg)
			}
			if pushSvc != nil {
				pushSvc.SendToUser(userID, remTitle, remMsg, map[string]string{
					"type":     "event_reminder",
					"event_id": eventID.String(),
				})
			}
			count++
		}
		attendees.Close()

		if count > 0 {
			log.Printf("[WORKER] Sent %s reminder for '%s' to %d attendees", label, title, count)
		}
	}
}
