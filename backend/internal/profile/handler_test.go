package profile

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	_ "github.com/lib/pq"
)

func TestUpdateProfileError(t *testing.T) {
	db, err := sql.Open("postgres", "postgresql://postgres.ulwubufgyodwmajbsfsw:As717801454%2A@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres")
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	// Insert a test user
	uid := uuid.New()
	_, err = db.Exec("INSERT INTO users (id, email, password_hash, role) VALUES ($1, $2, 'hash', 'user')", uid, uid.String()+"@example.com")
	if err != nil {
		t.Fatal(err)
	}
	defer db.Exec("DELETE FROM users WHERE id = $1", uid)

	handler := NewHandler(db, nil, nil)
	
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.PUT("/profile", func(c *gin.Context) {
		c.Set("user_id", uid)
		handler.UpdateProfile(c)
	})

	updateReq := map[string]interface{}{
		"display_name": "Updated Name",
		"country": "US",
		"city": "NY",
		"preferred_language": "en",
		"gender": "NOT_SET",
		"confirm_eligibility_impact": false,
	}
	updateBytes, _ := json.Marshal(updateReq)

	req, _ := http.NewRequest("PUT", "/profile", bytes.NewReader(updateBytes))
	req.Header.Set("Content-Type", "application/json")
	
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	
	if w.Code != http.StatusOK {
		t.Fatalf("Update failed: %d - %s", w.Code, w.Body.String())
	}
}
