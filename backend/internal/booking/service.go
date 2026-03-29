package booking

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/notification"
	"github.com/khair/backend/internal/push"
	"github.com/khair/backend/pkg/prayer"
)

// Slot represents an available time slot for booking.
type Slot struct {
	StartTime time.Time `json:"start_time"`
	EndTime   time.Time `json:"end_time"`
}

// Service handles booking business logic.
type Service struct {
	repo     *Repository
	notifSvc *notification.Service
	pushSvc  *push.Service
}

// NewService creates a new booking service.
func NewService(db *sql.DB, notifSvc *notification.Service, pushSvc *push.Service) *Service {
	return &Service{
		repo:     NewRepository(db),
		notifSvc: notifSvc,
		pushSvc:  pushSvc,
	}
}

// ── Availability ──

func (s *Service) SetAvailability(sheikhID uuid.UUID, rules []AvailabilityRule) error {
	for i := range rules {
		rules[i].SheikhID = sheikhID
		if rules[i].SlotDurationMinutes < 15 {
			rules[i].SlotDurationMinutes = 30
		}
		if rules[i].BreakMinutes < 0 {
			rules[i].BreakMinutes = 0
		}
		if err := s.repo.UpsertAvailabilityRule(&rules[i]); err != nil {
			return fmt.Errorf("save rule for day %d: %w", rules[i].DayOfWeek, err)
		}
	}
	return nil
}

func (s *Service) GetAvailability(sheikhID uuid.UUID) ([]AvailabilityRule, error) {
	return s.repo.GetAvailabilityRules(sheikhID)
}

func (s *Service) DeleteAvailability(sheikhID uuid.UUID, dayOfWeek int) error {
	return s.repo.DeleteAvailabilityRule(sheikhID, dayOfWeek)
}

// ── Settings ──

func (s *Service) GetSettings(sheikhID uuid.UUID) (*BookingSettings, error) {
	return s.repo.GetBookingSettings(sheikhID)
}

func (s *Service) UpdateSettings(settings *BookingSettings) error {
	return s.repo.UpsertBookingSettings(settings)
}

// ── Slot Generation ──

// GetAvailableSlots returns available time slots for a sheikh on a given date.
func (s *Service) GetAvailableSlots(sheikhID uuid.UUID, date time.Time) ([]Slot, error) {
	settings, err := s.repo.GetBookingSettings(sheikhID)
	if err != nil {
		return nil, fmt.Errorf("get settings: %w", err)
	}

	// Load timezone
	loc, err := time.LoadLocation(settings.Timezone)
	if err != nil {
		loc = time.UTC
	}
	date = time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, loc)

	// 1. Get availability rule for this day of week
	dow := int(date.Weekday())
	rules, err := s.repo.GetAvailabilityRules(sheikhID)
	if err != nil {
		return nil, err
	}

	var rule *AvailabilityRule
	for _, r := range rules {
		if r.DayOfWeek == dow && r.IsActive {
			r := r
			rule = &r
			break
		}
	}
	if rule == nil {
		return []Slot{}, nil // No availability for this day
	}

	// 2. Generate all possible slots
	startH, startM := parseTime(rule.StartTime)
	endH, endM := parseTime(rule.EndTime)

	start := date.Add(time.Duration(startH)*time.Hour + time.Duration(startM)*time.Minute)
	end := date.Add(time.Duration(endH)*time.Hour + time.Duration(endM)*time.Minute)

	slotDur := time.Duration(rule.SlotDurationMinutes) * time.Minute
	breakDur := time.Duration(rule.BreakMinutes) * time.Minute

	var allSlots []Slot
	for t := start; t.Add(slotDur).Before(end) || t.Add(slotDur).Equal(end); t = t.Add(slotDur + breakDur) {
		allSlots = append(allSlots, Slot{
			StartTime: t,
			EndTime:   t.Add(slotDur),
		})
	}

	if len(allSlots) == 0 {
		return []Slot{}, nil
	}

	// 3. Get existing bookings for this date range
	dayStart := date
	dayEnd := date.Add(24 * time.Hour)
	existingBookings, err := s.repo.GetBookingsInRange(sheikhID, dayStart, dayEnd)
	if err != nil {
		return nil, err
	}

	// 4. Get blocked times
	blockedTimes, err := s.repo.GetBlockedTimesInRange(sheikhID, dayStart, dayEnd)
	if err != nil {
		return nil, err
	}

	// 5. Get prayer windows (if enabled)
	var prayerWindows []prayer.Window
	if settings.PrayerBlocking && settings.Latitude != nil && settings.Longitude != nil {
		prayerTimes := prayer.Calculate(date, *settings.Latitude, *settings.Longitude, prayer.MWL)
		prayerWindows = prayer.BlockedWindows(prayerTimes, 15, 10) // 15 min before, 10 min after
	}

	// 6. Filter slots
	now := time.Now().In(loc)
	var available []Slot
	for _, slot := range allSlots {
		// Skip past slots
		if slot.StartTime.Before(now) {
			continue
		}

		// Skip if booked
		if isBooked(slot, existingBookings) {
			continue
		}

		// Skip if blocked
		if isBlocked(slot, blockedTimes) {
			continue
		}

		// Skip if during prayer
		if isInPrayerWindow(slot, prayerWindows) {
			continue
		}

		available = append(available, slot)
	}

	if available == nil {
		available = []Slot{}
	}
	return available, nil
}

