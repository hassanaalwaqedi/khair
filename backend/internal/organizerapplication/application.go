// Package organizerapplication owns the organizer trust gateway. It keeps the
// detailed application dossier separate from the legacy organizers profile,
// which remains the compatibility layer for existing event APIs.
package organizerapplication

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/khair/backend/internal/notification"
	"github.com/khair/backend/internal/push"
	"github.com/khair/backend/pkg/email"
)

const GuidelinesVersion = "2026-08"

const (
	StatusDraft         = "draft"
	StatusPending       = "pending"
	StatusNeedsRevision = "needs_revision"
	StatusApproved      = "approved"
	StatusRejected      = "rejected"
	StatusSuspended     = "suspended"
)

var organizerTypes = map[string]struct{}{
	"individual": {}, "community": {}, "mosque": {}, "charity": {},
	"company": {}, "school": {}, "other": {},
}

var categorySlugs = map[string]struct{}{
	"community": {}, "charity": {}, "lecture": {}, "workshop": {},
	"conference": {}, "family": {}, "youth": {}, "technology": {},
	"online": {}, "education": {}, "social_gathering": {}, "other": {},
}

var audienceValues = map[string]struct{}{
	"everyone": {}, "men": {}, "women": {}, "families": {}, "youth": {},
	"students": {}, "professionals": {}, "other": {},
}

var countryCodePattern = regexp.MustCompile(`^[A-Z]{2}$`)
var phonePattern = regexp.MustCompile(`^\+[1-9][0-9 ()-]{6,23}$`)

type Link struct {
	ID       string `json:"id,omitempty"`
	Platform string `json:"platform"`
	URL      string `json:"url"`
}

type Evidence struct {
	ID           string `json:"id,omitempty"`
	EvidenceType string `json:"evidence_type"`
	URL          string `json:"url,omitempty"`
	Note         string `json:"note,omitempty"`
}

type VerificationFile struct {
	ID               string    `json:"id"`
	FileType         string    `json:"file_type"`
	OriginalFilename string    `json:"original_filename"`
	MimeType         string    `json:"mime_type"`
	SizeBytes        int64     `json:"size_bytes"`
	ApplicantNote    string    `json:"applicant_note,omitempty"`
	UploadedAt       time.Time `json:"uploaded_at"`
}

type Application struct {
	ID                     uuid.UUID          `json:"id"`
	UserID                 uuid.UUID          `json:"user_id"`
	Status                 string             `json:"status"`
	OrganizerType          string             `json:"organizer_type,omitempty"`
	PublicName             string             `json:"public_name,omitempty"`
	RepresentativeName     string             `json:"representative_name,omitempty"`
	AccountEmail           string             `json:"account_email,omitempty"`
	ContactEmail           string             `json:"contact_email,omitempty"`
	ContactEmailVerified   bool               `json:"contact_email_verified"`
	Phone                  string             `json:"phone,omitempty"`
	CountryCode            string             `json:"country_code,omitempty"`
	City                   string             `json:"city,omitempty"`
	Description            string             `json:"description,omitempty"`
	PublicLogoKey          string             `json:"-"`
	RepresentativePhotoKey string             `json:"-"`
	HasPublicLogo          bool               `json:"has_public_logo"`
	HasRepresentativePhoto bool               `json:"has_representative_photo"`
	EventPlan              string             `json:"event_plan,omitempty"`
	TypicalAudience        []string           `json:"typical_audience"`
	GuidelinesVersion      string             `json:"guidelines_version,omitempty"`
	GuidelinesAcceptedAt   *time.Time         `json:"guidelines_accepted_at,omitempty"`
	SubmittedAt            *time.Time         `json:"submitted_at,omitempty"`
	ResubmittedAt          *time.Time         `json:"resubmitted_at,omitempty"`
	ReviewedAt             *time.Time         `json:"reviewed_at,omitempty"`
	ReviewedBy             *uuid.UUID         `json:"reviewed_by,omitempty"`
	AdminReasonCode        string             `json:"admin_reason_code,omitempty"`
	AdminUserMessage       string             `json:"admin_user_message,omitempty"`
	InternalAdminNote      string             `json:"-"`
	RevisionCount          int                `json:"revision_count"`
	CreatedAt              time.Time          `json:"created_at"`
	UpdatedAt              time.Time          `json:"updated_at"`
	Links                  []Link             `json:"links"`
	EventCategories        []string           `json:"event_categories"`
	Evidence               []Evidence         `json:"evidence"`
	VerificationFiles      []VerificationFile `json:"verification_files"`
	AccountCreatedAt       *time.Time         `json:"account_created_at,omitempty"`
	AccountEmailVerified   bool               `json:"account_email_verified"`
}

// AdminView is intentionally separate from the applicant JSON shape so an
// internal reviewer note can never leak through the /me endpoint.
func (a *Application) AdminView() map[string]any {
	data, _ := json.Marshal(a)
	view := map[string]any{}
	_ = json.Unmarshal(data, &view)
	view["internal_admin_note"] = a.InternalAdminNote
	return view
}

type DraftInput struct {
	OrganizerType      string     `json:"organizer_type"`
	PublicName         string     `json:"public_name"`
	RepresentativeName string     `json:"representative_name"`
	ContactEmail       string     `json:"contact_email"`
	Phone              string     `json:"phone"`
	CountryCode        string     `json:"country_code"`
	City               string     `json:"city"`
	Description        string     `json:"description"`
	EventPlan          string     `json:"event_plan"`
	TypicalAudience    []string   `json:"typical_audience"`
	GuidelinesAccepted bool       `json:"guidelines_accepted"`
	GuidelinesVersion  string     `json:"guidelines_version"`
	Links              []Link     `json:"links"`
	EventCategories    []string   `json:"event_categories"`
	Evidence           []Evidence `json:"evidence"`
}

