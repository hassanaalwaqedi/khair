package launch

import (
	"context"
	"testing"
)

func TestNewServiceWithoutRedisUsesDefaults(t *testing.T) {
	service := NewService(nil)
	if service == nil || service.GetConfig(context.Background()) == nil {
		t.Fatal("expected launch service defaults without Redis")
	}
	if _, err := service.ListInviteCodes(context.Background()); err == nil {
		t.Fatal("expected invite storage to report unavailable Redis")
	}
}