// ── Booking CRUD ──

func (s *Service) CreateBooking(studentID, sheikhID uuid.UUID, startTime time.Time, duration int, notes string) (*Booking, error) {
	settings, err := s.repo.GetBookingSettings(sheikhID)
	if err != nil {
		return nil, fmt.Errorf("get settings: %w", err)
	}

	status := "pending"
	if settings.AutoApprove {
		status = "confirmed"
	}

	booking := &Booking{
		ID:              uuid.New(),
		StudentID:       studentID,
		SheikhID:        sheikhID,
		StartTime:       startTime,
		EndTime:         startTime.Add(time.Duration(duration) * time.Minute),
		Status:          status,
		MeetingLink:     settings.DefaultMeetingLink,
		MeetingPlatform: settings.DefaultPlatform,
	}
	if notes != "" {
		booking.Notes = &notes
	}

	if err := s.repo.CreateBookingTx(booking); err != nil {
		return nil, err
	}

	// Notify sheikh
	go s.notifyBookingCreated(booking)

	// If auto-approved, also notify student
	if settings.AutoApprove {
		go s.notifyBookingConfirmed(booking)
	}

	return booking, nil
}

func (s *Service) RespondToBooking(bookingID uuid.UUID, sheikhID uuid.UUID, status string) error {
	if status != "confirmed" && status != "rejected" {
		return fmt.Errorf("invalid status: must be confirmed or rejected")
	}

	booking, err := s.repo.GetBooking(bookingID)
	if err != nil {
		return fmt.Errorf("booking not found: %w", err)
	}
	if booking.SheikhID != sheikhID {
		return fmt.Errorf("not authorized")
	}
	if booking.Status != "pending" {
		return fmt.Errorf("booking is not pending")
	}

	if err := s.repo.UpdateBookingStatus(bookingID, status); err != nil {
		return err
	}

	booking.Status = status

	if status == "confirmed" {
		go s.notifyBookingConfirmed(booking)
	} else {
		go s.notifyBookingRejected(booking)
	}

	return nil
}

func (s *Service) CancelBooking(bookingID uuid.UUID, userID uuid.UUID) error {
	booking, err := s.repo.GetBooking(bookingID)
	if err != nil {
		return fmt.Errorf("booking not found: %w", err)
	}
	if booking.StudentID != userID && booking.SheikhID != userID {
		return fmt.Errorf("not authorized")
	}
	if booking.Status == "cancelled" {
		return fmt.Errorf("booking already cancelled")
	}

	return s.repo.UpdateBookingStatus(bookingID, "cancelled")
}