type DecisionInput struct {
	ReasonCode   string `json:"reason_code"`
	UserMessage  string `json:"user_message"`
	InternalNote string `json:"internal_note"`
}

type identity struct {
	Email     string
	Verified  bool
	Language  string
	CreatedAt time.Time
}

type Service struct {
	db            *sql.DB
	notifications *notification.Service
	push          *push.Service
	email         *email.Service
	media         *S3Store
}

func NewService(db *sql.DB, notifications *notification.Service, pushService *push.Service, emailService *email.Service) *Service {
	return &Service{
		db:            db,
		notifications: notifications,
		push:          pushService,
		email:         emailService,
		media:         NewS3StoreFromEnv(),
	}
}

func (s *Service) GetMine(ctx context.Context, userID uuid.UUID) (*Application, error) {
	app, err := s.getByUserID(ctx, s.db, userID, false)
	if err != nil {
		return nil, err
	}
	return app, nil
}

func (s *Service) SaveDraft(ctx context.Context, userID uuid.UUID, input DraftInput) (*Application, error) {
	input.normalize()
	if err := validateDraft(input); err != nil {
		return nil, err
	}
	identity, err := s.identity(ctx, userID)
	if err != nil {
		return nil, err
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin draft transaction: %w", err)
	}
	defer tx.Rollback()

	app, err := s.getByUserID(ctx, tx, userID, true)
	if errors.Is(err, sql.ErrNoRows) {
		app = &Application{ID: uuid.New(), UserID: userID, Status: StatusDraft}
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO organizer_applications (id, user_id, status, account_email)
			VALUES ($1, $2, 'draft', $3)`, app.ID, userID, identity.Email); err != nil {
			return nil, fmt.Errorf("create organizer draft: %w", err)
		}
	} else if err != nil {
		return nil, err
	}
	if app.Status == StatusPending || app.Status == StatusApproved || app.Status == StatusSuspended || app.Status == StatusRejected {
		return nil, errors.New("this organizer application cannot be edited in its current status")
	}

	if err := s.writeDraft(ctx, tx, app, input, identity); err != nil {
		return nil, err
	}
	if err := s.replaceRelations(ctx, tx, app.ID, input); err != nil {
		return nil, err
	}
	if err := s.appendRevision(ctx, tx, app.ID, &userID, "draft_saved", appSnapshot(input), "", ""); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit organizer draft: %w", err)
	}
	return s.GetMine(ctx, userID)
}

func (s *Service) Submit(ctx context.Context, userID uuid.UUID, resubmission bool) (*Application, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin submit transaction: %w", err)
	}
	defer tx.Rollback()

	app, err := s.getByUserID(ctx, tx, userID, true)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, errors.New("save your organizer application before submitting")
		}
		return nil, err
	}
	if app.Status == StatusPending || app.Status == StatusApproved || app.Status == StatusSuspended || app.Status == StatusRejected {
		return nil, errors.New("this organizer application cannot be submitted in its current status")
	}
	identity, err := s.identity(ctx, userID)
	if err != nil {
		return nil, err
	}
	if err := validateSubmission(app, identity); err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	action := "submitted"
	if resubmission || app.Status == StatusNeedsRevision {
		action = "resubmitted"
	}
	snapshot, _ := json.Marshal(app)
	_, err = tx.ExecContext(ctx, `
		UPDATE organizer_applications
		SET status = 'pending', submitted_snapshot = $2, submitted_at = COALESCE(submitted_at, $3),
		    resubmitted_at = CASE WHEN $4 THEN $3 ELSE resubmitted_at END,
		    admin_reason_code = NULL, admin_user_message = NULL, internal_admin_note = NULL,
		    updated_at = $3
		WHERE id = $1`, app.ID, snapshot, now, action == "resubmitted")
	if err != nil {
		return nil, fmt.Errorf("submit organizer application: %w", err)
	}
	if err := s.upsertLegacyOrganizer(ctx, tx, app, "pending", nil, ""); err != nil {
		return nil, err
	}
	if err := s.appendRevision(ctx, tx, app.ID, &userID, action, snapshot, "", ""); err != nil {
		return nil, err
	}
	if s.notifications == nil {
		if _, err := tx.ExecContext(ctx, `
		INSERT INTO notifications (user_id, title, message, notification_type, data)
		SELECT DISTINCT reviewer.user_id, 'Organizer application submitted', 'A new organizer application is ready for review.', 'organizer_application',
		       jsonb_build_object('application_id', $1::text, 'path', '/admin/organizer-applications/' || $1::text)
		FROM (
			SELECT id AS user_id FROM users WHERE role IN ('admin', 'super_admin')
			UNION
			SELECT ur.user_id FROM user_roles ur JOIN roles r ON r.id = ur.role_id
			WHERE r.name IN ('admin', 'super_admin')
		) AS reviewer`, app.ID); err != nil {
			return nil, fmt.Errorf("notify administrators: %w", err)
		}
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit organizer submission: %w", err)
	}
	s.notifyReviewers(app.ID)
	return s.GetMine(ctx, userID)
}

func (s *Service) ListForAdmin(ctx context.Context, status string) ([]Application, error) {
	query := `SELECT a.id, a.user_id, a.status, COALESCE(a.organizer_type, ''), COALESCE(a.public_name, ''),
		COALESCE(a.representative_name, ''), COALESCE(a.country_code, ''), COALESCE(a.city, ''),
		a.submitted_at, a.created_at, a.updated_at, COALESCE(a.public_logo_key, '')
		FROM organizer_applications a`
	args := []any{}
	if status != "" {
		query += " WHERE a.status = $1"
		args = append(args, status)
	}
	query += " ORDER BY a.submitted_at NULLS LAST, a.created_at ASC"
	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list organizer applications: %w", err)
	}
	defer rows.Close()
	apps := []Application{}
	for rows.Next() {
		var app Application
		if err := rows.Scan(&app.ID, &app.UserID, &app.Status, &app.OrganizerType, &app.PublicName,
			&app.RepresentativeName, &app.CountryCode, &app.City, &app.SubmittedAt, &app.CreatedAt,
			&app.UpdatedAt, &app.PublicLogoKey); err != nil {
			return nil, err
		}
		app.HasPublicLogo = app.PublicLogoKey != ""
		apps = append(apps, app)
	}
	return apps, rows.Err()
}

func (s *Service) GetForAdmin(ctx context.Context, applicationID uuid.UUID) (*Application, error) {
	app, err := s.getByID(ctx, s.db, applicationID, false)
	if err != nil {
		return nil, err
	}
	return app, nil
}

func (s *Service) Decide(ctx context.Context, adminID, applicationID uuid.UUID, decision string, input DecisionInput) (*Application, error) {
	if decision != StatusApproved && decision != StatusNeedsRevision && decision != StatusRejected {
		return nil, errors.New("invalid organizer application decision")
	}
	input.ReasonCode = strings.TrimSpace(strings.ToLower(input.ReasonCode))
	input.UserMessage = strings.TrimSpace(input.UserMessage)
	input.InternalNote = strings.TrimSpace(input.InternalNote)
	if decision == StatusNeedsRevision && input.UserMessage == "" {
		return nil, errors.New("a message is required when requesting changes")
	}
	if decision == StatusRejected && (input.ReasonCode == "" || input.UserMessage == "") {
		return nil, errors.New("a reason code and user-facing explanation are required when rejecting")
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	app, err := s.getByID(ctx, tx, applicationID, true)
	if err != nil {
		return nil, err
	}
	if app.Status != StatusPending {
		return nil, errors.New("only applications under review can receive a decision")
	}
	now := time.Now().UTC()
	_, err = tx.ExecContext(ctx, `
		UPDATE organizer_applications SET status = $2, reviewed_at = $3, reviewed_by = $4,
		admin_reason_code = $5, admin_user_message = $6, internal_admin_note = $7,
		revision_count = revision_count + CASE WHEN $2 = 'needs_revision' THEN 1 ELSE 0 END,
		updated_at = $3 WHERE id = $1`, app.ID, decision, now, adminID, nullable(input.ReasonCode), nullable(input.UserMessage), nullable(input.InternalNote))
	if err != nil {
		return nil, fmt.Errorf("update organizer decision: %w", err)
	}
	legacyReason := input.UserMessage
	if err := s.upsertLegacyOrganizer(ctx, tx, app, decision, nullable(legacyReason), s.publicLogoURL(app.ID)); err != nil {
		return nil, err
	}
	if decision == StatusApproved {
		if _, err := tx.ExecContext(ctx, `UPDATE users SET role = 'organizer', updated_at = $2 WHERE id = $1 AND role = 'user'`, app.UserID, now); err != nil {
			return nil, err
		}
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO user_roles (user_id, role_id, assigned_at, assigned_by)
			SELECT $1, id, $3, $2 FROM roles WHERE name = 'organizer'
			ON CONFLICT (user_id, role_id) DO NOTHING`, app.UserID, adminID, now); err != nil {
			return nil, err
		}
	} else if decision == StatusRejected {
		if _, err := tx.ExecContext(ctx, `DELETE FROM user_roles WHERE user_id = $1 AND role_id = (SELECT id FROM roles WHERE name = 'organizer')`, app.UserID); err != nil {
			return nil, err
		}
		if _, err := tx.ExecContext(ctx, `UPDATE users SET role = 'user', updated_at = $2 WHERE id = $1 AND role = 'organizer'`, app.UserID, now); err != nil {
			return nil, err
		}
	}
	snapshot, _ := json.Marshal(app)
	if err := s.appendRevision(ctx, tx, app.ID, &adminID, decision, snapshot, input.UserMessage, input.InternalNote); err != nil {
		return nil, err
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO organizer_application_decisions (application_id, admin_id, decision, reason_code, user_message, internal_note) VALUES ($1,$2,$3,$4,$5,$6)`, app.ID, adminID, decision, nullable(input.ReasonCode), nullable(input.UserMessage), nullable(input.InternalNote)); err != nil {
		return nil, err
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO rbac_audit_log (actor_id, action, target_user_id, details) VALUES ($1, $2, $3, $4)`, adminID, "organizer_application_"+decision, app.UserID, snapshot); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit organizer decision: %w", err)
	}

	updated, err := s.GetForAdmin(ctx, app.ID)
	if err != nil {
		return nil, err
	}
	s.deliverDecision(updated, decision, input.UserMessage)
	return updated, nil
}

