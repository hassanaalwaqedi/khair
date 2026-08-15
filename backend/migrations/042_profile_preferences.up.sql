CREATE TABLE IF NOT EXISTS user_profile_preferences (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    push_notifications BOOLEAN NOT NULL DEFAULT TRUE,
    email_notifications BOOLEAN NOT NULL DEFAULT TRUE,
    profile_visibility VARCHAR(32) NOT NULL DEFAULT 'private'
        CHECK (profile_visibility IN ('private', 'event_attendees')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

