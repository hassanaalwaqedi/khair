package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"github.com/joho/godotenv"
	"github.com/khair/backend/pkg/middleware"
)

const baseURL = "http://localhost:8080/api/v1"

func main() {
	_ = godotenv.Load(".env")

	// 1. Get an auth token for testing
	token := loginUser()

	fmt.Println("==================================================")
	fmt.Println("KHAIR AI INTEGRATION RELIABILITY & STRESS TEST")
	fmt.Println("==================================================")

	// A. Stress test generic generation (Moderate Text as a proxy for generation)
	fmt.Println("\n--- Testing Moderation Service (20 requests) ---")
	testModeration(token, 20)

	// B. Support Agent Context Growth and Stress Test
	fmt.Println("\n--- Testing Support Agent Context Growth & Stress (30 messages) ---")
	testSupportAgent(token, 30)

	// C. Support Agent Rapid Concurrent Test
	fmt.Println("\n--- Testing Support Agent Rapid Concurrency (3 rapid messages) ---")
	testSupportAgentRapid(token)

	fmt.Println("\n✅ AI STRESS TEST COMPLETE.")
}

func loginUser() string {
	ctx := context.Background()
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgresql://postgres.ulwubufgyodwmajbsfsw:As717801454%2A@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres?sslmode=require"
	}
	conn, err := pgx.Connect(ctx, dbURL)
	if err != nil {
		log.Fatalf("DB connect: %v", err)
	}
	defer conn.Close(ctx)

	var userID, email, role string
	err = conn.QueryRow(ctx, "SELECT id, email, role FROM users WHERE is_verified = true LIMIT 1").Scan(&userID, &email, &role)
	if err != nil {
		log.Fatalf("Query user: %v", err)
	}

	claims := &middleware.Claims{
		UserID: userID,
		Email:  email,
		Role:   role,
		Roles:  []string{role},
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "khair",
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	secret := os.Getenv("JWT_SECRET")
	t, err := token.SignedString([]byte(secret))
	if err != nil {
		log.Fatalf("Sign token: %v", err)
	}
	return t
}

func testModeration(token string, count int) {
	success := 0
	fails := 0
	var latencies []time.Duration

	for i := 1; i <= count; i++ {
		start := time.Now()
		reqBody := map[string]string{"text": fmt.Sprintf("Hello, is this appropriate content? Attempt %d", i)}
		b, _ := json.Marshal(reqBody)
		req, _ := http.NewRequest("POST", baseURL+"/me/profile/moderate", bytes.NewReader(b))
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Content-Type", "application/json")

		resp, err := http.DefaultClient.Do(req)
		latency := time.Since(start)
		latencies = append(latencies, latency)

		if err == nil && resp.StatusCode == http.StatusOK {
			success++
		} else {
			fails++
		}
		if resp != nil {
			resp.Body.Close()
		}
		time.Sleep(500 * time.Millisecond) // slight delay to not trigger basic rate limit too aggressively
	}
	
	avg := time.Duration(0)
	for _, l := range latencies {
		avg += l
	}
	if len(latencies) > 0 {
		avg /= time.Duration(len(latencies))
	}
	fmt.Printf("Moderation: Success: %d, Fails: %d, Avg Latency: %v\n", success, fails, avg)
}

func testSupportAgent(token string, count int) {
	// Open a conversation
	req, _ := http.NewRequest("POST", baseURL+"/support/conversations", strings.NewReader(`{"language": "en", "force_new": true}`))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		log.Fatalf("Failed to open conversation: %v", err)
	}
	
	var res map[string]interface{}
	bodyBytes, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	json.Unmarshal(bodyBytes, &res)
	
	ticketMap := res["ticket"].(map[string]interface{})
	if ticketMap == nil {
		ticketMap = res["conversation"].(map[string]interface{})
	}
	ticketID := ticketMap["id"].(string)
	
	fmt.Printf("Opened ticket: %s\n", ticketID)

	success := 0
	fails := 0
	var latencies []time.Duration

	for i := 1; i <= count; i++ {
		start := time.Now()
		msgBody := map[string]string{
			"body": fmt.Sprintf("Tell me a random short tip about Khair events. Message %d", i),
			"message_type": "text",
		}
		b, _ := json.Marshal(msgBody)
		mReq, _ := http.NewRequest("POST", baseURL+"/support/tickets/"+ticketID+"/messages", bytes.NewReader(b))
		mReq.Header.Set("Authorization", "Bearer "+token)
		mReq.Header.Set("Content-Type", "application/json")

		mResp, err := http.DefaultClient.Do(mReq)
		latency := time.Since(start)
		latencies = append(latencies, latency)

		if err == nil && mResp.StatusCode == http.StatusOK {
			success++
		} else {
			fails++
			fmt.Printf("Failed at msg %d: %v\n", i, err)
		}
		if mResp != nil {
			mResp.Body.Close()
		}
		
		fmt.Printf("Msg %d/%d - Latency: %v\n", i, count, latency)
	}
	
	avg := time.Duration(0)
	for _, l := range latencies {
		avg += l
	}
	if len(latencies) > 0 {
		avg /= time.Duration(len(latencies))
	}
	fmt.Printf("Support Agent E2E: Success: %d, Fails: %d, Avg Latency: %v\n", success, fails, avg)
}

func testSupportAgentRapid(token string) {
	// Open a conversation
	req, _ := http.NewRequest("POST", baseURL+"/support/conversations", strings.NewReader(`{"language": "en", "force_new": true}`))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		log.Fatalf("Failed to open conversation: %v", err)
	}
	var res map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&res)
	
	ticketMap := res["ticket"].(map[string]interface{})
	if ticketMap == nil {
		ticketMap = res["conversation"].(map[string]interface{})
	}
	ticketID := ticketMap["id"].(string)

	var wg sync.WaitGroup
	for i := 1; i <= 3; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			msgBody := map[string]string{
				"body": fmt.Sprintf("Rapid message %d", idx),
				"message_type": "text",
			}
			b, _ := json.Marshal(msgBody)
			mReq, _ := http.NewRequest("POST", baseURL+"/support/tickets/"+ticketID+"/messages", bytes.NewReader(b))
			mReq.Header.Set("Authorization", "Bearer "+token)
			mReq.Header.Set("Content-Type", "application/json")

			mResp, err := http.DefaultClient.Do(mReq)
			if err == nil && mResp.StatusCode == http.StatusOK {
				fmt.Printf("Rapid msg %d success\n", idx)
			} else {
				fmt.Printf("Rapid msg %d failed\n", idx)
			}
			if mResp != nil {
				mResp.Body.Close()
			}
		}(i)
	}
	wg.Wait()
}