func (s *Service) UploadLogo(ctx context.Context, userID uuid.UUID, filename, mime string, data []byte) (*Application, error) {
	if err := validateImage(filename, mime, int64(len(data))); err != nil {
		return nil, err
	}
	app, err := s.ensureDraft(ctx, userID)
	if err != nil {
		return nil, err
	}
	previousKey := app.PublicLogoKey
	key := fmt.Sprintf("organizers/applications/%s/logo/current", app.ID)
	if err := s.media.Put(ctx, key, data, mime); err != nil {
		return nil, err
	}
	if _, err := s.db.ExecContext(ctx, `UPDATE organizer_applications SET public_logo_key = $2, updated_at = NOW() WHERE id = $1`, app.ID, key); err != nil {
		if previousKey != key {
			_ = s.media.Delete(context.Background(), key)
		}
		return nil, err
	}
	if previousKey != "" && previousKey != key {
		_ = s.media.Delete(context.Background(), previousKey)
	}
	return s.GetMine(ctx, userID)
}

func (s *Service) UploadRepresentativePhoto(ctx context.Context, userID uuid.UUID, filename, mime string, data []byte) (*Application, error) {
	if err := validateImage(filename, mime, int64(len(data))); err != nil {
		return nil, err
	}
	app, err := s.ensureDraft(ctx, userID)
	if err != nil {
		return nil, err
	}
	previousKey := app.RepresentativePhotoKey
	key := fmt.Sprintf("organizers/applications/%s/profile/current", app.ID)
	if err := s.media.Put(ctx, key, data, mime); err != nil {
		return nil, err
	}
	if _, err := s.db.ExecContext(ctx, `UPDATE organizer_applications SET representative_photo_key = $2, updated_at = NOW() WHERE id = $1`, app.ID, key); err != nil {
		if previousKey != key {
			_ = s.media.Delete(context.Background(), key)
		}
		return nil, err
	}
	if previousKey != "" && previousKey != key {
		_ = s.media.Delete(context.Background(), previousKey)
	}
	return s.GetMine(ctx, userID)
}

