DROP INDEX IF EXISTS idx_event_tags_tag;
DROP TABLE IF EXISTS event_tags;
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_registration_mode_check;
ALTER TABLE events
  DROP COLUMN IF EXISTS timezone,
  DROP COLUMN IF EXISTS registration_deadline,
  DROP COLUMN IF EXISTS registration_mode,
  DROP COLUMN IF EXISTS organizer_guidelines,
  DROP COLUMN IF EXISTS venue_name,
  DROP COLUMN IF EXISTS online_platform;
