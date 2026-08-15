-- 044: Production fields used by the organizer event editor.
-- Additive and backwards-compatible with the legacy event model.

ALTER TABLE events
  ADD COLUMN IF NOT EXISTS timezone VARCHAR(64) NOT NULL DEFAULT 'UTC',
  ADD COLUMN IF NOT EXISTS registration_deadline TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS registration_mode VARCHAR(24) NOT NULL DEFAULT 'instant',
  ADD COLUMN IF NOT EXISTS organizer_guidelines TEXT,
  ADD COLUMN IF NOT EXISTS venue_name VARCHAR(255),
  ADD COLUMN IF NOT EXISTS online_platform VARCHAR(32);

ALTER TABLE events
  DROP CONSTRAINT IF EXISTS events_registration_mode_check;
ALTER TABLE events
  ADD CONSTRAINT events_registration_mode_check
  CHECK (registration_mode IN ('instant', 'approval_required'));

CREATE TABLE IF NOT EXISTS event_tags (
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  tag VARCHAR(32) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (event_id, tag)
);

CREATE INDEX IF NOT EXISTS idx_event_tags_tag ON event_tags(tag);