func (s *Service) UploadVerificationFile(ctx context.Context, userID uuid.UUID, fileType, note, filename, mime string, data []byte) (*VerificationFile, error) {
	if err := validateDocument(fileType, filename, mime, int64(len(data))); err != nil {
		return nil, err
	}
	app, err := s.ensureDraft(ctx, userID)
	if err != nil {
		return nil, err
	}
	key := fmt.Sprintf("organizers/applications/%s/verification/%s", app.ID, safeFilename(filename))
	if err := s.media.Put(ctx, key, data, mime); err != nil {
		return nil, err
	}
	file := &VerificationFile{ID: uuid.NewString(), FileType: fileType, OriginalFilename: safeDisplayFilename(filename), MimeType: mime, SizeBytes: int64(len(data)), ApplicantNote: strings.TrimSpace(note), UploadedAt: time.Now().UTC()}
	if _, err := s.db.ExecContext(ctx, `INSERT INTO organizer_verification_files (id, application_id, file_type, storage_key, original_filename, mime_type, size_bytes, applicant_note) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`, file.ID, app.ID, file.FileType, key, file.OriginalFilename, file.MimeType, file.SizeBytes, nullable(file.ApplicantNote)); err != nil {
		_ = s.media.Delete(context.Background(), key)
		return nil, err
	}
	return file, nil
}

func (s *Service) AdminDocumentURL(ctx context.Context, adminID, applicationID, fileID uuid.UUID) (string, error) {
	var key string
	err := s.db.QueryRowContext(ctx, `SELECT storage_key FROM organizer_verification_files WHERE id = $1 AND application_id = $2`, fileID, applicationID).Scan(&key)
	if err != nil {
		return "", err
	}
	url, err := s.media.SignedGetURL(key, 10*time.Minute)
	if err != nil {
		return "", err
	}
	_, _ = s.db.ExecContext(ctx, `INSERT INTO organizer_application_revisions (application_id, actor_user_id, action, snapshot) VALUES ($1,$2,'document_accessed',jsonb_build_object('file_id',$3))`, applicationID, adminID, fileID)
	return url, nil
}

func (s *Service) AdminMediaURL(ctx context.Context, adminID, applicationID uuid.UUID, kind string) (string, error) {
	app, err := s.getByID(ctx, s.db, applicationID, false)
	if err != nil {
		return "", err
	}
	var key string
	switch kind {
	case "logo":
		key = app.PublicLogoKey
	case "representative-photo":
		key = app.RepresentativePhotoKey
	default:
		return "", errors.New("invalid organizer media type")
	}
	if key == "" {
		return "", sql.ErrNoRows
	}
	url, err := s.media.SignedGetURL(key, 10*time.Minute)
	if err != nil {
		return "", err
	}
	_, _ = s.db.ExecContext(ctx, `INSERT INTO organizer_application_revisions (application_id, actor_user_id, action, snapshot) VALUES ($1,$2,'document_accessed',jsonb_build_object('media',$3))`, applicationID, adminID, kind)
	return url, nil
}

// databaseQuery is intentionally minimal so the same scanner works for DB and transaction queries.
type databaseQuery interface {
	QueryRowContext(context.Context, string, ...any) *sql.Row
	QueryContext(context.Context, string, ...any) (*sql.Rows, error)
}
type databaseExec interface {
	databaseQuery
	ExecContext(context.Context, string, ...any) (sql.Result, error)
}

func (s *Service) getByUserID(ctx context.Context, q databaseQuery, userID uuid.UUID, lock bool) (*Application, error) {
	query := applicationSelect + " WHERE a.user_id = $1"
	if lock {
		query += " FOR UPDATE"
	}
	app, err := scanApplication(q.QueryRowContext(ctx, query, userID))
	if err != nil {
		return nil, err
	}
	return s.loadRelations(ctx, q, app)
}

func (s *Service) getByID(ctx context.Context, q databaseQuery, id uuid.UUID, lock bool) (*Application, error) {
	query := applicationSelect + " WHERE a.id = $1"
	if lock {
		query += " FOR UPDATE"
	}
	app, err := scanApplication(q.QueryRowContext(ctx, query, id))
	if err != nil {
		return nil, err
	}
	return s.loadRelations(ctx, q, app)
}

