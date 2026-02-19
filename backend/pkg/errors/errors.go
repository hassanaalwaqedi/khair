package errors

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// Code represents an error code
type Code string

const (
	CodeBadRequest       Code = "BAD_REQUEST"
	CodeUnauthorized     Code = "UNAUTHORIZED"
	CodeForbidden        Code = "FORBIDDEN"
	CodeNotFound         Code = "NOT_FOUND"
	CodeConflict         Code = "CONFLICT"
	CodeValidation       Code = "VALIDATION_ERROR"
	CodeRateLimit        Code = "RATE_LIMIT_EXCEEDED"
	CodeInternal         Code = "INTERNAL_ERROR"
	CodeServiceUnavail   Code = "SERVICE_UNAVAILABLE"
	CodeFeatureDisabled  Code = "FEATURE_DISABLED"
	CodeInsufficientPerm Code = "INSUFFICIENT_PERMISSIONS"
)

// AppError represents an application error
type AppError struct {
	HTTPStatus int         `json:"-"`
	Code       Code        `json:"code"`
	Message    string      `json:"message"`
	Details    interface{} `json:"details,omitempty"`
	Internal   error       `json:"-"`
}

// Error implements error interface
func (e *AppError) Error() string {
	return e.Message
}

// Response formats error for HTTP response
func (e *AppError) Response(c *gin.Context, isProduction bool) {
	resp := gin.H{
		"success": false,
		"error":   e.Message,
		"code":    e.Code,
	}

	if e.Details != nil {
		resp["details"] = e.Details
	}

	// Only include internal error in development
	if !isProduction && e.Internal != nil {
		resp["internal_error"] = e.Internal.Error()
	}

	// Add request ID if available
	if requestID, exists := c.Get("request_id"); exists {
		resp["request_id"] = requestID
	}

	c.JSON(e.HTTPStatus, resp)
}

// Common error constructors
func BadRequest(message string) *AppError {
	return &AppError{
		HTTPStatus: http.StatusBadRequest,
		Code:       CodeBadRequest,
		Message:    message,
	}
}

func Unauthorized(message string) *AppError {
	if message == "" {
		message = "Authentication required"
	}
	return &AppError{
		HTTPStatus: http.StatusUnauthorized,
		Code:       CodeUnauthorized,
		Message:    message,
	}
}

func Forbidden(message string) *AppError {
	if message == "" {
		message = "Access denied"
	}
	return &AppError{
		HTTPStatus: http.StatusForbidden,
		Code:       CodeForbidden,
		Message:    message,
	}
}

func NotFound(resource string) *AppError {
	return &AppError{
		HTTPStatus: http.StatusNotFound,
		Code:       CodeNotFound,
		Message:    resource + " not found",
	}
}

func Conflict(message string) *AppError {
	return &AppError{
		HTTPStatus: http.StatusConflict,
		Code:       CodeConflict,
		Message:    message,
	}
}

func ValidationError(details interface{}) *AppError {
	return &AppError{
		HTTPStatus: http.StatusBadRequest,
		Code:       CodeValidation,
		Message:    "Validation failed",
		Details:    details,
	}
}

func RateLimitExceeded() *AppError {
	return &AppError{
		HTTPStatus: http.StatusTooManyRequests,
		Code:       CodeRateLimit,
		Message:    "Too many requests. Please try again later.",
	}
}

func Internal(err error) *AppError {
	return &AppError{
		HTTPStatus: http.StatusInternalServerError,
		Code:       CodeInternal,
		Message:    "An internal error occurred",
		Internal:   err,
	}
}

func ServiceUnavailable(service string) *AppError {
	return &AppError{
		HTTPStatus: http.StatusServiceUnavailable,
		Code:       CodeServiceUnavail,
		Message:    service + " is temporarily unavailable",
	}
}

func FeatureDisabled(feature string) *AppError {
	return &AppError{
		HTTPStatus: http.StatusServiceUnavailable,
		Code:       CodeFeatureDisabled,
		Message:    feature + " is currently disabled",
	}
}

// ErrorHandlerMiddleware provides consistent error handling
func ErrorHandlerMiddleware(isProduction bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()

		// Check for errors
		if len(c.Errors) > 0 {
			err := c.Errors.Last().Err

			if appErr, ok := err.(*AppError); ok {
				appErr.Response(c, isProduction)
				return
			}

			// Generic error
			Internal(err).Response(c, isProduction)
		}
	}
}

// Success sends a success response
func Success(c *gin.Context, data interface{}, message ...string) {
	resp := gin.H{
		"success": true,
		"data":    data,
	}

	if len(message) > 0 {
		resp["message"] = message[0]
	}

	c.JSON(http.StatusOK, resp)
}

// Created sends a created response
func Created(c *gin.Context, data interface{}, message ...string) {
	resp := gin.H{
		"success": true,
		"data":    data,
	}

	if len(message) > 0 {
		resp["message"] = message[0]
	}

	c.JSON(http.StatusCreated, resp)
}

// NoContent sends a no content response
func NoContent(c *gin.Context) {
	c.Status(http.StatusNoContent)
}
