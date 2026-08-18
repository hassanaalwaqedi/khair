package support_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/internal/support"
	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
)

// A small mock repo to test service logic if we had interfaces, but since we rely on concrete sql.DB,
// we will use go-sqlmock to test the service interactions.

func TestService_StartSession(t *testing.T) {
	db, mock, err := sqlmock.New()
	assert.NoError(t, err)
	defer db.Close()

	repo := support.NewRepository(db)
	svc := support.NewService(repo, nil, nil, nil, db)

	userID := uuid.New()
	req := models.CreateSupportTicketRequest{
		Category: "General",
		Subject:  "Help me",
	}

	mock.ExpectQuery(`INSERT INTO support_tickets`).
		WithArgs(userID, "General", "Help me", "ai_active", "normal").
		WillReturnRows(sqlmock.NewRows([]string{"id", "created_at", "updated_at"}).
			AddRow(uuid.New(), time.Now(), time.Now()))

	mock.ExpectQuery(`SELECT id, slug, title, content, category, language, is_published, created_at, updated_at`).
		WillReturnRows(sqlmock.NewRows([]string{"id", "slug", "title", "content", "category", "language", "is_published", "created_at", "updated_at"}))

	mock.ExpectQuery(`INSERT INTO support_messages`).
		WithArgs(sqlmock.AnyArg(), "user", userID, "Help me", "text").
		WillReturnRows(sqlmock.NewRows([]string{"id", "created_at"}).AddRow(uuid.New(), time.Now()))

	mock.ExpectQuery(`INSERT INTO support_messages`).
		WithArgs(sqlmock.AnyArg(), "ai", nil, sqlmock.AnyArg(), "text").
		WillReturnRows(sqlmock.NewRows([]string{"id", "created_at"}).AddRow(uuid.New(), time.Now()))

	mock.ExpectQuery(`UPDATE support_tickets`).
		WillReturnRows(sqlmock.NewRows([]string{"updated_at"}).AddRow(time.Now()))

	ticket, aiMsg, err := svc.StartSession(context.Background(), userID, req)
	assert.NoError(t, err)
	assert.NotNil(t, ticket)
	assert.NotNil(t, aiMsg)
	assert.Equal(t, "ai_active", ticket.Status)
	assert.Equal(t, "ai", aiMsg.SenderType)

	err = mock.ExpectationsWereMet()
	assert.NoError(t, err)
}

func TestService_EscalateTicket(t *testing.T) {
	db, mock, err := sqlmock.New()
	assert.NoError(t, err)
	defer db.Close()

	repo := support.NewRepository(db)
	svc := support.NewService(repo, nil, nil, nil, db)

	ticketID := uuid.New()

	mock.ExpectQuery(`SELECT id, user_id, assigned_to, category, subject, status, priority, ai_summary, created_at, updated_at, first_human_response_at, resolved_at, closed_at`).
		WithArgs(ticketID).
		WillReturnRows(sqlmock.NewRows([]string{"id", "user_id", "assigned_to", "category", "subject", "status", "priority", "ai_summary", "created_at", "updated_at", "first_human_response_at", "resolved_at", "closed_at"}).
			AddRow(ticketID, uuid.New(), nil, "General", "Subject", "ai_active", "normal", nil, time.Now(), time.Now(), nil, nil, nil))

	mock.ExpectQuery(`UPDATE support_tickets`).
		WithArgs(nil, "waiting_for_support", "normal", nil, nil, nil, nil, ticketID).
		WillReturnRows(sqlmock.NewRows([]string{"updated_at"}).AddRow(time.Now()))

	mock.ExpectQuery(`INSERT INTO support_messages`).
		WithArgs(ticketID, "system", nil, "Your request has been sent to Khair Support.", "text").
		WillReturnRows(sqlmock.NewRows([]string{"id", "created_at"}).AddRow(uuid.New(), time.Now()))

	err = svc.EscalateTicket(ticketID)
	assert.NoError(t, err)

	err = mock.ExpectationsWereMet()
	assert.NoError(t, err)
}
