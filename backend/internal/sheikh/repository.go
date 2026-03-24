package sheikh

import (
	"database/sql"
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"
)

// SheikhProfile represents a public-facing sheikh profile
type SheikhProfile struct {
	ID                 uuid.UUID      `json:"id"`
	UserID             uuid.UUID      `json:"user_id"`
	DisplayName        *string        `json:"display_name,omitempty"`
	Email              string         `json:"email"`
	AvatarURL          *string        `json:"avatar_url,omitempty"`
	Bio                *string        `json:"bio,omitempty"`
	City               *string        `json:"city,omitempty"`
	Country            *string        `json:"country,omitempty"`
	Specialization     *string        `json:"specialization,omitempty"`
	IjazahInfo         *string        `json:"ijazah_info,omitempty"`
	Certifications     pq.StringArray `json:"certifications"`
	YearsOfExperience  *int           `json:"years_of_experience,omitempty"`
	VerificationStatus string         `json:"verification_status"`
	CreatedAt          time.Time      `json:"created_at"`
	AverageRating      float64        `json:"average_rating"`
	TotalReviews       int            `json:"total_reviews"`
}

// SheikhReview represents a student's review of a sheikh
type SheikhReview struct {
	ID              uuid.UUID `json:"id"`
	SheikhID        uuid.UUID `json:"sheikh_id"`
	StudentID       uuid.UUID `json:"student_id"`
	LessonRequestID *uuid.UUID `json:"lesson_request_id,omitempty"`
	Rating          int       `json:"rating"`
	Comment         string    `json:"comment"`
	StudentName     string    `json:"student_name,omitempty"`
	CreatedAt       time.Time `json:"created_at"`
}

// SheikhReport represents a report against a sheikh
type SheikhReport struct {
	ID         uuid.UUID `json:"id"`
	SheikhID   uuid.UUID `json:"sheikh_id"`
	ReportedBy uuid.UUID `json:"reported_by"`
	Reason     string    `json:"reason"`
	SheikhName string    `json:"sheikh_name,omitempty"`
	ReporterName string  `json:"reporter_name,omitempty"`
	CreatedAt  time.Time `json:"created_at"`
}

