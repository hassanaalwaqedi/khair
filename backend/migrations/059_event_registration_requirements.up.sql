-- Registration channel and organizer requirements are independent from event
-- publication. Existing events deliberately retain the no-registration default.
ALTER TABLE events
    ADD COLUMN IF NOT EXISTS registration_required BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS registration_type VARCHAR(16) NOT NULL DEFAULT 'none',
    ADD COLUMN IF NOT EXISTS external_platform_name VARCHAR(120),
    ADD COLUMN IF NOT EXISTS external_registration_url TEXT,
    ADD COLUMN IF NOT EXISTS external_registration_instructions TEXT,
    ADD COLUMN IF NOT EXISTS registration_requirements TEXT,
    ADD COLUMN IF NOT EXISTS application_approval_required BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE events DROP CONSTRAINT IF EXISTS events_registration_type_check;
ALTER TABLE events ADD CONSTRAINT events_registration_type_check
    CHECK (registration_type IN ('none', 'khair', 'external', 'both'));
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_external_registration_url_https_check;
ALTER TABLE events ADD CONSTRAINT events_external_registration_url_https_check
    CHECK (external_registration_url IS NULL OR external_registration_url ~* '^https://');

CREATE TABLE IF NOT EXISTS event_external_registration_clicks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    domain VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_external_registration_clicks_event
    ON event_external_registration_clicks(event_id, created_at DESC);