const applicationSelect = `SELECT a.id, a.user_id, a.status, COALESCE(a.organizer_type,''), COALESCE(a.public_name,''),
 COALESCE(a.representative_name,''), COALESCE(a.account_email,''), COALESCE(a.contact_email,''), a.contact_email_verified,
 COALESCE(a.phone,''), COALESCE(a.country_code,''), COALESCE(a.city,''), COALESCE(a.description,''),
 COALESCE(a.public_logo_key,''), COALESCE(a.representative_photo_key,''), COALESCE(a.event_plan,''),
 a.typical_audience, COALESCE(a.guidelines_version,''), a.guidelines_accepted_at, a.submitted_at,
 a.resubmitted_at, a.reviewed_at, a.reviewed_by, COALESCE(a.admin_reason_code,''), COALESCE(a.admin_user_message,''), COALESCE(a.internal_admin_note,''),
 a.revision_count, a.created_at, a.updated_at, u.created_at, u.is_verified
 FROM organizer_applications a JOIN users u ON u.id = a.user_id`

func scanApplication(row *sql.Row) (*Application, error) {
	app := &Application{Links: []Link{}, EventCategories: []string{}, Evidence: []Evidence{}, VerificationFiles: []VerificationFile{}, TypicalAudience: []string{}}
	var audienceJSON []byte
	if err := row.Scan(&app.ID, &app.UserID, &app.Status, &app.OrganizerType, &app.PublicName, &app.RepresentativeName,
		&app.AccountEmail, &app.ContactEmail, &app.ContactEmailVerified, &app.Phone, &app.CountryCode, &app.City,
		&app.Description, &app.PublicLogoKey, &app.RepresentativePhotoKey, &app.EventPlan, &audienceJSON,
		&app.GuidelinesVersion, &app.GuidelinesAcceptedAt, &app.SubmittedAt, &app.ResubmittedAt, &app.ReviewedAt,
		&app.ReviewedBy, &app.AdminReasonCode, &app.AdminUserMessage, &app.InternalAdminNote, &app.RevisionCount, &app.CreatedAt, &app.UpdatedAt,
		&app.AccountCreatedAt, &app.AccountEmailVerified); err != nil {
		return nil, err
	}
	_ = json.Unmarshal(audienceJSON, &app.TypicalAudience)
	app.HasPublicLogo = app.PublicLogoKey != ""
	app.HasRepresentativePhoto = app.RepresentativePhotoKey != ""
	return app, nil
}

func (s *Service) loadRelations(ctx context.Context, q databaseQuery, app *Application) (*Application, error) {
	links, err := q.QueryContext(ctx, `SELECT id, platform, url FROM organizer_application_links WHERE application_id=$1 ORDER BY created_at`, app.ID)
	if err != nil {
		return nil, err
	}
	defer links.Close()
	for links.Next() {
		var link Link
		if err := links.Scan(&link.ID, &link.Platform, &link.URL); err != nil {
			return nil, err
		}
		app.Links = append(app.Links, link)
	}
	categories, err := q.QueryContext(ctx, `SELECT category_slug FROM organizer_application_categories WHERE application_id=$1 ORDER BY category_slug`, app.ID)
	if err != nil {
		return nil, err
	}
	defer categories.Close()
	for categories.Next() {
		var category string
		if err := categories.Scan(&category); err != nil {
			return nil, err
		}
		app.EventCategories = append(app.EventCategories, category)
	}
	evidence, err := q.QueryContext(ctx, `SELECT id,evidence_type,COALESCE(url,''),COALESCE(note,'') FROM organizer_application_evidence WHERE application_id=$1 ORDER BY created_at`, app.ID)
	if err != nil {
		return nil, err
	}
	defer evidence.Close()
	for evidence.Next() {
		var item Evidence
		if err := evidence.Scan(&item.ID, &item.EvidenceType, &item.URL, &item.Note); err != nil {
			return nil, err
		}
		app.Evidence = append(app.Evidence, item)
	}
	files, err := q.QueryContext(ctx, `SELECT id,file_type,original_filename,mime_type,size_bytes,COALESCE(applicant_note,''),uploaded_at FROM organizer_verification_files WHERE application_id=$1 ORDER BY uploaded_at DESC`, app.ID)
	if err != nil {
		return nil, err
	}
	defer files.Close()
	for files.Next() {
		var file VerificationFile
		if err := files.Scan(&file.ID, &file.FileType, &file.OriginalFilename, &file.MimeType, &file.SizeBytes, &file.ApplicantNote, &file.UploadedAt); err != nil {
			return nil, err
		}
		app.VerificationFiles = append(app.VerificationFiles, file)
	}
	return app, nil
}

func (s *Service) identity(ctx context.Context, userID uuid.UUID) (identity, error) {
	var value identity
	err := s.db.QueryRowContext(ctx, `SELECT u.email,u.is_verified,COALESCE(p.preferred_language,'en'),u.created_at FROM users u LEFT JOIN profiles p ON p.user_id=u.id WHERE u.id=$1`, userID).Scan(&value.Email, &value.Verified, &value.Language, &value.CreatedAt)
	if err != nil {
		return identity{}, fmt.Errorf("load account identity: %w", err)
	}
	return value, nil
}

func (s *Service) writeDraft(ctx context.Context, tx *sql.Tx, app *Application, input DraftInput, identity identity) error {
	guidelinesAcceptedAt := any(nil)
	guidelinesVersion := any(nil)
	if input.GuidelinesAccepted {
		guidelinesAcceptedAt = time.Now().UTC()
		guidelinesVersion = nullable(input.GuidelinesVersion)
	}
	_, err := tx.ExecContext(ctx, `UPDATE organizer_applications SET organizer_type=$2,public_name=$3,representative_name=$4,account_email=$5,contact_email=$6,contact_email_verified=$7,phone=$8,country_code=$9,city=$10,description=$11,event_plan=$12,typical_audience=$13,guidelines_version=$14,guidelines_accepted_at=$15,updated_at=NOW() WHERE id=$1`,
		app.ID, nullable(input.OrganizerType), nullable(input.PublicName), nullable(input.RepresentativeName), identity.Email,
		nullable(input.ContactEmail), input.ContactEmail != "" && strings.EqualFold(input.ContactEmail, identity.Email) && identity.Verified,
		nullable(input.Phone), nullable(input.CountryCode), nullable(input.City), nullable(input.Description), nullable(input.EventPlan),
		mustJSON(input.TypicalAudience), guidelinesVersion, guidelinesAcceptedAt)
	if err != nil {
		return fmt.Errorf("save organizer application draft: %w", err)
	}
	return nil
}

