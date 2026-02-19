package ratelimit

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
)

// Config holds rate limit configuration
type Config struct {
	// Per-IP limits (for guests)
	IPLimit    int           `json:"ip_limit"`
	IPWindow   time.Duration `json:"ip_window"`
	
	// Per-account limits (for authenticated users)
	AccountLimit  int           `json:"account_limit"`
	AccountWindow time.Duration `json:"account_window"`
}

// DefaultConfigs for different actions
var DefaultConfigs = map[string]Config{
	"event_create": {
		IPLimit:       5,
		IPWindow:      time.Hour,
		AccountLimit:  10,
		AccountWindow: 24 * time.Hour,
	},
	"event_edit": {
		IPLimit:       10,
		IPWindow:      time.Hour,
		AccountLimit:  30,
		AccountWindow: 24 * time.Hour,
	},
	"report_submit": {
		IPLimit:       10,
		IPWindow:      time.Hour,
		AccountLimit:  20,
		AccountWindow: 24 * time.Hour,
	},
	"organizer_action": {
		IPLimit:       20,
		IPWindow:      time.Hour,
		AccountLimit:  50,
		AccountWindow: 24 * time.Hour,
	},
	"default": {
		IPLimit:       100,
		IPWindow:      time.Hour,
		AccountLimit:  200,
		AccountWindow: 24 * time.Hour,
	},
}

// Limiter provides rate limiting functionality backed by Redis
type Limiter struct {
	redis   *redis.Client
	configs map[string]Config
}

// NewLimiter creates a new rate limiter
func NewLimiter(redisClient *redis.Client) *Limiter {
	return &Limiter{
		redis:   redisClient,
		configs: DefaultConfigs,
	}
}

// SetConfig sets a custom config for an action
func (l *Limiter) SetConfig(action string, config Config) {
	l.configs[action] = config
}

// GetConfig retrieves config for an action
func (l *Limiter) GetConfig(action string) Config {
	if config, ok := l.configs[action]; ok {
		return config
	}
	return l.configs["default"]
}

// CheckLimit checks if the request is within rate limits
func (l *Limiter) CheckLimit(ctx context.Context, action string, identifier string, isAccount bool) (bool, int, error) {
	config := l.GetConfig(action)
	
	var limit int
	var window time.Duration
	var keyPrefix string
	
	if isAccount {
		limit = config.AccountLimit
		window = config.AccountWindow
		keyPrefix = "rl:acc"
	} else {
		limit = config.IPLimit
		window = config.IPWindow
		keyPrefix = "rl:ip"
	}
	
	key := fmt.Sprintf("%s:%s:%s", keyPrefix, action, identifier)
	
	// Get current count
	count, err := l.redis.Get(ctx, key).Int()
	if err != nil && err != redis.Nil {
		return false, 0, err
	}
	
	remaining := limit - count
	if remaining < 0 {
		remaining = 0
	}
	
	if count >= limit {
		return false, remaining, nil
	}
	
	// Increment counter
	pipe := l.redis.Pipeline()
	pipe.Incr(ctx, key)
	pipe.Expire(ctx, key, window)
	_, err = pipe.Exec(ctx)
	if err != nil {
		return false, remaining, err
	}
	
	return true, remaining - 1, nil
}

// Middleware returns a Gin middleware for rate limiting
func (l *Limiter) Middleware(action string) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		
		// Get identifier - prefer account ID if available
		var identifier string
		var isAccount bool
		
		if userID, exists := c.Get("userID"); exists && userID != nil {
			identifier = fmt.Sprintf("%v", userID)
			isAccount = true
		} else {
			identifier = c.ClientIP()
			isAccount = false
		}
		
		allowed, remaining, err := l.CheckLimit(ctx, action, identifier, isAccount)
		if err != nil {
			// On Redis error, allow the request but log
			c.Next()
			return
		}
		
		// Set rate limit headers
		config := l.GetConfig(action)
		var limit int
		if isAccount {
			limit = config.AccountLimit
		} else {
			limit = config.IPLimit
		}
		
		c.Header("X-RateLimit-Limit", fmt.Sprintf("%d", limit))
		c.Header("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
		
		if !allowed {
			c.Header("Retry-After", "3600")
			c.JSON(http.StatusTooManyRequests, gin.H{
				"success": false,
				"error":   "Rate limit exceeded",
				"message": "Too many requests. Please try again later.",
			})
			c.Abort()
			return
		}
		
		c.Next()
	}
}

// RateLimitInfo holds current rate limit status
type RateLimitInfo struct {
	Action     string `json:"action"`
	Limit      int    `json:"limit"`
	Remaining  int    `json:"remaining"`
	ResetTime  int64  `json:"reset_time"`
	IsBlocked  bool   `json:"is_blocked"`
}

// GetStatus retrieves current rate limit status for an identifier
func (l *Limiter) GetStatus(ctx context.Context, action string, identifier string, isAccount bool) (*RateLimitInfo, error) {
	config := l.GetConfig(action)
	
	var limit int
	var keyPrefix string
	
	if isAccount {
		limit = config.AccountLimit
		keyPrefix = "rl:acc"
	} else {
		limit = config.IPLimit
		keyPrefix = "rl:ip"
	}
	
	key := fmt.Sprintf("%s:%s:%s", keyPrefix, action, identifier)
	
	count, err := l.redis.Get(ctx, key).Int()
	if err != nil && err != redis.Nil {
		return nil, err
	}
	
	ttl, err := l.redis.TTL(ctx, key).Result()
	if err != nil {
		ttl = 0
	}
	
	remaining := limit - count
	if remaining < 0 {
		remaining = 0
	}
	
	return &RateLimitInfo{
		Action:    action,
		Limit:     limit,
		Remaining: remaining,
		ResetTime: time.Now().Add(ttl).Unix(),
		IsBlocked: count >= limit,
	}, nil
}

// Reset resets the rate limit for an identifier (admin action)
func (l *Limiter) Reset(ctx context.Context, action string, identifier string, isAccount bool) error {
	var keyPrefix string
	if isAccount {
		keyPrefix = "rl:acc"
	} else {
		keyPrefix = "rl:ip"
	}
	
	key := fmt.Sprintf("%s:%s:%s", keyPrefix, action, identifier)
	return l.redis.Del(ctx, key).Err()
}
