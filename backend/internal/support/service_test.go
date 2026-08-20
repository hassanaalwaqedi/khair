package support_test

import (
	"context"
	"database/sql"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/google/uuid"
	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/internal/support"
	"github.com/stretchr/testify/assert"
)

func ticketRows(ticketID, userID uuid.UUID, status string) *sqlmock.Rows {
	return sqlmock.NewRows([]string{
		"id", "user_id", "assigned_to", "category", "subject", "status",
		"priority", "ai_summary", "created_at", "updated_at",
		"first_human_response_at", "resolved_at", "closed_at", "language",
		"context_type", "context_id",
	}).AddRow(ticketID, userID, nil, "general", "Khair support conversation",
		status, "normal", nil, time.Now(), time.Now(), nil, nil, nil, "en", nil, nil)
}

func TestService_StartConversationCreatesPersistentWelcome(t *testing.T) {
	db, mock, err := sqlmock.New()
	assert.NoError(t, err)
	defer db.Close()

	repo := support.NewRepository(db)
	svc := support.NewService(repo, nil, nil, nil, db)
	userID := uuid.New()
	ticketID := uuid.New()

	mock.ExpectQuery(`SELECT id, user_id, assigned_to`).
		WithArgs(userID).
		WillReturnError(sql.ErrNoRows)
	mock.ExpectQuery(`SELECT COALESCE\(NULLIF\(p.preferred_language`).
		WithArgs(userID).
		WillReturnRows(sqlmock.NewRows([]string{"language", "role", "organizer_status"}).AddRow("en", "user", ""))
	mock.ExpectQuery(`INSERT INTO support_tickets`).
		WithArgs(userID, "general", "Khair support conversation", "ai_active", "normal", "en", nil, nil).
		WillReturnRows(sqlmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(ticketID, time.Now(), time.Now()))
	mock.ExpectQuery(`INSERT INTO support_messages`).
		WithArgs(ticketID, "ai", nil, sqlmock.AnyArg(), "text", sqlmock.AnyArg()).
		WillReturnRows(sqlmock.NewRows([]string{"id", "created_at"}).AddRow(uuid.New(), time.Now()))

	ticket, welcome, created, err := svc.StartConversation(context.Background(), userID, models.CreateSupportConversationRequest{Language: "en"})
	assert.NoError(t, err)
	assert.True(t, created)
	assert.Equal(t, ticketID, ticket.ID)
	assert.Equal(t, "ai_active", ticket.Status)
	assert.Equal(t, "ai", welcome.SenderType)
	assert.Contains(t, welcome.Body, "Khair AI")
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestService_EscalateTicketMovesConversationToWaitingForAgent(t *testing.T) {
	db, mock, err := sqlmock.New()
	assert.NoError(t, err)
	defer db.Close()

	repo := support.NewRepository(db)
	svc := support.NewService(repo, nil, nil, nil, db)
	ticketID := uuid.New()
	userID := uuid.New()

	mock.ExpectQuery(`SELECT id, user_id, assigned_to`).
		WithArgs(ticketID).
		WillReturnRows(ticketRows(ticketID, userID, "ai_active"))
	mock.ExpectQuery(`UPDATE support_tickets`).
		WithArgs(nil, "waiting_for_agent", "normal", nil, nil, nil, nil, ticketID).
		WillReturnRows(sqlmock.NewRows([]string{"updated_at"}).AddRow(time.Now()))
	mock.ExpectQuery(`INSERT INTO support_messages`).
		WithArgs(ticketID, "system", nil, sqlmock.AnyArg(), "text", sqlmock.AnyArg()).
		WillReturnRows(sqlmock.NewRows([]string{"id", "created_at"}).AddRow(uuid.New(), time.Now()))

	assert.NoError(t, svc.EscalateTicket(ticketID))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestService_EscalateTicketIsIdempotentAfterHandoff(t *testing.T) {
	db, mock, err := sqlmock.New()
	assert.NoError(t, err)
	defer db.Close()

	repo := support.NewRepository(db)
	svc := support.NewService(repo, nil, nil, nil, db)
	ticketID := uuid.New()
	userID := uuid.New()
	mock.ExpectQuery(`SELECT id, user_id, assigned_to`).
		WithArgs(ticketID).
		WillReturnRows(ticketRows(ticketID, userID, "waiting_for_agent"))

	assert.NoError(t, svc.EscalateTicket(ticketID))
	assert.NoError(t, mock.ExpectationsWereMet())
}
