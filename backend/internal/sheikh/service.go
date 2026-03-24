package sheikh

import (
	"database/sql"
	"fmt"

	"github.com/google/uuid"
)

// Service handles sheikh directory business logic
type Service struct {
	repo *Repository
}

// NewService creates a new sheikh service
func NewService(db *sql.DB) *Service {
	return &Service{
		repo: NewRepository(db),
	}
}

// ListSheikhs returns all active sheikh profiles for public display
func (s *Service) ListSheikhs() ([]SheikhProfile, error) {
	return s.repo.ListPublicSheikhs()
}

// ──────────── Reviews ────────────

// CreateReview validates and creates a review
func (s *Service) CreateReview(studentID, sheikhID uuid.UUID, lessonRequestID *uuid.UUID, rating int, comment string) error {
	if rating < 1 || rating > 5 {
		return fmt.Errorf("rating must be between 1 and 5")
	}

	// Verify the student had an accepted lesson
	hasLesson, err := s.repo.HasAcceptedLesson(studentID, sheikhID)
	if err != nil {
		return fmt.Errorf("failed to verify lesson: %w", err)
	}
	if !hasLesson {
		return fmt.Errorf("you must have an accepted lesson to rate this sheikh")
	}

	// Check for duplicate review
	if lessonRequestID != nil {
		alreadyReviewed, err := s.repo.HasStudentReviewed(studentID, sheikhID, lessonRequestID)
		if err != nil {
			return fmt.Errorf("failed to check existing review: %w", err)
		}
		if alreadyReviewed {
			return fmt.Errorf("you have already reviewed this lesson")
		}
	}

	review := &SheikhReview{
		SheikhID:        sheikhID,
		StudentID:       studentID,
		LessonRequestID: lessonRequestID,
		Rating:          rating,
		Comment:         comment,
	}
	return s.repo.CreateReview(review)
}

// GetReviews returns all reviews for a sheikh
func (s *Service) GetReviews(sheikhID uuid.UUID) ([]SheikhReview, error) {
	reviews, err := s.repo.GetReviewsBySheikh(sheikhID)
	if err != nil {
		return nil, err
	}
	if reviews == nil {
		reviews = []SheikhReview{}
	}
	return reviews, nil
}

// ──────────── Reports ────────────

// ReportSheikh validates and creates a report
func (s *Service) ReportSheikh(reporterID, sheikhID uuid.UUID, reason string) error {
	if reason == "" {
		return fmt.Errorf("reason is required")
	}

	// Rate limit: max 3 reports per user per day
	count, err := s.repo.CountUserReportsToday(reporterID)
	if err != nil {
		return fmt.Errorf("failed to check report limit: %w", err)
	}
	if count >= 3 {
		return fmt.Errorf("you have reached the daily report limit")
	}

	report := &SheikhReport{
		SheikhID:   sheikhID,
		ReportedBy: reporterID,
		Reason:     reason,
	}
	return s.repo.CreateReport(report)
}

// ListReports returns all reports for admin review
func (s *Service) ListReports() ([]SheikhReport, error) {
	reports, err := s.repo.ListReportsForAdmin()
	if err != nil {
		return nil, err
	}
	if reports == nil {
		reports = []SheikhReport{}
	}
	return reports, nil
}
