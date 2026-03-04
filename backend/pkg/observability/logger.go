package observability

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"runtime"
	"sync"
	"time"

	"github.com/google/uuid"
)

// LogLevel represents logging severity
type LogLevel int

const (
	DEBUG LogLevel = iota
	INFO
	WARN
	ERROR
	FATAL
)

func (l LogLevel) String() string {
	switch l {
	case DEBUG:
		return "DEBUG"
	case INFO:
		return "INFO"
	case WARN:
		return "WARN"
	case ERROR:
		return "ERROR"
	case FATAL:
		return "FATAL"
	default:
		return "UNKNOWN"
	}
}

// LogEntry represents a structured log entry
type LogEntry struct {
	Timestamp  string                 `json:"timestamp"`
	Level      string                 `json:"level"`
	Message    string                 `json:"message"`
	RequestID  string                 `json:"request_id,omitempty"`
	TraceID    string                 `json:"trace_id,omitempty"`
	Service    string                 `json:"service"`
	Component  string                 `json:"component,omitempty"`
	Error      string                 `json:"error,omitempty"`
	Stack      string                 `json:"stack,omitempty"`
	Duration   float64                `json:"duration_ms,omitempty"`
	StatusCode int                    `json:"status_code,omitempty"`
	Method     string                 `json:"method,omitempty"`
	Path       string                 `json:"path,omitempty"`
	UserID     string                 `json:"user_id,omitempty"`
	IP         string                 `json:"ip,omitempty"`
	Fields     map[string]interface{} `json:"fields,omitempty"`
}

// Logger provides structured logging
type Logger struct {
	mu          sync.Mutex
	output      io.Writer
	level       LogLevel
	service     string
	environment string
}

var (
	defaultLogger *Logger
	once          sync.Once
)

// NewLogger creates a new logger instance
func NewLogger(service, environment string, level LogLevel) *Logger {
	return &Logger{
		output:      os.Stdout,
		level:       level,
		service:     service,
		environment: environment,
	}
}

// Default returns the default logger instance
func Default() *Logger {
	once.Do(func() {
		env := os.Getenv("ENV")
		if env == "" {
			env = "development"
		}
		level := INFO
		if env == "development" {
			level = DEBUG
		}
		defaultLogger = NewLogger("khair-api", env, level)
	})
	return defaultLogger
}

// SetOutput sets the logger output
func (l *Logger) SetOutput(w io.Writer) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.output = w
}

// SetLevel sets the minimum log level
func (l *Logger) SetLevel(level LogLevel) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.level = level
}

// log writes a log entry
func (l *Logger) log(level LogLevel, msg string, fields map[string]interface{}) {
	if level < l.level {
		return
	}

	l.mu.Lock()
	defer l.mu.Unlock()

	entry := LogEntry{
		Timestamp: time.Now().UTC().Format(time.RFC3339Nano),
		Level:     level.String(),
		Message:   msg,
		Service:   l.service,
		Fields:    fields,
	}

	// Extract special fields
	if fields != nil {
		if requestID, ok := fields["request_id"].(string); ok {
			entry.RequestID = requestID
			delete(fields, "request_id")
		}
		if traceID, ok := fields["trace_id"].(string); ok {
			entry.TraceID = traceID
			delete(fields, "trace_id")
		}
		if component, ok := fields["component"].(string); ok {
			entry.Component = component
			delete(fields, "component")
		}
		if err, ok := fields["error"].(string); ok {
			entry.Error = err
			delete(fields, "error")
		}
		if err, ok := fields["error"].(error); ok {
			entry.Error = err.Error()
			delete(fields, "error")
		}
		if duration, ok := fields["duration_ms"].(float64); ok {
			entry.Duration = duration
			delete(fields, "duration_ms")
		}
		if statusCode, ok := fields["status_code"].(int); ok {
			entry.StatusCode = statusCode
			delete(fields, "status_code")
		}
		if method, ok := fields["method"].(string); ok {
			entry.Method = method
			delete(fields, "method")
		}
		if path, ok := fields["path"].(string); ok {
			entry.Path = path
			delete(fields, "path")
		}
		if userID, ok := fields["user_id"].(string); ok {
			entry.UserID = userID
			delete(fields, "user_id")
		}
		if ip, ok := fields["ip"].(string); ok {
			entry.IP = ip
			delete(fields, "ip")
		}
	}

	// Add stack trace for errors
	if level >= ERROR {
		buf := make([]byte, 4096)
		n := runtime.Stack(buf, false)
		entry.Stack = string(buf[:n])
	}

	data, err := json.Marshal(entry)
	if err != nil {
		fmt.Fprintf(l.output, `{"error":"failed to marshal log entry: %s"}`+"\n", err)
		return
	}

	l.output.Write(data)
	l.output.Write([]byte("\n"))
}