func (s *Service) GetStudentBookings(studentID uuid.UUID) ([]Booking, error) {
	return s.repo.ListStudentBookings(studentID)
}

func (s *Service) GetSheikhBookings(sheikhID uuid.UUID) ([]Booking, error) {
	return s.repo.ListSheikhBookings(sheikhID)
}

// ── Blocked Times ──

func (s *Service) AddBlockedTime(bt *BlockedTime) error {
	bt.ID = uuid.New()
	return s.repo.CreateBlockedTime(bt)
}

func (s *Service) RemoveBlockedTime(id, sheikhID uuid.UUID) error {
	return s.repo.DeleteBlockedTime(id, sheikhID)
}

func (s *Service) GetBlockedTimes(sheikhID uuid.UUID) ([]BlockedTime, error) {
	return s.repo.ListSheikhBlockedTimes(sheikhID)
}

// ── Notifications ──

func (s *Service) notifyBookingCreated(b *Booking) {
	sheikhUserID, err := s.repo.GetSheikhUserID(b.SheikhID)
	if err != nil {
		return
	}

	title := "New Lesson Booking 📅"
	body := fmt.Sprintf("A student has booked a lesson at %s", b.StartTime.Format("Jan 2, 3:04 PM"))

	if s.notifSvc != nil {
		_ = s.notifSvc.CreateTyped(sheikhUserID, title, body, "booking_created", map[string]string{
			"booking_id": b.ID.String(),
		})
	}
	if s.pushSvc != nil {
		s.pushSvc.SendToUser(sheikhUserID, title, body, map[string]string{
			"type":       "booking_created",
			"booking_id": b.ID.String(),
		})
	}
}

func (s *Service) notifyBookingConfirmed(b *Booking) {
	title := "Lesson Confirmed! ✅"
	body := fmt.Sprintf("Your lesson on %s has been confirmed", b.StartTime.Format("Jan 2, 3:04 PM"))
	if b.MeetingLink != nil {
		body += fmt.Sprintf(". Join: %s", *b.MeetingLink)
	}

	if s.notifSvc != nil {
		_ = s.notifSvc.CreateTyped(b.StudentID, title, body, "booking_confirmed", map[string]string{
			"booking_id": b.ID.String(),
		})
	}
	if s.pushSvc != nil {
		s.pushSvc.SendToUser(b.StudentID, title, body, map[string]string{
			"type":       "booking_confirmed",
			"booking_id": b.ID.String(),
		})
	}
}

func (s *Service) notifyBookingRejected(b *Booking) {
	title := "Lesson Request Declined"
	body := fmt.Sprintf("Your booking for %s was declined by the sheikh", b.StartTime.Format("Jan 2, 3:04 PM"))

	if s.notifSvc != nil {
		_ = s.notifSvc.CreateTyped(b.StudentID, title, body, "booking_rejected", map[string]string{
			"booking_id": b.ID.String(),
		})
	}
	if s.pushSvc != nil {
		s.pushSvc.SendToUser(b.StudentID, title, body, map[string]string{
			"type":       "booking_rejected",
			"booking_id": b.ID.String(),
		})
	}
}

// ── Helpers ──

func parseTime(s string) (int, int) {
	var h, m int
	fmt.Sscanf(s, "%d:%d", &h, &m)
	return h, m
}

func isBooked(slot Slot, bookings []Booking) bool {
	for _, b := range bookings {
		if slot.StartTime.Equal(b.StartTime) {
			return true
		}
		// Overlap check
		if slot.StartTime.Before(b.EndTime) && slot.EndTime.After(b.StartTime) {
			return true
		}
	}
	return false
}

func isBlocked(slot Slot, blocks []BlockedTime) bool {
	for _, bt := range blocks {
		if slot.StartTime.Before(bt.EndTime) && slot.EndTime.After(bt.StartTime) {
			return true
		}
	}
	return false
}

func isInPrayerWindow(slot Slot, windows []prayer.Window) bool {
	for _, w := range windows {
		if slot.StartTime.Before(w.End) && slot.EndTime.After(w.Start) {
			return true
		}
	}
	return false
}
