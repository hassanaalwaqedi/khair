package orgdash

import (
	"testing"
	"time"
)

func TestHubRangeWindowPresets(t *testing.T) {
	now := time.Date(2026, time.August, 13, 15, 30, 0, 0, time.UTC)
	tests := []struct {
		name       string
		key        string
		wantStart  time.Time
		wantEnd    time.Time
		wantPrevAt time.Time
	}{
		{
			name:       "last 30 days",
			key:        "30d",
			wantStart:  now.AddDate(0, 0, -30),
			wantEnd:    now,
			wantPrevAt: now.AddDate(0, 0, -30),
		},
		{
			name:       "this month",
			key:        "this_month",
			wantStart:  time.Date(2026, time.August, 1, 0, 0, 0, 0, time.UTC),
			wantEnd:    now,
			wantPrevAt: time.Date(2026, time.August, 1, 0, 0, 0, 0, time.UTC),
		},
		{
			name:       "last month",
			key:        "last_month",
			wantStart:  time.Date(2026, time.July, 1, 0, 0, 0, 0, time.UTC),
			wantEnd:    time.Date(2026, time.August, 1, 0, 0, 0, 0, time.UTC),
			wantPrevAt: time.Date(2026, time.July, 1, 0, 0, 0, 0, time.UTC),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			window, previousStart, previousEnd, err := HubRangeWindow(tt.key, "", "", now)
			if err != nil {
				t.Fatalf("HubRangeWindow() error = %v", err)
			}
			if !window.Start.Equal(tt.wantStart) || !window.End.Equal(tt.wantEnd) {
				t.Fatalf("window = [%s, %s], want [%s, %s]", window.Start, window.End, tt.wantStart, tt.wantEnd)
			}
			if !previousEnd.Equal(tt.wantPrevAt) || !previousStart.Before(previousEnd) {
				t.Fatalf("previous window = [%s, %s]", previousStart, previousEnd)
			}
		})
	}
}

func TestHubRangeWindowRejectsInvalidCustomRange(t *testing.T) {
	_, _, _, err := HubRangeWindow(
		"custom",
		"2026-08-10T00:00:00Z",
		"2026-08-09T00:00:00Z",
		time.Now(),
	)
	if err == nil {
		t.Fatal("expected custom range validation error")
	}
}

func TestRateHandlesZeroViewDenominator(t *testing.T) {
	if got := rate(4, 0); got != 0 {
		t.Fatalf("rate(4, 0) = %v, want 0", got)
	}
	if got := rate(5, 20); got != 25 {
		t.Fatalf("rate(5, 20) = %v, want 25", got)
	}
}

func TestPercentageChangeOmitsInsufficientPreviousPeriod(t *testing.T) {
	if got := percentageChange(4, 0); got != nil {
		t.Fatalf("percentageChange(4, 0) = %v, want nil", *got)
	}
	if got := percentageChange(0, 0); got == nil || *got != 0 {
		t.Fatalf("percentageChange(0, 0) = %v, want 0", got)
	}
}
