DROP TABLE IF EXISTS event_announcement_deliveries;
ALTER TABLE event_announcements DROP CONSTRAINT IF EXISTS event_announcements_type_check;
ALTER TABLE event_announcements DROP COLUMN IF EXISTS announcement_type;
ALTER TABLE event_announcements DROP COLUMN IF EXISTS title;
DROP TABLE IF EXISTS event_views;
