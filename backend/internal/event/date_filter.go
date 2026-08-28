package event

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// applyDatePreset converts a user's calendar date into UTC query boundaries.
// Event timestamps are stored as instants (TIMESTAMP WITH TIME ZONE), so the
// user's timezone is used only to calculate the calendar boundaries.
func applyDatePreset(filter *EventFilter, preset, timezone string, now time.Time) error {
	preset = strings.ToLower(strings.TrimSpace(preset))
	if preset == "" {
		return nil
	}

	loc, err := queryLocation(timezone)
	if err != nil {
		return err
	}
	localNow := now.In(loc)
	startOfDay := time.Date(localNow.Year(), localNow.Month(), localNow.Day(), 0, 0, 0, 0, loc)

	var start, end *time.Time
	switch preset {
	case "today":
		endOfDay := startOfDay.AddDate(0, 0, 1)
		start, end = utcPtr(startOfDay), utcPtr(endOfDay)
	case "this_weekend", "weekend":
		// Saturday/Sunday. On Saturday or Sunday use the current weekend;
		// Monday-Friday use the upcoming weekend.
		daysFromSaturday := (int(localNow.Weekday()) - int(time.Saturday) + 7) % 7
		if localNow.Weekday() != time.Saturday && localNow.Weekday() != time.Sunday {
			daysFromSaturday = (int(time.Saturday) - int(localNow.Weekday()) + 7) % 7
		}
		weekendStart := startOfDay.AddDate(0, 0, -daysFromSaturday)
		if localNow.Weekday() >= time.Monday && localNow.Weekday() <= time.Friday {
			weekendStart = startOfDay.AddDate(0, 0, daysFromSaturday)
		}
		weekendEnd := weekendStart.AddDate(0, 0, 2)
		start, end = utcPtr(weekendStart), utcPtr(weekendEnd)
	case "this_week", "week":
		weekStart := startOfDay.AddDate(0, 0, -((int(localNow.Weekday()) + 6) % 7))
		weekEnd := weekStart.AddDate(0, 0, 7)
		start, end = utcPtr(weekStart), utcPtr(weekEnd)
	case "this_month", "month":
		monthEnd := time.Date(localNow.Year(), localNow.Month()+1, 1, 0, 0, 0, 0, loc)
		start, end = utcPtr(startOfDay), utcPtr(monthEnd)
	case "upcoming":
		start = utcPtr(now)
	case "past":
		end = utcPtr(now)
	default:
		return fmt.Errorf("unsupported date filter %q", preset)
	}

	filter.StartDate = start
	filter.EndDate = end
	return nil
}

func utcPtr(value time.Time) *time.Time {
	utc := value.UTC()
	return &utc
}

var fixedTimezonePattern = regexp.MustCompile(`^(?:UTC|GMT)?([+-])(\d{1,2})(?::?(\d{2}))?$`)

func queryLocation(name string) (*time.Location, error) {
	name = strings.TrimSpace(name)
	if name == "" || strings.EqualFold(name, "utc") || strings.EqualFold(name, "gmt") {
		return time.UTC, nil
	}
	if loc, err := time.LoadLocation(name); err == nil {
		return loc, nil
	}

	match := fixedTimezonePattern.FindStringSubmatch(strings.ToUpper(name))
	if len(match) == 0 {
		return nil, fmt.Errorf("invalid timezone %q", name)
	}
	hours, _ := strconv.Atoi(match[2])
	minutes := 0
	if match[3] != "" {
		minutes, _ = strconv.Atoi(match[3])
	}
	if hours > 23 || minutes > 59 {
		return nil, fmt.Errorf("invalid timezone %q", name)
	}
	offset := (hours*60 + minutes) * 60
	if match[1] == "-" {
		offset = -offset
	}
	return time.FixedZone(name, offset), nil
}

func parseQueryTime(raw, timezone string) (time.Time, error) {
	if value, err := time.Parse(time.RFC3339Nano, raw); err == nil {
		return value.UTC(), nil
	}
	// Accept legacy local timestamps only when the client also identifies its
	// timezone. New clients should send RFC3339 UTC values.
	loc, err := queryLocation(timezone)
	if err != nil {
		return time.Time{}, err
	}
	value, err := time.ParseInLocation("2006-01-02T15:04:05.999999999", raw, loc)
	if err != nil {
		return time.Time{}, fmt.Errorf("invalid timestamp %q", raw)
	}
	return value.UTC(), nil
}
