package lesson

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/notification"
	"github.com/khair/backend/internal/push"
)

// ConversationCreator is the interface the chat service must satisfy
type ConversationCreator interface {
	CreateConversation(studentID, sheikhID uuid.UUID, lessonRequestID *uuid.UUID) error
}

// Service handles lesson request business logic
type Service struct {
	repo     *Repository
	notifSvc *notification.Service
	pushSvc  *push.Service
	chatSvc  ConversationCreator
}

// NewService creates a new lesson service
func NewService(db *sql.DB, notifSvc *notification.Service, pushSvc *push.Service) *Service {
	return &Service{
		repo:     NewRepository(db),
		notifSvc: notifSvc,
		pushSvc:  pushSvc,
	}
}

// SetChatService sets the chat service dependency (breaks circular init)
func (s *Service) SetChatService(cs ConversationCreator) {
	s.chatSvc = cs
}

// CreateRequest creates a new lesson request from a student
func (s *Service) CreateRequest(studentID, sheikhID uuid.UUID, message string, preferredTime *time.Time) (*LessonRequest, error) {
	// Rate limit: max 3 pending per student per sheikh
	count, err := s.repo.CountPending(studentID, sheikhID)
	if err != nil {
		return nil, fmt.Errorf("check pending: %w", err)
	}
	if count >= 3 {
		return nil, fmt.Errorf("you already have %d pending requests to this sheikh", count)
	}

	req := &LessonRequest{
		ID:            uuid.New(),
		StudentID:     studentID,
		SheikhID:      sheikhID,
		Message:       message,
		PreferredTime: preferredTime,
		Status:        "pending",
		CreatedAt:     time.Now(),
		UpdatedAt:     time.Now(),
	}

	if err := s.repo.Create(req); err != nil {
		return nil, fmt.Errorf("create lesson request: %w", err)
	}

	// Notify sheikh
	go s.notifyNewRequest(req)

	return req, nil
}

// GetSheikhRequests returns all requests for a sheikh
func (s *Service) GetSheikhRequests(userID uuid.UUID) ([]LessonRequest, error) {
	return s.repo.ListBySheikhUserID(userID)
}

// GetStudentRequests returns all requests sent by a student
func (s *Service) GetStudentRequests(studentID uuid.UUID) ([]LessonRequest, error) {
	return s.repo.ListByStudentID(studentID)
}

// RespondToRequest lets a sheikh accept or reject a lesson request
func (s *Service) RespondToRequest(userID, requestID uuid.UUID, status string) (*LessonRequest, error) {
	if status != "accepted" && status != "rejected" {
		return nil, fmt.Errorf("status must be 'accepted' or 'rejected'")
	}

	req, err := s.repo.GetByID(requestID)
	if err != nil {
		return nil, fmt.Errorf("request not found")
	}

	// Verify the caller is the correct sheikh
	if !s.repo.IsUserSheikh(userID, req.SheikhID) {
		return nil, fmt.Errorf("you are not authorized to respond to this request")
	}

	if req.Status != "pending" {
		return nil, fmt.Errorf("this request has already been %s", req.Status)
	}

	if err := s.repo.UpdateStatus(requestID, status); err != nil {
		return nil, fmt.Errorf("update status: %w", err)
	}

	req.Status = status

	// Auto-create conversation on accept
	if status == "accepted" && s.chatSvc != nil {
		go func() {
			_ = s.chatSvc.CreateConversation(req.StudentID, req.SheikhID, &req.ID)
		}()
	}

	// Notify student
	go s.notifyResponse(req)

	return req, nil
}

func (s *Service) notifyNewRequest(req *LessonRequest) {
	sheikhUserID, err := s.repo.GetSheikhUserID(req.SheikhID)
	if err != nil {
		return
	}

	title := "New Lesson Request"
	body := fmt.Sprintf("A student has requested a lesson: %s", truncate(req.Message, 80))

	if s.notifSvc != nil {
		_ = s.notifSvc.CreateTyped(sheikhUserID, title, body, "lesson_request", map[string]string{
			"request_id": req.ID.String(),
		})
	}
	if s.pushSvc != nil {
		s.pushSvc.SendToUser(sheikhUserID, title, body, map[string]string{
			"type":       "lesson_request",
			"request_id": req.ID.String(),
		})
	}
}

func (s *Service) notifyResponse(req *LessonRequest) {
	var title, body string
	if req.Status == "accepted" {
		title = "Lesson Request Accepted!"
		body = "Your lesson request has been accepted. You can now start chatting."
	} else {
		title = "Lesson Request Declined"
		body = "Your lesson request was declined by the sheikh."
	}

	if s.notifSvc != nil {
		_ = s.notifSvc.CreateTyped(req.StudentID, title, body, "lesson_response", map[string]string{
			"request_id": req.ID.String(),
			"status":     req.Status,
		})
	}
	if s.pushSvc != nil {
		s.pushSvc.SendToUser(req.StudentID, title, body, map[string]string{
			"type":       "lesson_response",
			"request_id": req.ID.String(),
			"status":     req.Status,
		})
	}
}

// ScheduleLesson sets the meeting details for an accepted lesson request
func (s *Service) ScheduleLesson(userID, reqID uuid.UUID, meetingLink, meetingPlatform string, scheduledTime time.Time) error {
	req, err := s.repo.GetByID(reqID)
	if err != nil {
		return fmt.Errorf("lesson request not found")
	}

	// Only the sheikh can schedule
	if !s.repo.IsUserSheikh(userID, req.SheikhID) {
		return fmt.Errorf("only the sheikh can schedule lessons")
	}

	if req.Status != "accepted" {
		return fmt.Errorf("only accepted requests can be scheduled")
	}

	if err := s.repo.Schedule(reqID, meetingLink, meetingPlatform, scheduledTime); err != nil {
		return fmt.Errorf("failed to schedule: %w", err)
	}

	// Notify the student
	title := "Lesson Scheduled! 📅"
	body := fmt.Sprintf("Your lesson has been scheduled via %s", meetingPlatform)
	if s.notifSvc != nil {
		_ = s.notifSvc.CreateTyped(req.StudentID, title, body, "lesson_scheduled", map[string]string{
			"request_id": reqID.String(),
		})
	}
	if s.pushSvc != nil {
		s.pushSvc.SendToUser(req.StudentID, title, body, map[string]string{
			"type":       "lesson_scheduled",
			"request_id": reqID.String(),
		})
	}

	return nil
}

func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}
