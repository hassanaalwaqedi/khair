package jobqueue

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

// Job types
const (
	JobSendEmail             = "send_email"
	JobCreateNotification    = "create_notification"
	JobRecalculateTrustScore = "recalculate_trust_score"
	JobAIRecommendation      = "ai_recommendation"
)

// Job represents a unit of work to be processed asynchronously.
type Job struct {
	ID         string          `json:"id"`
	Type       string          `json:"type"`
	Payload    json.RawMessage `json:"payload"`
	RetryCount int             `json:"retry_count"`
	MaxRetries int             `json:"max_retries"`
	CreatedAt  time.Time       `json:"created_at"`
}

// ── Payload types ──

// SendEmailPayload is the payload for email jobs.
type SendEmailPayload struct {
	To       string `json:"to"`
	Subject  string `json:"subject"`
	Body     string `json:"body"`
	Language string `json:"language,omitempty"`
	// Template-based emails
	Template string `json:"template,omitempty"`
	OTP      string `json:"otp,omitempty"`
}

// CreateNotificationPayload is the payload for notification jobs.
type CreateNotificationPayload struct {
	UserID  string `json:"user_id"`
	Title   string `json:"title"`
	Message string `json:"message"`
}

// RecalculateTrustScorePayload is the payload for trust score jobs.
type RecalculateTrustScorePayload struct {
	UserID string `json:"user_id"`
}

// AIRecommendationPayload is the payload for AI recommendation jobs.
type AIRecommendationPayload struct {
	UserID  string `json:"user_id"`
	EventID string `json:"event_id,omitempty"`
}

// ── Queue ──

const (
	defaultQueue      = "khair:jobs:default"
	emailQueue        = "khair:jobs:email"
	notifQueue        = "khair:jobs:notification"
	defaultMaxRetries = 3
)

// QueueName returns the Redis key for the given job type.
func QueueName(jobType string) string {
	switch jobType {
	case JobSendEmail:
		return emailQueue
	case JobCreateNotification:
		return notifQueue
	default:
		return defaultQueue
	}
}

// AllQueues returns every queue name the worker should listen on.
func AllQueues() []string {
	return []string{emailQueue, notifQueue, defaultQueue}
}

// Queue wraps a Redis client with LPUSH / BRPOP-based job queue operations.
type Queue struct {
	redis *redis.Client
}

// NewQueue creates a new job queue backed by the given Redis client.
func NewQueue(redisClient *redis.Client) *Queue {
	return &Queue{redis: redisClient}
}

// Enqueue serialises a job and pushes it to the appropriate Redis list.
func (q *Queue) Enqueue(ctx context.Context, job *Job) error {
	if job.ID == "" {
		job.ID = uuid.New().String()
	}
	if job.CreatedAt.IsZero() {
		job.CreatedAt = time.Now()
	}
	if job.MaxRetries == 0 {
		job.MaxRetries = defaultMaxRetries
	}

	data, err := json.Marshal(job)
	if err != nil {
		return fmt.Errorf("marshal job: %w", err)
	}

	queueKey := QueueName(job.Type)
	if err := q.redis.LPush(ctx, queueKey, data).Err(); err != nil {
		return fmt.Errorf("enqueue job to %s: %w", queueKey, err)
	}

	log.Printf("[QUEUE] Enqueued job %s (type=%s) to %s", job.ID, job.Type, queueKey)
	return nil
}

// EnqueueJob is a convenience wrapper that builds a Job from type + payload.
func (q *Queue) EnqueueJob(ctx context.Context, jobType string, payload interface{}) error {
	data, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal payload: %w", err)
	}
	return q.Enqueue(ctx, &Job{
		Type:    jobType,
		Payload: data,
	})
}

// Dequeue blocks for up to `timeout` waiting for a job on any of the given queues.
// It returns the job and the queue it came from, or an error.
func (q *Queue) Dequeue(ctx context.Context, timeout time.Duration, queues ...string) (*Job, string, error) {
	result, err := q.redis.BRPop(ctx, timeout, queues...).Result()
	if err != nil {
		if err == redis.Nil {
			return nil, "", nil // timeout, no job
		}
		return nil, "", fmt.Errorf("dequeue: %w", err)
	}

	// result[0] = queue name, result[1] = job JSON
	queueKey := result[0]
	var job Job
	if err := json.Unmarshal([]byte(result[1]), &job); err != nil {
		return nil, queueKey, fmt.Errorf("unmarshal job: %w", err)
	}

	return &job, queueKey, nil
}

// Retry re-enqueues a job with an incremented retry count.
// Returns false if the job has exceeded its max retries.
func (q *Queue) Retry(ctx context.Context, job *Job) (bool, error) {
	job.RetryCount++
	if job.RetryCount > job.MaxRetries {
		log.Printf("[QUEUE] Job %s (type=%s) exceeded max retries (%d), dropping", job.ID, job.Type, job.MaxRetries)
		return false, nil
	}

	log.Printf("[QUEUE] Retrying job %s (type=%s) attempt %d/%d", job.ID, job.Type, job.RetryCount, job.MaxRetries)
	return true, q.Enqueue(ctx, job)
}