// Debug logs a debug message
func (l *Logger) Debug(msg string, fields ...map[string]interface{}) {
	f := map[string]interface{}{}
	if len(fields) > 0 {
		f = fields[0]
	}
	l.log(DEBUG, msg, f)
}

// Info logs an info message
func (l *Logger) Info(msg string, fields ...map[string]interface{}) {
	f := map[string]interface{}{}
	if len(fields) > 0 {
		f = fields[0]
	}
	l.log(INFO, msg, f)
}

// Warn logs a warning message
func (l *Logger) Warn(msg string, fields ...map[string]interface{}) {
	f := map[string]interface{}{}
	if len(fields) > 0 {
		f = fields[0]
	}
	l.log(WARN, msg, f)
}

// Error logs an error message
func (l *Logger) Error(msg string, fields ...map[string]interface{}) {
	f := map[string]interface{}{}
	if len(fields) > 0 {
		f = fields[0]
	}
	l.log(ERROR, msg, f)
}

// Fatal logs a fatal message and exits
func (l *Logger) Fatal(msg string, fields ...map[string]interface{}) {
	f := map[string]interface{}{}
	if len(fields) > 0 {
		f = fields[0]
	}
	l.log(FATAL, msg, f)
	os.Exit(1)
}

// WithContext returns a logger with context fields
func (l *Logger) WithContext(ctx context.Context) *ContextLogger {
	return &ContextLogger{
		logger: l,
		ctx:    ctx,
	}
}

// ContextLogger wraps logger with context
type ContextLogger struct {
	logger *Logger
	ctx    context.Context
}

// getContextFields extracts fields from context
func (cl *ContextLogger) getContextFields() map[string]interface{} {
	fields := map[string]interface{}{}

	if requestID := cl.ctx.Value(RequestIDKey); requestID != nil {
		fields["request_id"] = requestID.(string)
	}
	if traceID := cl.ctx.Value(TraceIDKey); traceID != nil {
		fields["trace_id"] = traceID.(string)
	}
	if userID := cl.ctx.Value(UserIDKey); userID != nil {
		fields["user_id"] = userID.(string)
	}

	return fields
}

func (cl *ContextLogger) Debug(msg string, fields ...map[string]interface{}) {
	f := cl.getContextFields()
	if len(fields) > 0 {
		for k, v := range fields[0] {
			f[k] = v
		}
	}
	cl.logger.log(DEBUG, msg, f)
}

func (cl *ContextLogger) Info(msg string, fields ...map[string]interface{}) {
	f := cl.getContextFields()
	if len(fields) > 0 {
		for k, v := range fields[0] {
			f[k] = v
		}
	}
	cl.logger.log(INFO, msg, f)
}

func (cl *ContextLogger) Warn(msg string, fields ...map[string]interface{}) {
	f := cl.getContextFields()
	if len(fields) > 0 {
		for k, v := range fields[0] {
			f[k] = v
		}
	}
	cl.logger.log(WARN, msg, f)
}

func (cl *ContextLogger) Error(msg string, fields ...map[string]interface{}) {
	f := cl.getContextFields()
	if len(fields) > 0 {
		for k, v := range fields[0] {
			f[k] = v
		}
	}
	cl.logger.log(ERROR, msg, f)
}

// Context keys
type contextKey string

const (
	RequestIDKey contextKey = "request_id"
	TraceIDKey   contextKey = "trace_id"
	UserIDKey    contextKey = "user_id"
)

// GenerateRequestID creates a new request ID
func GenerateRequestID() string {
	return uuid.New().String()[:8]
}

// WithRequestID adds request ID to context
func WithRequestID(ctx context.Context, requestID string) context.Context {
	return context.WithValue(ctx, RequestIDKey, requestID)
}

// WithTraceID adds trace ID to context
func WithTraceID(ctx context.Context, traceID string) context.Context {
	return context.WithValue(ctx, TraceIDKey, traceID)
}

// WithUserID adds user ID to context
func WithUserID(ctx context.Context, userID string) context.Context {
	return context.WithValue(ctx, UserIDKey, userID)
}

// GetRequestID retrieves request ID from context
func GetRequestID(ctx context.Context) string {
	if id := ctx.Value(RequestIDKey); id != nil {
		return id.(string)
	}
	return ""
}
