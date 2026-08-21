package support_test

import (
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/google/uuid"
	"github.com/khair/backend/internal/support"
	"github.com/stretchr/testify/require"
)

func TestRepositoryGetTicketMessagesReadsAIMessageWithoutOptionalRelations(t *testing.T) {
	db, mock, err := sqlmock.New()
	require.NoError(t, err)
	defer db.Close()

	ticketID := uuid.New()
	messageID := uuid.New()
	createdAt := time.Now().UTC().Truncate(time.Microsecond)
	mock.ExpectQuery(`SELECT m.id, m.ticket_id`).
		WithArgs(ticketID).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "ticket_id", "sender_type", "sender_user_id", "body",
			"message_type", "created_at", "read_at", "metadata", "sender_name",
			"attachment_id", "file_url", "mime_type", "size_bytes", "attachment_created_at",
		}).AddRow(
			messageID, ticketID, "ai", nil, "Welcome to Khair Support", "text",
			createdAt, nil, []byte(`{"quick_actions":[]}`), nil,
			nil, nil, nil, nil, nil,
		))

	messages, err := support.NewRepository(db).GetTicketMessages(ticketID, false)
	require.NoError(t, err)
	require.Len(t, messages, 1)
	require.Equal(t, "ai", messages[0].SenderType)
	require.Nil(t, messages[0].SenderUserID)
	require.Nil(t, messages[0].SenderName)
	require.Nil(t, messages[0].Attachment)
	require.NoError(t, mock.ExpectationsWereMet())
}

func TestRepositoryGetAdminTicketsSupportsUsersWithoutProfileNames(t *testing.T) {
	db, mock, err := sqlmock.New()
	require.NoError(t, err)
	defer db.Close()

	ticketID := uuid.New()
	userID := uuid.New()
	createdAt := time.Now().UTC().Truncate(time.Microsecond)
	mock.ExpectQuery(`COALESCE\(NULLIF\(u\.display_name`).
		WithArgs("waiting_for_agent").
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "user_id", "assigned_to", "category", "subject", "status",
			"priority", "ai_summary", "created_at", "updated_at",
			"first_human_response_at", "resolved_at", "closed_at", "language",
			"context_type", "context_id", "user_name", "user_email", "assigned_to_name",
		}).AddRow(
			ticketID, userID, nil, "general", "Need help", "waiting_for_agent",
			"normal", nil, createdAt, createdAt, nil, nil, nil, "en", nil, nil,
			"Khair user", "", nil,
		))

	tickets, err := support.NewRepository(db).GetAdminTickets("waiting_for_agent")
	require.NoError(t, err)
	require.Len(t, tickets, 1)
	require.Equal(t, "Khair user", tickets[0].UserName)
	require.Empty(t, tickets[0].UserEmail)
	require.Nil(t, tickets[0].AssignedToName)
	require.NoError(t, mock.ExpectationsWereMet())
}