func (s *Service) replaceRelations(ctx context.Context, tx *sql.Tx, applicationID uuid.UUID, input DraftInput) error {
	for _, table := range []string{"organizer_application_links", "organizer_application_categories", "organizer_application_evidence"} {
		if _, err := tx.ExecContext(ctx, "DELETE FROM "+table+" WHERE application_id=$1", applicationID); err != nil {
			return err
		}
	}
	for _, link := range input.Links {
		if _, err := tx.ExecContext(ctx, `INSERT INTO organizer_application_links (application_id,platform,url) VALUES ($1,$2,$3)`, applicationID, link.Platform, link.URL); err != nil {
			return err
		}
	}
	for _, category := range uniqueSorted(input.EventCategories) {
		if _, err := tx.ExecContext(ctx, `INSERT INTO organizer_application_categories (application_id,category_slug) VALUES ($1,$2)`, applicationID, category); err != nil {
			return err
		}
	}
	for _, evidence := range input.Evidence {
		if _, err := tx.ExecContext(ctx, `INSERT INTO organizer_application_evidence (application_id,evidence_type,url,note) VALUES ($1,$2,$3,$4)`, applicationID, evidence.EvidenceType, nullable(evidence.URL), nullable(evidence.Note)); err != nil {
			return err
		}
	}
	return nil
}

func (s *Service) upsertLegacyOrganizer(ctx context.Context, tx *sql.Tx, app *Application, status string, reason any, logoURL string) error {
	// The legacy organizers table is intentionally retained as a compatibility
	// bridge for event authorization and only accepts pending/approved/rejected.
	// The dossier above remains the canonical source for needs_revision.
	legacyStatus := status
	if status == StatusNeedsRevision {
		legacyStatus = StatusPending
	}
	legacyType := app.OrganizerType
	switch app.OrganizerType {
	case "individual", "company":
		legacyType = "other"
	case "school":
		legacyType = "educational"
	}
	var organizerID uuid.UUID
	err := tx.QueryRowContext(ctx, `SELECT id FROM organizers WHERE user_id=$1 FOR UPDATE`, app.UserID).Scan(&organizerID)
	if errors.Is(err, sql.ErrNoRows) {
		_, err = tx.ExecContext(ctx, `INSERT INTO organizers (id,user_id,name,description,website,phone,logo_url,status,country,city,contact_email,organization_type) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`, uuid.New(), app.UserID, app.PublicName, nullable(app.Description), firstWebsite(app.Links), nullable(app.Phone), nullable(logoURL), legacyStatus, nullable(app.CountryCode), nullable(app.City), nullable(app.ContactEmail), nullable(legacyType))
	} else if err == nil {
		_, err = tx.ExecContext(ctx, `UPDATE organizers SET name=$2,description=$3,website=$4,phone=$5,logo_url=COALESCE($6,logo_url),status=$7,rejection_reason=$8,country=$9,city=$10,contact_email=$11,organization_type=$12,updated_at=NOW() WHERE id=$1`, organizerID, app.PublicName, nullable(app.Description), firstWebsite(app.Links), nullable(app.Phone), nullable(logoURL), legacyStatus, reason, nullable(app.CountryCode), nullable(app.City), nullable(app.ContactEmail), nullable(legacyType))
	}
	if err != nil {
		return fmt.Errorf("synchronize organizer access record: %w", err)
	}
	return nil
}

func (s *Service) appendRevision(ctx context.Context, tx *sql.Tx, applicationID uuid.UUID, actorID *uuid.UUID, action string, snapshot []byte, userMessage, internalNote string) error {
	_, err := tx.ExecContext(ctx, `INSERT INTO organizer_application_revisions (application_id,actor_user_id,action,snapshot,user_message,internal_note) VALUES ($1,$2,$3,$4,$5,$6)`, applicationID, actorID, action, snapshot, nullable(userMessage), nullable(internalNote))
	return err
}

func (s *Service) ensureDraft(ctx context.Context, userID uuid.UUID) (*Application, error) {
	app, err := s.GetMine(ctx, userID)
	if err == nil {
		if app.Status == StatusPending || app.Status == StatusApproved || app.Status == StatusSuspended || app.Status == StatusRejected {
			return nil, errors.New("this organizer application cannot accept uploads in its current status")
		}
		return app, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return nil, err
	}
	_, err = s.SaveDraft(ctx, userID, DraftInput{})
	if err != nil {
		return nil, err
	}
	return s.GetMine(ctx, userID)
}

func (s *Service) deliverDecision(app *Application, decision, message string) {
	identity, err := s.identity(context.Background(), app.UserID)
	if err != nil {
		return
	}
	data := map[string]string{
		"status":         decision,
		"organizer_name": app.PublicName,
		"reason":         message,
		"entity_type":    "organizer_application",
		"entity_id":      app.ID.String(),
		"application_id": app.ID.String(),
		"path":           "/organizer/apply",
	}
	copy := notification.Render("organizer_application", data, identity.Language)
	title, body := copy.Title, copy.Message
	if title == "" || body == "" {
		title, body = localizedDecision(decision, app.PublicName, message, identity.Language)
	}
	if s.notifications != nil {
		if localized, err := s.notifications.LocalizeForUser(app.UserID, "organizer_application", data); err == nil {
			title, body = localized.Title, localized.Message
		}
		_ = s.notifications.CreateTyped(app.UserID, title, body, "organizer_application", data)
	}
	if s.push != nil {
		s.push.SendToUser(app.UserID, title, body, data)
	}
	if s.email != nil {
		_ = s.email.SendNotificationEmail(identity.Email, title, body, identity.Language)
	}
}

