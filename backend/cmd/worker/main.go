package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	"github.com/khair/backend/pkg/config"
	"github.com/khair/backend/pkg/database"
	"github.com/khair/backend/pkg/email"
	"github.com/khair/backend/pkg/jobqueue"

	"github.com/khair/backend/internal/notification"
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

	// Main processing loop
	for {
		select {
		case <-ctx.Done():
			log.Println("[WORKER] Shutdown complete.")
			return
		default:
		}

		job, queueName, err := queue.Dequeue(ctx, 5*time.Second, jobqueue.AllQueues()...)
		if err != nil {
			if ctx.Err() != nil {
				// Context cancelled — clean shutdown
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

		if err := processJob(job, emailSvc, notifSvc); err != nil {
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

func processJob(job *jobqueue.Job, emailSvc *email.Service, notifSvc *notification.Service) error {
	switch job.Type {
	case jobqueue.JobSendEmail:
		return handleSendEmail(job, emailSvc)
	case jobqueue.JobCreateNotification:
		return handleCreateNotification(job, notifSvc)
	case jobqueue.JobRecalculateTrustScore:
		return handleRecalculateTrustScore(job)
	case jobqueue.JobAIRecommendation:
		return handleAIRecommendation(job)
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

	// Generic email — logged but not sent (would need a generic send method)
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

func handleRecalculateTrustScore(job *jobqueue.Job) error {
	var payload jobqueue.RecalculateTrustScorePayload
	if err := json.Unmarshal(job.Payload, &payload); err != nil {
		return fmt.Errorf("unmarshal trust score payload: %w", err)
	}

	// TODO: Wire up trust score recalculation service
	log.Printf("[WORKER] Trust score recalculation for user %s (not yet implemented)", payload.UserID)
	return nil
}

func handleAIRecommendation(job *jobqueue.Job) error {
	var payload jobqueue.AIRecommendationPayload
	if err := json.Unmarshal(job.Payload, &payload); err != nil {
		return fmt.Errorf("unmarshal AI recommendation payload: %w", err)
	}

	// TODO: Wire up AI recommendation service
	log.Printf("[WORKER] AI recommendation for user %s, event %s (not yet implemented)", payload.UserID, payload.EventID)
	return nil
}
