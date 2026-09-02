-- Notification center metadata, per-topic preferences, and delivery auditing.
-- Existing notification rows remain valid; all new fields are nullable or have
-- safe defaults so this migration can be applied without downtime.
ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS related_event_id UUID REFERENCES events(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS related_conversation_id UUID,
    ADD COLUMN IF NOT EXISTS related_message_id UUID,
    ADD COLUMN IF NOT EXISTS action_url TEXT,
    ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

UPDATE notifications
SET read_at = COALESCE(read_at, created_at)
WHERE is_read = true;

CREATE INDEX IF NOT EXISTS idx_notifications_related_event
    ON notifications(related_event_id) WHERE related_event_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
    ON notifications(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS notification_preferences (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    messages BOOLEAN NOT NULL DEFAULT TRUE,
    event_registrations BOOLEAN NOT NULL DEFAULT TRUE,
    event_updates BOOLEAN NOT NULL DEFAULT TRUE,
    event_reminders BOOLEAN NOT NULL DEFAULT TRUE,
    organizer_announcements BOOLEAN NOT NULL DEFAULT TRUE,
    system_notifications BOOLEAN NOT NULL DEFAULT TRUE,
    browser_push BOOLEAN NOT NULL DEFAULT TRUE,
    email_notifications BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notification_delivery_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID REFERENCES notifications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    channel VARCHAR(20) NOT NULL CHECK (channel IN ('websocket', 'fcm', 'email', 'in_app')),
    status VARCHAR(20) NOT NULL CHECK (status IN ('queued', 'sent', 'failed', 'skipped')),
    provider_message_id TEXT,
    error_message TEXT,
    attempt_count INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    delivered_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_notification_delivery_logs_notification
    ON notification_delivery_logs(notification_id, created_at DESC);
