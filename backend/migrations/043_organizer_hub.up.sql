-- 043: Organizer Hub metrics and announcement delivery audit.
-- Additive only: existing events, registrations and announcements remain valid.

CREATE TABLE IF NOT EXISTS event_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  session_id VARCHAR(128),
  viewer_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  source VARCHAR(32) NOT NULL DEFAULT 'event_detail',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT event_views_identity_check CHECK (
    session_id IS NOT NULL OR viewer_user_id IS NOT NULL
  )
);

CREATE INDEX IF NOT EXISTS idx_event_views_event_created
  ON event_views(event_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_event_views_session_created
  ON event_views(session_id, created_at DESC) WHERE session_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_event_views_event_identity_created
  ON event_views(event_id, viewer_user_id, session_id, created_at DESC);

ALTER TABLE event_announcements
  ADD COLUMN IF NOT EXISTS title VARCHAR(160),
  ADD COLUMN IF NOT EXISTS announcement_type VARCHAR(32) NOT NULL DEFAULT 'general';

ALTER TABLE event_announcements
  DROP CONSTRAINT IF EXISTS event_announcements_type_check;
ALTER TABLE event_announcements
  ADD CONSTRAINT event_announcements_type_check
  CHECK (announcement_type IN ('general', 'schedule_change', 'reminder', 'important'));

CREATE TABLE IF NOT EXISTS event_announcement_deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id UUID NOT NULL REFERENCES event_announcements(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  in_app_status VARCHAR(20) NOT NULL DEFAULT 'queued',
  push_status VARCHAR(20) NOT NULL DEFAULT 'queued',
  error_message TEXT,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(announcement_id, user_id),
  CONSTRAINT announcement_delivery_status_check CHECK (
    in_app_status IN ('queued', 'delivered', 'failed') AND
    push_status IN ('queued', 'dispatched', 'failed')
  )
);
CREATE INDEX IF NOT EXISTS idx_announcement_deliveries_announcement
  ON event_announcement_deliveries(announcement_id, created_at DESC);
