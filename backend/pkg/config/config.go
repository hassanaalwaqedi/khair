package config

import (
	"log"
	"os"
	"strconv"
	"strings"
)

// Config holds all configuration for the application
type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	Redis    RedisConfig
	JWT      JWTConfig
	Logger   LoggerConfig
	Gemini   GeminiConfig
	Email    EmailConfig
	Google   GoogleConfig
}

// ServerConfig holds server-related configuration
type ServerConfig struct {
	Port string
	Mode string
}

// DatabaseConfig holds database connection configuration
type DatabaseConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	SSLMode  string
}

// RedisConfig holds Redis connection configuration
type RedisConfig struct {
	Host     string
	Port     string
	Password string
	DB       int
	Addr     string
}

// JWTConfig holds JWT-related configuration
type JWTConfig struct {
	Secret      string
	ExpiryHours int
}

// LoggerConfig holds logging configuration
type LoggerConfig struct {
	Level  string
	Pretty bool
}

// GeminiConfig holds Gemini AI configuration
type GeminiConfig struct {
	APIKey    string
	Model     string
	MaxTokens int
	Enabled   bool
}

// EmailConfig holds email provider configuration.
// Supports Resend (preferred) and SendGrid (fallback).
type EmailConfig struct {
	Provider     string // "resend" or "sendgrid"
	ResendKey    string
	SendGridKey  string
	SendGridFrom string
	FromEmail    string
	FromName     string
	BrandLogoURL string
}

// GoogleConfig contains the OAuth audience expected on Google ID tokens.
// The mobile/web client IDs stay public; token verification always happens on
// the API with this server-side audience check.
type GoogleConfig struct {
	ClientID string
}

// Load loads configuration from environment variables
func Load() *Config {
	cfg := &Config{
		Server: ServerConfig{
			// Render injects PORT. SERVER_PORT remains available for Docker and local development.
			Port: getEnv("PORT", getEnv("SERVER_PORT", "8080")),
			Mode: getEnv("GIN_MODE", "debug"),
		},
		Database: DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "5432"),
			User:     getEnv("DB_USER", "khair"),
			Password: requireEnv("DB_PASSWORD"),
			DBName:   getEnv("DB_NAME", "khair"),
			SSLMode:  getEnv("DB_SSLMODE", "require"),
		},
		Redis: RedisConfig{
			Host:     getEnv("REDIS_HOST", "localhost"),
			Port:     getEnv("REDIS_PORT", "6379"),
			Password: getEnv("REDIS_PASSWORD", ""),
			DB:       getEnvAsInt("REDIS_DB", 0),
			Addr:     getEnv("REDIS_HOST", "localhost") + ":" + getEnv("REDIS_PORT", "6379"),
		},
		JWT: JWTConfig{
			Secret:      requireEnv("JWT_SECRET"),
			ExpiryHours: getEnvAsInt("JWT_EXPIRY_HOURS", 24),
		},
		Logger: LoggerConfig{
			Level:  getEnv("LOG_LEVEL", "info"),
			Pretty: getEnv("LOG_PRETTY", "false") == "true",
		},
		Gemini: GeminiConfig{
			APIKey:    getEnv("GEMINI_API_KEY", ""),
			Model:     getEnv("GEMINI_MODEL", "gemini-2.5-flash"),
			MaxTokens: getEnvAsInt("GEMINI_MAX_TOKENS", 1024),
			Enabled:   getEnv("GEMINI_API_KEY", "") != "",
		},
		Email: buildEmailConfig(),
		Google: GoogleConfig{
			ClientID: strings.TrimSpace(getEnv("GOOGLE_OAUTH_CLIENT_ID", "")),
		},
	}

	// Validate JWT secret security — refuse to start with a weak secret
	if len(cfg.JWT.Secret) < 32 {
		log.Fatalf("FATAL: JWT_SECRET must be at least 32 characters for security (got %d)", len(cfg.JWT.Secret))
	}

	return cfg
}

// getEnv gets an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultValue
}

// getEnvAsInt gets an environment variable as an integer or returns a default value
func getEnvAsInt(key string, defaultValue int) int {
	if value, exists := os.LookupEnv(key); exists {
		if intVal, err := strconv.Atoi(value); err == nil {
			return intVal
		}
	}
	return defaultValue
}

// requireEnv gets a required environment variable or fatally exits
func requireEnv(key string) string {
	value, exists := os.LookupEnv(key)
	if !exists || value == "" {
		log.Fatalf("FATAL: required environment variable %s is not set", key)
	}
	return value
}

// buildEmailConfig configures the email provider.
// Priority: RESEND_API_KEY → SENDGRID_API_KEY → disabled.
func buildEmailConfig() EmailConfig {
	fromEmail := strings.TrimSpace(getEnv("EMAIL_FROM", getEnv("SENDGRID_FROM", "no-reply@khair.it.com")))
	fromName := strings.TrimSpace(getEnv("EMAIL_FROM_NAME", "Khair Platform"))
	publicBaseURL := strings.TrimRight(getEnv("PUBLIC_BASE_URL", "https://api.khair.it.com"), "/")
	brandLogoURL := strings.TrimSpace(getEnv("KHAIR_BRAND_LOGO_URL", publicBaseURL+"/brand/khair-logo.png"))

	resendKey := strings.TrimSpace(getEnv("RESEND_API_KEY", ""))
	if resendKey != "" {
		return EmailConfig{
			Provider:     "resend",
			ResendKey:    resendKey,
			FromEmail:    fromEmail,
			FromName:     fromName,
			BrandLogoURL: brandLogoURL,
		}
	}

	sgKey := strings.TrimSpace(getEnv("SENDGRID_API_KEY", ""))
	return EmailConfig{
		Provider:     "sendgrid",
		SendGridKey:  sgKey,
		SendGridFrom: fromEmail,
		FromEmail:    fromEmail,
		FromName:     fromName,
		BrandLogoURL: brandLogoURL,
	}
}
