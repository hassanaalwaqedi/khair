//go:build ignore
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"golang.org/x/net/context"
)

const (
	baseURL = "http://localhost:8080"
	dbURL   = "postgresql://postgres.ulwubufgyodwmajbsfsw:As717801454%2A@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres?sslmode=require"
	email   = "test_phase2_user@example.com"
)

var client = &http.Client{Timeout: 10 * time.Second}
var jwtToken string
var currentEmail string

func main() {
	currentEmail = fmt.Sprintf("test_phase2_%d@example.com", time.Now().Unix())
	log.Println("Starting Phase 2 API E2E Validation...")
	ctx := context.Background()

	// Clean up previous test user if exists
	cleanup(ctx)

	// 1. Registration
	log.Println("1. Registering user...")
	reqBody, _ := json.Marshal(map[string]string{
		"email":    currentEmail,
		"name":     "Phase2 Test",
		"password": "Password123!",
	})
	resp := doRequest("POST", "/api/v1/auth/register", reqBody, false)
	if resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusOK {
		log.Fatalf("Registration failed: %v %s", resp.StatusCode, resp.Body)
	}

	// 2. Fetch OTP from Log
	log.Println("2. Fetching OTP from Log...")
	otp := getOTPFromLog()
	if otp == "" {
		log.Fatalf("Failed to fetch OTP from database")
	}
	log.Printf("Fetched OTP: %s", otp)

	// 3. Verify OTP
	log.Println("3. Verifying OTP...")
	reqBody, _ = json.Marshal(map[string]string{
		"email": currentEmail,
		"otp":   otp,
	})
	resp = doRequest("POST", "/api/v1/auth/verify-email", reqBody, false)
	if resp.StatusCode != http.StatusOK {
		log.Fatalf("OTP Verification failed: %v %s", resp.StatusCode, resp.Body)
	}

	// 4. Login
	log.Println("4. Logging in...")
	reqBody, _ = json.Marshal(map[string]string{
		"email":    currentEmail,
		"password": "Password123!",
	})
	resp = doRequest("POST", "/api/v1/auth/login", reqBody, false)
	if resp.StatusCode != http.StatusOK {
		log.Fatalf("Login failed: %v %s", resp.StatusCode, resp.Body)
	}
	var loginData struct {
		Data struct {
			Token string `json:"token"`
		} `json:"data"`
	}
	json.Unmarshal([]byte(resp.Body), &loginData)
	jwtToken = loginData.Data.Token
	if jwtToken == "" {
		log.Fatalf("No access token returned. Body: %s", resp.Body)
	}

	// 5. Discover Events
	log.Println("5. Discovering events...")
	resp = doRequest("GET", "/api/v1/events", nil, true)
	if resp.StatusCode != http.StatusOK {
		log.Fatalf("Discover failed: %v %s", resp.StatusCode, resp.Body)
	}
	var discoverData struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	json.Unmarshal([]byte(resp.Body), &discoverData)
	if len(discoverData.Data) == 0 {
		log.Println("WARNING: No events found in discover to test joins. Skipping join test.")
		return
	}
	log.Printf("Found %d events.", len(discoverData.Data))

	// 6. Search and Filters
	log.Println("6. Testing Search & Filters...")
	resp = doRequest("GET", "/api/v1/events?search=asdfqwer1234zeroresults", nil, true)
	var searchData struct {
		Data []interface{} `json:"data"`
	}
	json.Unmarshal([]byte(resp.Body), &searchData)
	if len(searchData.Data) != 0 {
		log.Fatalf("Expected 0 results for dummy search, got %d", len(searchData.Data))
	}
	log.Println("Zero-result search successful.")

	// 7. Join Event
	log.Println("7. Joining event...")
	var eventID string
	var joined bool
	for _, e := range discoverData.Data {
		resp = doRequest("POST", fmt.Sprintf("/api/v1/events/%s/join", e.ID), nil, true)
		if resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusCreated {
			eventID = e.ID
			joined = true
			break
		}
	}
	if !joined {
		log.Fatalf("Failed to join any event. All events returned errors or were closed.")
	}
	log.Printf("Successfully joined event: %s", eventID)

	// 8. Double Join Attempt
	log.Println("8. Attempting duplicate join...")
	resp = doRequest("POST", fmt.Sprintf("/api/v1/events/%s/join", eventID), nil, true)
	if resp.StatusCode != http.StatusConflict && resp.StatusCode != http.StatusBadRequest {
		log.Fatalf("Expected Conflict/BadRequest for duplicate join, got: %v %s", resp.StatusCode, resp.Body)
	}
	log.Println("Double join properly prevented.")

	// 9. My Events
	log.Println("9. Fetching My Events...")
	resp = doRequest("GET", "/api/v1/my/reservations", nil, true)
	if resp.StatusCode != http.StatusOK {
		log.Fatalf("My Events failed: %v %s", resp.StatusCode, resp.Body)
	}
	var verifyEventsData struct {
		Data []struct {
			EventID string `json:"event_id"`
			Status  string `json:"status"`
		} `json:"data"`
	}
	json.Unmarshal([]byte(resp.Body), &verifyEventsData)
	found := false
	for _, e := range verifyEventsData.Data {
		if e.EventID == eventID && e.Status != "cancelled" {
			found = true
			break
		}
	}
	if !found {
		log.Fatalf("Joined event not found in My Events. Body: %s", resp.Body)
	}

	// 10. Leave Event
	log.Println("10. Leaving event...")
	resp = doRequest("DELETE", fmt.Sprintf("/api/v1/events/%s/join", eventID), nil, true)
	if resp.StatusCode != http.StatusOK {
		log.Fatalf("Leave event failed: %v %s", resp.StatusCode, resp.Body)
	}

	// 11. Verify Left My Events
	log.Println("11. Verifying event removed from My Events...")
	resp = doRequest("GET", "/api/v1/my/reservations", nil, true)
	json.Unmarshal([]byte(resp.Body), &verifyEventsData)
	found = false
	for _, e := range verifyEventsData.Data {
		if e.EventID == eventID && e.Status != "cancelled" {
			found = true
			break
		}
	}
	if found {
		log.Fatalf("Event still found in My Events after leaving")
	}

	log.Println("=========================================")
	log.Println("PHASE 2 E2E VALIDATION COMPLETE AND SUCCESSFUL")
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
		log.Fatalf("Request error: %v", err)
	}
	defer res.Body.Close()
	resBody, _ := io.ReadAll(res.Body)
	return Response{
		StatusCode: res.StatusCode,
		Body:       string(resBody),
	}
}

func getOTPFromLog() string {
	time.Sleep(2 * time.Second)
	content, err := os.ReadFile(`C:\Users\Hassan\.gemini\antigravity-ide\brain\b153a191-99c5-44ee-876b-27ff2c2081ee\.system_generated\tasks\task-1072.log`)
	if err != nil {
		log.Fatalf("Failed to read log: %v", err)
	}
	lines := strings.Split(string(content), "\n")
	for i := len(lines) - 1; i >= 0; i-- {
		if strings.Contains(lines[i], "[E2E_INTERCEPT] OTP for " + currentEmail) {
			parts := strings.Split(lines[i], " is ")
			if len(parts) == 2 {
				return strings.TrimSpace(parts[1])
			}
		}
	}
	return ""
}

func cleanup(ctx context.Context) {
	conn, err := pgx.Connect(ctx, dbURL)
	if err != nil {
		log.Printf("DB connect failed during cleanup: %v", err)
		return
	}
	defer conn.Close(ctx)
	conn.Exec(ctx, "DELETE FROM otp_codes WHERE email = $1", currentEmail)
	conn.Exec(ctx, "DELETE FROM users WHERE email = $1", currentEmail)
}
