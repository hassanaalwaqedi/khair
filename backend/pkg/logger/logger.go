package logger

import (
	"io"
	"os"
	"time"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

// Logger wraps zerolog with convenience methods
type Logger struct {
	logger zerolog.Logger
}

// Config holds logger configuration
type Config struct {
	Level      string // debug, info, warn, error
	Pretty     bool   // Enable human-readable console output
	TimeFormat string // Default: RFC3339
}

// New creates a new structured logger
func New(cfg Config) *Logger {
	// Parse log level
	level := zerolog.InfoLevel
	switch cfg.Level {
	case "debug":
		level = zerolog.DebugLevel
	case "info":
		level = zerolog.InfoLevel
	case "warn":
		level = zerolog.WarnLevel
	case "error":
		level = zerolog.ErrorLevel
	}

	// Configure output format
	var output io.Writer = os.Stdout
	if cfg.Pretty {
		output = zerolog.ConsoleWriter{
			Out:        os.Stdout,
			TimeFormat: time.RFC3339,
		}
	}

	// Set time format
	if cfg.TimeFormat == "" {
		cfg.TimeFormat = time.RFC3339
	}
	zerolog.TimeFieldFormat = cfg.TimeFormat

	// Create logger
	logger := zerolog.New(output).
		Level(level).
		With().
		Timestamp().
		Logger()

	// Set global logger
	log.Logger = logger

	return &Logger{logger: logger}
}

// Info logs an informational message
func (l *Logger) Info(msg string, fields ...Field) {
	event := l.logger.Info()
	for _, field := range fields {
		field.apply(event)
	}
	event.Msg(msg)
}

// Error logs an error message
func (l *Logger) Error(msg string, err error, fields ...Field) {
	event := l.logger.Error()
	if err != nil {
		event = event.Err(err)
	}
	for _, field := range fields {
		field.apply(event)
	}
	event.Msg(msg)
}

// Warn logs a warning message
func (l *Logger) Warn(msg string, fields ...Field) {
	event := l.logger.Warn()
	for _, field := range fields {
		field.apply(event)
	}
	event.Msg(msg)
}

// Debug logs a debug message
func (l *Logger) Debug(msg string, fields ...Field) {
	event := l.logger.Debug()
	for _, field := range fields {
		field.apply(event)
	}
	event.Msg(msg)
}

// Fatal logs a fatal error and exits
func (l *Logger) Fatal(msg string, err error, fields ...Field) {
	event := l.logger.Fatal()
	if err != nil {
		event = event.Err(err)
	}
	for _, field := range fields {
		field.apply(event)
	}
	event.Msg(msg)
}

// Field represents a structured log field
type Field struct {
	key   string
	value interface{}
}

func (f Field) apply(event *zerolog.Event) {
	event.Interface(f.key, f.value)
}

// String creates a string field
func String(key, value string) Field {
	return Field{key: key, value: value}
}

// Int creates an int field
func Int(key string, value int) Field {
	return Field{key: key, value: value}
}

// Any creates a field with any value
func Any(key string, value interface{}) Field {
	return Field{key: key, value: value}
}
