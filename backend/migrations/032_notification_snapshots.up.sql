CREATE TABLE IF NOT EXISTS notification_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    event_name VARCHAR(255) NOT NULL,
    event_time TIMESTAMPTZ NOT NULL,
    event_location TEXT,
    event_online_link TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notification_snapshots_user_id ON notification_snapshots(user_id);
CREATE INDEX idx_notification_snapshots_event_id ON notification_snapshots(event_id);
