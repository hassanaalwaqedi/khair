package response

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/khair/backend/pkg/i18n"
)

const jsonContentTypeUTF8 = "application/json; charset=utf-8"

// Response represents a standard API response
type Response struct {
	Success bool        `json:"success"`
	Message string      `json:"message,omitempty"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// PaginatedResponse represents a paginated API response
type PaginatedResponse struct {
	Success    bool        `json:"success"`
	Data       interface{} `json:"data"`
	Page       int         `json:"page"`
	PageSize   int         `json:"page_size"`
	TotalCount int64       `json:"total_count"`
	TotalPages int         `json:"total_pages"`
}

// Success sends a successful response
func Success(c *gin.Context, data interface{}) {
	c.Header("Content-Type", jsonContentTypeUTF8)
	c.JSON(http.StatusOK, Response{
		Success: true,
		Data:    data,
	})
}

// SuccessWithMessage sends a successful response with a message
func SuccessWithMessage(c *gin.Context, message string, data interface{}) {
	c.Header("Content-Type", jsonContentTypeUTF8)
	c.JSON(http.StatusOK, Response{
		Success: true,
		Message: i18n.TranslateForContext(c, message),
		Data:    data,
	})
}

// Created sends a 201 response for resource creation
func Created(c *gin.Context, data interface{}) {
	c.Header("Content-Type", jsonContentTypeUTF8)
	c.JSON(http.StatusCreated, Response{
		Success: true,
		Data:    data,
	})
}

// Paginated sends a paginated response
func Paginated(c *gin.Context, data interface{}, page, pageSize int, totalCount int64) {
	c.Header("Content-Type", jsonContentTypeUTF8)
	totalPages := int(totalCount) / pageSize
	if int(totalCount)%pageSize > 0 {
		totalPages++
	}

	c.JSON(http.StatusOK, PaginatedResponse{
		Success:    true,
		Data:       data,
		Page:       page,
		PageSize:   pageSize,
		TotalCount: totalCount,
		TotalPages: totalPages,
	})
}

// Error sends an error response
func Error(c *gin.Context, statusCode int, message string) {
	c.Header("Content-Type", jsonContentTypeUTF8)
	c.JSON(statusCode, Response{
		Success: false,
		Error:   i18n.TranslateForContext(c, message),
	})
}

// BadRequest sends a 400 response
func BadRequest(c *gin.Context, message string) {
	Error(c, http.StatusBadRequest, message)
}

// Unauthorized sends a 401 response
func Unauthorized(c *gin.Context, message string) {
	Error(c, http.StatusUnauthorized, message)
}

// Forbidden sends a 403 response
func Forbidden(c *gin.Context, message string) {
	Error(c, http.StatusForbidden, message)
}

// NotFound sends a 404 response
func NotFound(c *gin.Context, message string) {
	Error(c, http.StatusNotFound, message)
}

// InternalServerError sends a 500 response
func InternalServerError(c *gin.Context, message string) {
	Error(c, http.StatusInternalServerError, message)
}

// ServiceUnavailable sends a 503 response
func ServiceUnavailable(c *gin.Context, message string) {
	Error(c, http.StatusServiceUnavailable, message)
}
