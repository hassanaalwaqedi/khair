package ws

import (
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"github.com/khair/backend/pkg/middleware"
)

func TestParseJWTAcceptsKhairAccessToken(t *testing.T) {
	const secret = "test-secret"
	const userID = "c49b65ce-1fdf-4f5d-a2d5-9f59950cf562"
	hub := NewHub(nil, secret)

	token, err := jwt.NewWithClaims(jwt.SigningMethodHS256, &middleware.Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Minute)),
		},
	}).SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("sign token: %v", err)
	}

	actual, err := hub.parseJWT(token)
	if err != nil {
		t.Fatalf("parse token: %v", err)
	}
	if actual != userID {
		t.Fatalf("user id = %q, want %q", actual, userID)
	}
}

func TestParseJWTFallsBackToSubject(t *testing.T) {
	const secret = "test-secret"
	const userID = "62cfbe53-4296-4ab8-9b57-4510749c3e8e"
	hub := NewHub(nil, secret)

	token, err := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub": userID,
		"exp": time.Now().Add(time.Minute).Unix(),
	}).SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("sign token: %v", err)
	}

	actual, err := hub.parseJWT(token)
	if err != nil {
		t.Fatalf("parse token: %v", err)
	}
	if actual != userID {
		t.Fatalf("user id = %q, want %q", actual, userID)
	}
}
