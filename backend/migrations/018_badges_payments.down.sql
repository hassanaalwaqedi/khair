-- Rollback migration 018
DROP TABLE IF EXISTS payouts;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS tickets;
DROP TABLE IF EXISTS payment_settings;
DROP TABLE IF EXISTS event_validation_logs;
ALTER TABLE organizers DROP COLUMN IF EXISTS avg_rating;
ALTER TABLE organizers DROP COLUMN IF EXISTS total_attendees;
ALTER TABLE organizers DROP COLUMN IF EXISTS total_events_hosted;
ALTER TABLE organizers DROP COLUMN IF EXISTS verified_at;
ALTER TABLE organizers DROP COLUMN IF EXISTS verification_badge;
DROP TABLE IF EXISTS organizer_badges;
