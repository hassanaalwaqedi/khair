package lifecycle

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/require"
)

func TestReadinessAllowsOptionalRedisFailure(t *testing.T) {
	gin.SetMode(gin.TestMode)

	db, mock, err := sqlmock.New(sqlmock.MonitorPingsOption(true))
	require.NoError(t, err)
	defer db.Close()
	mock.ExpectPing()

	redisClient := redis.NewClient(&redis.Options{
		Addr:        "127.0.0.1:1",
		DialTimeout: 20 * time.Millisecond,
	})
	defer redisClient.Close()

	router := gin.New()
	router.GET("/readyz", NewHealthChecker(db, redisClient).ReadinessHandler())

	request := httptest.NewRequest(http.MethodGet, "/readyz", nil)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)

	require.Equal(t, http.StatusOK, response.Code)

	var body HealthResponse
	require.NoError(t, json.Unmarshal(response.Body.Bytes(), &body))
	require.Equal(t, "ready", body.Status)
	require.Equal(t, "healthy", body.Checks["database"].Status)
	require.Equal(t, "degraded", body.Checks["redis"].Status)
	require.NotEmpty(t, body.Checks["redis"].Error)
	require.NoError(t, mock.ExpectationsWereMet())
}
