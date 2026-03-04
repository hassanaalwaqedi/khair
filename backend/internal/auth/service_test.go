package auth

import (
	"crypto/sha256"
	"encoding/hex"
	"strconv"
	"testing"
)

func TestGenerateOTP(t *testing.T) {
	// Generate multiple OTPs and verify properties
	seen := make(map[string]bool)
	for i := 0; i < 100; i++ {
		otp, err := generateOTP()
		if err != nil {
			t.Fatalf("generateOTP() returned error: %v", err)
		}

		// Must be exactly 6 digits
		if len(otp) != 6 {
			t.Errorf("OTP length = %d, want 6", len(otp))
		}

		// Must be numeric
		if _, err := strconv.Atoi(otp); err != nil {
			t.Errorf("OTP %q is not numeric", otp)
		}

		// Must be in range 000000-999999
		num, _ := strconv.Atoi(otp)
		if num < 0 || num > 999999 {
			t.Errorf("OTP value %d out of range [0, 999999]", num)
		}

		seen[otp] = true
	}

	// With 100 samples of 1M possibilities, we should see some uniqueness
	if len(seen) < 10 {
		t.Errorf("Generated only %d unique OTPs out of 100, expected more randomness", len(seen))
	}
}

func TestHashOTP(t *testing.T) {
	otp := "123456"
	hash := hashOTP(otp)

	// SHA256 always produces 64 hex characters
	if len(hash) != 64 {
		t.Errorf("hash length = %d, want 64", len(hash))
	}

	// Same input should produce same output
	hash2 := hashOTP(otp)
	if hash != hash2 {
		t.Error("hashOTP() not deterministic: same input produced different hashes")
	}

	// Different input should produce different output
	hash3 := hashOTP("654321")
	if hash == hash3 {
		t.Error("hashOTP() produced same hash for different inputs")
	}

	// Verify against known SHA256 value
	expected := sha256.Sum256([]byte(otp))
	expectedHex := hex.EncodeToString(expected[:])
	if hash != expectedHex {
		t.Errorf("hashOTP(%q) = %q, want %q", otp, hash, expectedHex)
	}
}

func TestConstantTimeEqual(t *testing.T) {
	tests := []struct {
		name string
		a    string
		b    string
		want bool
	}{
		{"identical strings", "abc123", "abc123", true},
		{"different strings", "abc123", "xyz789", false},
		{"different lengths", "short", "much longer string", false},
		{"empty strings", "", "", true},
		{"one empty", "abc", "", false},
		{"SHA256 hashes match", hashOTP("123456"), hashOTP("123456"), true},
		{"SHA256 hashes differ", hashOTP("123456"), hashOTP("654321"), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := constantTimeEqual(tt.a, tt.b)
			if got != tt.want {
				t.Errorf("constantTimeEqual(%q, %q) = %v, want %v", tt.a, tt.b, got, tt.want)
			}
		})
	}
}

func TestHashOTPEdgeCases(t *testing.T) {
	// Empty string
	hash := hashOTP("")
	if len(hash) != 64 {
		t.Errorf("hash of empty string: length = %d, want 64", len(hash))
	}

	// Leading zeros
	hash1 := hashOTP("000000")
	hash2 := hashOTP("000001")
	if hash1 == hash2 {
		t.Error("different OTPs with leading zeros produced same hash")
	}

	// Verify OTP "000000" hashes correctly
	expected := sha256.Sum256([]byte("000000"))
	expectedHex := hex.EncodeToString(expected[:])
	if hash1 != expectedHex {
		t.Errorf("hashOTP(\"000000\") = %q, want %q", hash1, expectedHex)
	}
}