// Repository handles database operations for sheikh listings
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new sheikh repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// ListPublicSheikhs returns all active sheikhs with rating aggregation
func (r *Repository) ListPublicSheikhs() ([]SheikhProfile, error) {
	rows, err := r.db.Query(`
		SELECT s.id, s.user_id, u.display_name, u.email,
			   p.avatar_url, p.bio, p.city, p.country,
			   s.specialization, s.ijazah_info, s.certifications,
			   s.years_of_experience, s.verification_status, s.created_at,
			   COALESCE(rv.avg_rating, 0) AS average_rating,
			   COALESCE(rv.total_reviews, 0) AS total_reviews
		FROM sheikhs s
		JOIN users u ON u.id = s.user_id
		LEFT JOIN profiles p ON p.user_id = s.user_id
		LEFT JOIN (
			SELECT sheikh_id, AVG(rating)::numeric(3,2) AS avg_rating, COUNT(*) AS total_reviews
			FROM sheikh_reviews
			GROUP BY sheikh_id
		) rv ON rv.sheikh_id = s.id
		WHERE u.status = 'active'
		ORDER BY
			CASE WHEN s.verification_status = 'verified' THEN 0 ELSE 1 END,
			COALESCE(rv.avg_rating, 0) DESC,
			s.created_at DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sheikhs []SheikhProfile
	for rows.Next() {
		var s SheikhProfile
		err := rows.Scan(
			&s.ID, &s.UserID, &s.DisplayName, &s.Email,
			&s.AvatarURL, &s.Bio, &s.City, &s.Country,
			&s.Specialization, &s.IjazahInfo, &s.Certifications,
			&s.YearsOfExperience, &s.VerificationStatus, &s.CreatedAt,
			&s.AverageRating, &s.TotalReviews,
		)
		if err != nil {
			continue
		}
		sheikhs = append(sheikhs, s)
	}
	return sheikhs, nil
}

// ──────────── Reviews ────────────

// CreateReview inserts a new review
func (r *Repository) CreateReview(review *SheikhReview) error {
	review.ID = uuid.New()
	review.CreatedAt = time.Now()
	_, err := r.db.Exec(`
		INSERT INTO sheikh_reviews (id, sheikh_id, student_id, lesson_request_id, rating, comment, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		review.ID, review.SheikhID, review.StudentID, review.LessonRequestID,
		review.Rating, review.Comment, review.CreatedAt,
	)
	return err
}

// GetReviewsBySheikh returns all reviews for a sheikh
func (r *Repository) GetReviewsBySheikh(sheikhID uuid.UUID) ([]SheikhReview, error) {
	rows, err := r.db.Query(`
		SELECT sr.id, sr.sheikh_id, sr.student_id, sr.lesson_request_id,
		       sr.rating, sr.comment, sr.created_at,
		       COALESCE(u.display_name, u.email) as student_name
		FROM sheikh_reviews sr
		JOIN users u ON u.id = sr.student_id
		WHERE sr.sheikh_id = $1
		ORDER BY sr.created_at DESC`, sheikhID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var reviews []SheikhReview
	for rows.Next() {
		var rv SheikhReview
		if err := rows.Scan(&rv.ID, &rv.SheikhID, &rv.StudentID, &rv.LessonRequestID,
			&rv.Rating, &rv.Comment, &rv.CreatedAt, &rv.StudentName); err != nil {
			continue
		}
		reviews = append(reviews, rv)
	}
	return reviews, nil
}

// HasStudentReviewed checks if a student already reviewed this sheikh for a specific lesson
func (r *Repository) HasStudentReviewed(studentID, sheikhID uuid.UUID, lessonRequestID *uuid.UUID) (bool, error) {
	var exists bool
	err := r.db.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM sheikh_reviews
			WHERE student_id = $1 AND sheikh_id = $2 AND lesson_request_id = $3
		)`, studentID, sheikhID, lessonRequestID).Scan(&exists)
	return exists, err
}

// HasAcceptedLesson checks if a student had an accepted lesson with this sheikh
func (r *Repository) HasAcceptedLesson(studentID, sheikhID uuid.UUID) (bool, error) {
	var exists bool
	err := r.db.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM lesson_requests
			WHERE student_id = $1 AND sheikh_id = $2 AND status = 'accepted'
		)`, studentID, sheikhID).Scan(&exists)
	return exists, err
}

// ──────────── Reports ────────────

// CreateReport inserts a new report
func (r *Repository) CreateReport(report *SheikhReport) error {
	report.ID = uuid.New()
	report.CreatedAt = time.Now()
	_, err := r.db.Exec(`
		INSERT INTO sheikh_reports (id, sheikh_id, reported_by, reason, created_at)
		VALUES ($1, $2, $3, $4, $5)`,
		report.ID, report.SheikhID, report.ReportedBy, report.Reason, report.CreatedAt,
	)
	return err
}

// CountUserReportsToday counts reports submitted by a user today
func (r *Repository) CountUserReportsToday(userID uuid.UUID) (int, error) {
	var count int
	err := r.db.QueryRow(`
		SELECT COUNT(*) FROM sheikh_reports
		WHERE reported_by = $1 AND created_at >= CURRENT_DATE`,
		userID).Scan(&count)
	return count, err
}

// ListReportsForAdmin returns all reports for admin panel
func (r *Repository) ListReportsForAdmin() ([]SheikhReport, error) {
	rows, err := r.db.Query(`
		SELECT sr.id, sr.sheikh_id, sr.reported_by, sr.reason, sr.created_at,
		       COALESCE(us.display_name, us.email) AS sheikh_name,
		       COALESCE(ur.display_name, ur.email) AS reporter_name
		FROM sheikh_reports sr
		JOIN sheikhs s ON s.id = sr.sheikh_id
		JOIN users us ON us.id = s.user_id
		JOIN users ur ON ur.id = sr.reported_by
		ORDER BY sr.created_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var reports []SheikhReport
	for rows.Next() {
		var rpt SheikhReport
		if err := rows.Scan(&rpt.ID, &rpt.SheikhID, &rpt.ReportedBy, &rpt.Reason,
			&rpt.CreatedAt, &rpt.SheikhName, &rpt.ReporterName); err != nil {
			continue
		}
		reports = append(reports, rpt)
	}
	return reports, nil
}
