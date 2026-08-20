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
