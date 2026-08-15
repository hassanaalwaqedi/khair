package ai

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

func TestHandler_Status(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.Default()

	// Provide empty struct or mocked struct
	client := &Client{}
	handler := NewHandler(nil, nil, nil, client)

	router.GET("/ai/status", handler.Status)

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/ai/status", nil)
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
}
