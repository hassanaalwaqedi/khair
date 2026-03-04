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
	SMTP     SMTPConfig
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

// SMTPConfig holds SMTP email configuration
type SMTPConfig struct {
	Host         string
	Port         int
	User         string
	Pass         string
	From         string
	SendGridKey  string
	SendGridFrom string
}

// Load loads configuration from environment variables
func Load() *Config {
	return &Config{
		Server: ServerConfig{
			Port: getEnv("SERVER_PORT", "8080"),
			Mode: getEnv("GIN_MODE", "debug"),
		},
		Database: DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "5432"),
			User:     getEnv("DB_USER", "khair"),
			Password: requireEnv("DB_PASSWORD"),
			DBName:   getEnv("DB_NAME", "khair"),
			SSLMode:  getEnv("DB_SSLMODE", "disable"),
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
			Model:     getEnv("GEMINI_MODEL", "gemini-2.0-flash"),
			MaxTokens: getEnvAsInt("GEMINI_MAX_TOKENS", 1024),
			Enabled:   getEnv("GEMINI_API_KEY", "") != "",
		},
		SMTP: SMTPConfig{
			Host:         strings.TrimSpace(getEnv("SMTP_HOST", "")),
			Port:         getEnvAsInt("SMTP_PORT", 587),
			User:         strings.TrimSpace(getEnv("SMTP_USER", "")),
			Pass:         strings.TrimSpace(getEnv("SMTP_PASS", "")),
			From:         strings.TrimSpace(getEnv("SMTP_FROM", "")),
			SendGridKey:  strings.TrimSpace(getEnv("SENDGRID_API_KEY", "")),
			SendGridFrom: strings.TrimSpace(getEnv("SENDGRID_FROM", getEnv("SMTP_FROM", ""))),
		},
	}
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
