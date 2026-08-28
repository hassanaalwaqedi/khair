package event

import (
	"testing"
	"time"
)

func TestApplyDatePresetTodayUsesUserTimezoneAndHalfOpenEnd(t *testing.T) {
	filter := &EventFilter{}
	now := time.Date(2026, time.August, 28, 10, 0, 0, 0, time.UTC)
	if err := applyDatePreset(filter, "today", "Asia/Riyadh", now); err != nil {
		t.Fatal(err)
	}

	wantStart := time.Date(2026, time.August, 27, 21, 0, 0, 0, time.UTC)
	wantEnd := time.Date(2026, time.August, 28, 21, 0, 0, 0, time.UTC)
	if !filter.StartDate.Equal(wantStart) || !filter.EndDate.Equal(wantEnd) {
		t.Fatalf("today window = %v..%v, want %v..%v", filter.StartDate, filter.EndDate, wantStart, wantEnd)
	}

	augustThirtyOne := time.Date(2026, time.August, 31, 12, 0, 0, 0, time.UTC)
	if overlapsEventWindow(augustThirtyOne, nil, *filter.StartDate, *filter.EndDate) {
		t.Fatal("31 August event must not match 28 August today window")
	}
}

func TestApplyDatePresetWeekendIsSaturdayThroughMonday(t *testing.T) {
	filter := &EventFilter{}
	now := time.Date(2026, time.August, 28, 12, 0, 0, 0, time.UTC) // Friday
	if err := applyDatePreset(filter, "this_weekend", "UTC", now); err != nil {
		t.Fatal(err)
	}

	if got, want := filter.StartDate.Weekday(), time.Saturday; got != want {
		t.Fatalf("weekend start weekday = %v, want %v", got, want)
	}
	if got, want := filter.EndDate.Weekday(), time.Monday; got != want {
		t.Fatalf("weekend end weekday = %v, want %v", got, want)
	}
}

func overlapsEventWindow(eventStart time.Time, eventEnd *time.Time, windowStart, windowEnd time.Time) bool {
	end := eventStart
	if eventEnd != nil {
		end = *eventEnd
	}
	return eventStart.Before(windowEnd) && !end.Before(windowStart)
}