// notifyReviewers creates one localized notification per reviewer after the
// application transaction commits. Reviewer language is resolved from each
// account rather than using the applicant's language.
func (s *Service) notifyReviewers(applicationID uuid.UUID) {
	if s.notifications == nil {
		return
	}
	rows, err := s.db.Query(`
		SELECT DISTINCT reviewer.user_id
		FROM (
			SELECT id AS user_id FROM users WHERE role IN ('admin', 'super_admin')
			UNION
			SELECT ur.user_id FROM user_roles ur JOIN roles r ON r.id = ur.role_id
			WHERE r.name IN ('admin', 'super_admin')
		) AS reviewer`)
	if err != nil {
		return
	}
	defer rows.Close()

	data := map[string]string{
		"status":         "submitted",
		"entity_type":    "organizer_application",
		"entity_id":      applicationID.String(),
		"application_id": applicationID.String(),
		"path":           "/admin/organizer-applications/" + applicationID.String(),
	}
	for rows.Next() {
		var reviewerID uuid.UUID
		if err := rows.Scan(&reviewerID); err == nil {
			_, _ = s.notifications.CreateLocalized(reviewerID, "organizer_application", data)
		}
	}
}

func (s *Service) publicLogoURL(applicationID uuid.UUID) string {
	base := strings.TrimSuffix(s.media.publicBaseURL, "/")
	if base == "" {
		return "/api/v1/organizer/application/public/" + applicationID.String() + "/logo"
	}
	return base + "/api/v1/organizer/application/public/" + applicationID.String() + "/logo"
}

func validateDraft(input DraftInput) error {
	fail := func(msg string) error {
		fmt.Println("VALIDATION FAILED:", msg)
		return errors.New(msg)
	}
	if input.OrganizerType != "" {
		if _, ok := organizerTypes[input.OrganizerType]; !ok {
			return fail("choose a valid organizer type")
		}
	}
	if input.CountryCode != "" && !countryCodePattern.MatchString(input.CountryCode) {
		return fail("choose a valid ISO country code")
	}
	if input.Phone != "" && !phonePattern.MatchString(input.Phone) {
		return fail("enter a valid international phone number")
	}
	if len(input.Description) > 1000 {
		return fail("organization description must be 1000 characters or fewer")
	}
	if len(input.EventPlan) > 1500 {
		return fail("event plan must be 1500 characters or fewer")
	}
	for _, link := range input.Links {
		if !validPlatform(link.Platform) || !validURL(link.URL) {
			return fail(fmt.Sprintf("add valid official links (platform: %s, url: %s)", link.Platform, link.URL))
		}
	}
	for _, e := range input.Evidence {
		if !validEvidenceType(e.EvidenceType) || (e.URL != "" && !validURL(e.URL)) {
			return fail(fmt.Sprintf("add valid verification evidence (type: %s, url: %s)", e.EvidenceType, e.URL))
		}
	}
	for _, category := range input.EventCategories {
		if _, ok := categorySlugs[category]; !ok {
			return fail(fmt.Sprintf("choose valid planned event categories (category: %s)", category))
		}
	}
	for _, audience := range input.TypicalAudience {
		if _, ok := audienceValues[audience]; !ok {
			return fail(fmt.Sprintf("choose valid typical audiences (audience: %s)", audience))
		}
	}
	return nil
}

func validateSubmission(app *Application, identity identity) error {
	if _, ok := organizerTypes[app.OrganizerType]; !ok {
		return errors.New("choose your organizer type")
	}
	if len([]rune(app.PublicName)) < 2 || len([]rune(app.PublicName)) > 160 {
		return errors.New("enter an organizer name between 2 and 160 characters")
	}
	if len([]rune(app.RepresentativeName)) < 2 || len([]rune(app.RepresentativeName)) > 160 {
		return errors.New("enter the responsible representative's full name")
	}
	if !identity.Verified {
		return errors.New("verify your account email before submitting an organizer application")
	}
	if app.ContactEmail == "" {
		return errors.New("add a verified contact email")
	}
	if !strings.EqualFold(app.ContactEmail, identity.Email) || !app.ContactEmailVerified {
		return errors.New("use your verified account email as organizer contact email")
	}
	if !countryCodePattern.MatchString(app.CountryCode) {
		return errors.New("choose a country")
	}
	if len([]rune(app.City)) < 2 {
		return errors.New("enter your city")
	}
	if len([]rune(app.Description)) < 50 {
		return errors.New("tell us about your organization in at least 50 characters")
	}
	if len([]rune(app.EventPlan)) < 50 {
		return errors.New("describe your event plan in at least 50 characters")
	}
	if len(app.EventCategories) == 0 {
		return errors.New("choose at least one planned event category")
	}
	if app.PublicLogoKey == "" {
		return errors.New("upload an organizer logo or public profile image")
	}
	if app.OrganizerType == "individual" && app.RepresentativePhotoKey == "" {
		return errors.New("upload your public profile photo before submitting")
	}
	if app.GuidelinesVersion != GuidelinesVersion || app.GuidelinesAcceptedAt == nil {
		return errors.New("accept the Khair Organizer Standards before submitting")
	}
	return nil
}

