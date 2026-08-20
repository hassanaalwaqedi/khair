package storage

import (
	"strings"
	"testing"
)

func TestR2ProviderRequiresCompleteProductionConfiguration(t *testing.T) {
	t.Setenv("ENV", "production")
	t.Setenv("GIN_MODE", "release")
	t.Setenv("STORAGE_PROVIDER", "r2")
	t.Setenv("R2_PUBLIC_BUCKET", "")
	t.Setenv("R2_ENDPOINT", "")
	t.Setenv("R2_ACCESS_KEY_ID", "")
	t.Setenv("R2_SECRET_ACCESS_KEY", "")
	t.Setenv("R2_PUBLIC_BASE_URL", "")

	provider := NewProvider("./uploads", "")
	if _, ok := provider.(unavailableProvider); !ok {
		t.Fatalf("production must not fall back to local storage; got %T", provider)
	}
	if err := UnavailableError(provider); err == nil {
		t.Fatal("unavailable provider must expose a safe availability error")
	}
}

func TestR2ProviderBuildsPathStyleObjectURL(t *testing.T) {
	t.Setenv("R2_PUBLIC_BUCKET", "khair-public")
	t.Setenv("R2_ENDPOINT", "https://account-id.r2.cloudflarestorage.com")
	t.Setenv("R2_ACCESS_KEY_ID", "access")
	t.Setenv("R2_SECRET_ACCESS_KEY", "secret")
	t.Setenv("R2_PUBLIC_BASE_URL", "https://media.khair.example")
	t.Setenv("R2_REGION", "auto")

	provider, err := newR2ProviderFromEnv()
	if err != nil {
		t.Fatalf("newR2ProviderFromEnv() error = %v", err)
	}
	if got, want := provider.objectURL("images/event.webp"), "https://account-id.r2.cloudflarestorage.com/khair-public/images/event.webp"; got != want {
		t.Fatalf("objectURL = %q, want %q", got, want)
	}
	if !strings.HasPrefix(provider.publicBaseURL, "https://") {
		t.Fatal("public asset URLs must use HTTPS")
	}
}
