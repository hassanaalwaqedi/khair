-- Event-scoped messaging. There is intentionally no user-to-user global
-- conversation table: every participant relationship is tied to an event.
CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  organizer_id UUID NOT NULL REFERENCES organizers(id) ON DELETE CASCADE,
  attendee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  organizer_opening_pending BOOLEAN NOT NULL DEFAULT FALSE, muted_by_attendee BOOLEAN NOT NULL DEFAULT FALSE,
  attendee_deleted_at TIMESTAMPTZ, organizer_deleted_at TIMESTAMPTZ, last_message_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(event_id, attendee_id)
);
CREATE TABLE conversation_participants (conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE, user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, last_read_at TIMESTAMPTZ, PRIMARY KEY(conversation_id,user_id));
CREATE TABLE messages (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE, sender_id UUID NOT NULL REFERENCES users(id), body TEXT NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000), risk_flags JSONB NOT NULL DEFAULT '[]', moderation_status VARCHAR(20) NOT NULL DEFAULT 'allowed', deleted_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW());
CREATE TABLE message_reports (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), message_id UUID REFERENCES messages(id) ON DELETE SET NULL, conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE, reporter_id UUID NOT NULL REFERENCES users(id), reason VARCHAR(40) NOT NULL, explanation TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), CHECK(reason IN ('spam','fraud_or_scam','asking_for_money','harassment','inappropriate_content','suspicious_external_link','other')));
CREATE TABLE blocked_users (blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, organizer_id UUID REFERENCES organizers(id) ON DELETE CASCADE, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), PRIMARY KEY(blocker_id,blocked_id));
CREATE TABLE organizer_message_permissions (organizer_id UUID NOT NULL REFERENCES organizers(id) ON DELETE CASCADE, attendee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE, suspended_at TIMESTAMPTZ, suspended_by UUID REFERENCES users(id), reason TEXT, PRIMARY KEY(organizer_id,attendee_id,event_id));
CREATE TABLE moderation_events (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), actor_id UUID REFERENCES users(id), subject_user_id UUID REFERENCES users(id), event_id UUID REFERENCES events(id), conversation_id UUID REFERENCES conversations(id), message_id UUID REFERENCES messages(id), action VARCHAR(64) NOT NULL, metadata JSONB NOT NULL DEFAULT '{}', created_at TIMESTAMPTZ NOT NULL DEFAULT NOW());
CREATE INDEX idx_conversations_attendee ON conversations(attendee_id,last_message_at DESC); CREATE INDEX idx_messages_conversation ON messages(conversation_id,created_at); CREATE INDEX idx_reports_created ON message_reports(created_at DESC);