func validateImage(filename, mime string, size int64) error {
	if size <= 0 || size > 5*1024*1024 {
		return errors.New("images must be between 1 byte and 5 MB")
	}
	if mime != "image/jpeg" && mime != "image/png" && mime != "image/webp" {
		return errors.New("use a JPG, PNG, or WebP image")
	}
	if safeFilename(filename) == "" {
		return errors.New("invalid image filename")
	}
	return nil
}
func validateDocument(fileType, filename, mime string, size int64) error {
	if size <= 0 || size > 10*1024*1024 {
		return errors.New("documents must be between 1 byte and 10 MB")
	}
	if mime != "application/pdf" && mime != "image/jpeg" && mime != "image/png" {
		return errors.New("use a PDF, JPG, or PNG document")
	}
	if !validDocumentType(fileType) {
		return errors.New("choose a valid verification document type")
	}
	if safeFilename(filename) == "" {
		return errors.New("invalid document filename")
	}
	return nil
}
func validPlatform(value string) bool {
	_, ok := map[string]struct{}{"website": {}, "instagram": {}, "facebook": {}, "linkedin": {}, "other": {}}[value]
	return ok
}
func validEvidenceType(value string) bool {
	_, ok := map[string]struct{}{"official_website": {}, "verified_social": {}, "registration": {}, "charity_registration": {}, "community_document": {}, "school_company_document": {}, "other": {}}[value]
	return ok
}
func validDocumentType(value string) bool {
	_, ok := map[string]struct{}{"registration": {}, "charity_registration": {}, "community_document": {}, "school_company_document": {}, "other": {}}[value]
	return ok
}
func validURL(value string) bool {
	parsed, err := url.ParseRequestURI(value)
	return err == nil && parsed.Scheme == "https" && parsed.Host != ""
}
func nullable(value string) any {
	if strings.TrimSpace(value) == "" {
		return nil
	}
	return strings.TrimSpace(value)
}
func mustJSON(value any) []byte           { data, _ := json.Marshal(value); return data }
func appSnapshot(input DraftInput) []byte { return mustJSON(input) }
func firstWebsite(links []Link) any {
	for _, link := range links {
		if link.Platform == "website" {
			return nullable(link.URL)
		}
	}
	return nil
}
func uniqueSorted(values []string) []string {
	seen := map[string]struct{}{}
	out := []string{}
	for _, v := range values {
		if _, ok := seen[v]; !ok {
			seen[v] = struct{}{}
			out = append(out, v)
		}
	}
	sort.Strings(out)
	return out
}
func safeFilename(name string) string {
	name = strings.TrimSpace(strings.ReplaceAll(name, "\\", "/"))
	name = strings.TrimPrefix(name, "/")
	if name == "" || strings.Contains(name, "../") {
		return ""
	}
	name = strings.ReplaceAll(name, "/", "_")
	return fmt.Sprintf("%s-%s", uuid.NewString(), name)
}
func safeDisplayFilename(name string) string {
	name = strings.TrimSpace(strings.ReplaceAll(name, "\\", "/"))
	parts := strings.Split(name, "/")
	if len(parts) > 0 {
		name = parts[len(parts)-1]
	}
	if name == "" {
		return "upload"
	}
	return name
}
func (input *DraftInput) normalize() {
	input.OrganizerType = strings.TrimSpace(strings.ToLower(input.OrganizerType))
	input.PublicName = strings.TrimSpace(input.PublicName)
	input.RepresentativeName = strings.TrimSpace(input.RepresentativeName)
	input.ContactEmail = strings.ToLower(strings.TrimSpace(input.ContactEmail))
	input.Phone = strings.TrimSpace(input.Phone)
	input.CountryCode = strings.ToUpper(strings.TrimSpace(input.CountryCode))
	input.City = strings.TrimSpace(input.City)
	input.Description = strings.TrimSpace(input.Description)
	input.EventPlan = strings.TrimSpace(input.EventPlan)
	input.GuidelinesVersion = strings.TrimSpace(input.GuidelinesVersion)
	for i := range input.Links {
		input.Links[i].Platform = strings.TrimSpace(strings.ToLower(input.Links[i].Platform))
		input.Links[i].URL = strings.TrimSpace(input.Links[i].URL)
	}
	for i := range input.Evidence {
		input.Evidence[i].EvidenceType = strings.TrimSpace(strings.ToLower(input.Evidence[i].EvidenceType))
		input.Evidence[i].URL = strings.TrimSpace(input.Evidence[i].URL)
		input.Evidence[i].Note = strings.TrimSpace(input.Evidence[i].Note)
	}
	for i := range input.EventCategories {
		input.EventCategories[i] = strings.TrimSpace(strings.ToLower(input.EventCategories[i]))
	}
	for i := range input.TypicalAudience {
		input.TypicalAudience[i] = strings.TrimSpace(strings.ToLower(input.TypicalAudience[i]))
	}
}
func localizedDecision(decision, name, message, language string) (string, string) {
	if language == "tr" {
		switch decision {
		case StatusApproved:
			return "Organizatör başvurunuz onaylandı", "Artık Khair'de etkinlik oluşturabilir ve yönetebilirsiniz."
		case StatusNeedsRevision:
			return "Organizatör başvurunuzda değişiklik gerekiyor", message
		default:
			return "Organizatör başvurunuz onaylanmadı", message
		}
	}
	if language == "ar" {
		switch decision {
		case StatusApproved:
			return "تمت الموافقة على طلب المنظِّم", "يمكنك الآن إنشاء وإدارة الفعاليات على خير."
		case StatusNeedsRevision:
			return "يحتاج طلب المنظِّم إلى تعديلات", message
		default:
			return "لم تتم الموافقة على طلب المنظِّم", message
		}
	}
	switch decision {
	case StatusApproved:
		return "Your organizer application has been approved", fmt.Sprintf("You can now create and manage events on Khair.")
	case StatusNeedsRevision:
		return "Your organizer application needs changes", message
	default:
		return "Your organizer application was not approved", message
	}
}
