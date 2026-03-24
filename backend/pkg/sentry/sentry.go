package sentry

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	sentry "github.com/getsentry/sentry-go"
	sentrygin "github.com/getsentry/sentry-go/gin"
)

// Init initialises the Sentry SDK if SENTRY_DSN is set.
// Call this early in main(). Returns a cleanup function for defer.
func Init() func() {
	dsn := os.Getenv("SENTRY_DSN")
	if dsn == "" {
		log.Println("[SENTRY] No SENTRY_DSN set — error tracking disabled")
		return func() {}
	}

	env := "production"
	if os.Getenv("GIN_MODE") != "release" {
		env = "development"
	}

	err := sentry.Init(sentry.ClientOptions{
		Dsn:              dsn,
		Environment:      env,
		TracesSampleRate: 0.3,
		Release:          fmt.Sprintf("khair-api@%s", os.Getenv("APP_VERSION")),
	})
	if err != nil {
		log.Printf("[SENTRY] Init failed: %v", err)
		return func() {}
	}

	log.Printf("[SENTRY] Initialised (env=%s)", env)
	return func() {
		sentry.Flush(2 * time.Second)
	}
}

// Middleware returns a Gin middleware that captures panics and errors.
func Middleware() gin.HandlerFunc {
	if os.Getenv("SENTRY_DSN") == "" {
		return func(c *gin.Context) { c.Next() }
	}

	return sentrygin.New(sentrygin.Options{
		Repanic: true, // re-panic after capture so Gin's recovery can handle it
	})
}
