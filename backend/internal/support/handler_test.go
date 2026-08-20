package support_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/khair/backend/internal/support"
	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
)

func mockAuthMiddleware(userID uuid.UUID, roles []string) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Match the production AuthMiddleware contract. A UUID, rather than its
		// string representation, is placed in the Gin context after JWT validation.
		c.Set("user_id", userID)
		c.Set("roles", roles)
		c.Next()
	}
}

func mockAdminMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()
	}
}

func TestHandler_StartSessionAcceptsUUIDAuthContext(t *testing.T) {
	// Skip detailed implementation for brevity, testing HTTP response shape
	gin.SetMode(gin.TestMode)
	
	db, _, _ := sqlmock.New()
	defer db.Close()
	repo := support.NewRepository(db)
	svc := support.NewService(repo, nil, nil, nil, db)
	handler := support.NewHandler(svc)
	
	r := gin.New()
	userID := uuid.New()
	handler.RegisterRoutes(r.Group("/api/v1"), mockAuthMiddleware(userID, []string{"user"}), mockAdminMiddleware())

	reqBody, _ := json.Marshal(map[string]string{
		"category": "General",
		"subject":  "Help me",
	})
	
	req, _ := http.NewRequest(http.MethodPost, "/api/v1/support/sessions", bytes.NewBuffer(reqBody))
	w := httptest.NewRecorder()
	
	// The database has no mocked expectations, so this deliberately returns 500
	// after reaching the handler. It must not return 401: production auth stores
	// user_id as uuid.UUID in Gin context.
	r.ServeHTTP(w, req)
	
	assert.Equal(t, http.StatusInternalServerError, w.Code) // Expected without a real DB mock
}

func TestHandler_AdminGetTickets(t *testing.T) {
	gin.SetMode(gin.TestMode)
	
	db, _, _ := sqlmock.New()
	defer db.Close()
	repo := support.NewRepository(db)
	svc := support.NewService(repo, nil, nil, nil, db)
	handler := support.NewHandler(svc)
	
	r := gin.New()
	userID := uuid.New()
	// No support_agent role
	handler.RegisterRoutes(r.Group("/api/v1"), mockAuthMiddleware(userID, []string{"user"}), mockAdminMiddleware())

	req, _ := http.NewRequest(http.MethodGet, "/api/v1/admin/support/tickets", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	
	// Should be forbidden because user lacks support_agent
	assert.Equal(t, http.StatusForbidden, w.Code)
}
