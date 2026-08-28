//go:build ignore
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

	"github.com/jackc/pgx/v5"
)

const (
	baseURL = "http://localhost:8080"
	dbURL   = "postgresql://postgres.ulwubufgyodwmajbsfsw:As717801454%2A@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres?sslmode=require"
)

var client = &http.Client{Timeout: 10 * time.Second}
var jwtToken string
var currentEmail string

func main() {
	currentEmail = fmt.Sprintf("test_chaos_%d@example.com", time.Now().Unix())
	log.Println("Starting Phase 4 API Chaos Torture...")
	ctx := context.Background()

	// 1. Registration & Auth
	log.Println("1. Registering & Authenticating...")
	reqBody, _ := json.Marshal(map[string]string{"email": currentEmail, "name": "Chaos Test", "password": "Password123!"})
	doRequest("POST", "/api/v1/auth/register", reqBody, false)
	time.Sleep(2 * time.Second)
	otp := getOTPFromLog()
	reqBody, _ = json.Marshal(map[string]string{"email": currentEmail, "otp": otp})
	doRequest("POST", "/api/v1/auth/verify-email", reqBody, false)
	reqBody, _ = json.Marshal(map[string]string{"email": currentEmail, "password": "Password123!"})
	resp := doRequest("POST", "/api/v1/auth/login", reqBody, false)
	var loginData struct{ Data struct{ Token string `json:"token"` } `json:"data"` }
	json.Unmarshal([]byte(resp.Body), &loginData)
	jwtToken = loginData.Data.Token
	if jwtToken == "" {
		log.Fatalf("Chaos auth failed")
	}

	// 2. Discover Events
	log.Println("2. Discovering events...")
	resp = doRequest("GET", "/api/v1/events", nil, true)
	var discoverData struct{ Data []struct{ ID string `json:"id"` } `json:"data"` }
	json.Unmarshal([]byte(resp.Body), &discoverData)
	var targetEvent string
	for _, e := range discoverData.Data {
		// Test join
		r := doRequest("POST", fmt.Sprintf("/api/v1/events/%s/join", e.ID), nil, true)
		if r.StatusCode == http.StatusOK || r.StatusCode == http.StatusCreated {
			targetEvent = e.ID
			// Cancel it so we can run the concurrency torture on it
			doRequest("DELETE", fmt.Sprintf("/api/v1/events/%s/join", e.ID), nil, true)
			break
		}
	}
	if targetEvent == "" {
		log.Fatalf("No joinable events found for chaos test")
	}

	// 3. Concurrent Join Torture
	log.Println("3. Starting Concurrent Join Storm (10 requests)...")
	var wg sync.WaitGroup
	var joinSuccessCount int
	var joinMu sync.Mutex

	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			r := doRequest("POST", fmt.Sprintf("/api/v1/events/%s/join", targetEvent), nil, true)
			if r.StatusCode == http.StatusOK || r.StatusCode == http.StatusCreated {
				joinMu.Lock()
				joinSuccessCount++
				joinMu.Unlock()
			}
		}()
	}
	wg.Wait()

	if joinSuccessCount != 1 {
		log.Fatalf("P0 VIOLATION: Concurrent join allowed %d successes instead of exactly 1", joinSuccessCount)
	}
	log.Println("Concurrency check passed: Exactly 1 join succeeded, remainder rejected.")

	// 4. Authorization Torture
	log.Println("4. Authorization Torture (Normal User hitting Admin endpoint)...")
	resp = doRequest("GET", "/api/v1/admin/events", nil, true)
	if resp.StatusCode != http.StatusForbidden && resp.StatusCode != http.StatusUnauthorized && resp.StatusCode != http.StatusNotFound {
		log.Fatalf("P0 VIOLATION: Normal user accessed admin endpoint! Status: %d", resp.StatusCode)
	}
	log.Println("Authorization block passed.")

	// 5. Input Abuse
	log.Println("5. Input Abuse Torture (Huge Payload)...")
	hugeString := strings.Repeat("A", 2*1024*1024) // 2MB string
	reqBody, _ = json.Marshal(map[string]string{"email": currentEmail, "display_name": hugeString, "password": "Password123!"})
	resp = doRequest("PUT", "/api/v1/profile", reqBody, true)
	if resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusCreated {
		log.Fatalf("P1 VIOLATION: Server accepted excessively large input without validation")
	} else if resp.StatusCode >= 500 {
		log.Fatalf("P1 VIOLATION: Server panicked/crashed on large input! Status: %d", resp.StatusCode)
	}
	log.Println("Input abuse check passed.")

	// Cleanup
	conn, _ := pgx.Connect(ctx, dbURL)
	if conn != nil {
		defer conn.Close(ctx)
		conn.Exec(ctx, "DELETE FROM otp_codes WHERE email = $1", currentEmail)
		conn.Exec(ctx, "DELETE FROM users WHERE email = $1", currentEmail)
	}

	log.Println("=========================================")
	log.Println("PHASE 4 CHAOS VALIDATION COMPLETE AND SUCCESSFUL")
	log.Println("=========================================")
}

type Response struct {
	StatusCode int
	Body       string
}

func doRequest(method, path string, body []byte, useAuth bool) Response {
	req, _ := http.NewRequest(method, baseURL+path, bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	if useAuth {
		req.Header.Set("Authorization", "Bearer "+jwtToken)
	}
	res, err := client.Do(req)
	if err != nil {
		log.Printf("Request error: %v", err)
		return Response{StatusCode: 500}
	}
	defer res.Body.Close()
	resBody, _ := io.ReadAll(res.Body)
	return Response{
		StatusCode: res.StatusCode,
		Body:       string(resBody),
	}
}

func getOTPFromLog() string {
	content, err := os.ReadFile(`C:\Users\Hassan\.gemini\antigravity-ide\brain\b153a191-99c5-44ee-876b-27ff2c2081ee\.system_generated\tasks\task-1072.log`)
	if err != nil { return "" }
	lines := strings.Split(string(content), "\n")
	for i := len(lines) - 1; i >= 0; i-- {
		if strings.Contains(lines[i], "[E2E_INTERCEPT] OTP for "+currentEmail) {
			parts := strings.Split(lines[i], " is ")
			if len(parts) == 2 {
				return strings.TrimSpace(parts[1])
			}
		}
	}
	return ""
}
