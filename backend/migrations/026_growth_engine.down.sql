-- Revert Phase 4 Growth Engine changes

DROP TABLE IF EXISTS event_waitlist;
DROP TABLE IF EXISTS event_reminders;
DROP TABLE IF EXISTS event_reviews;
DROP TABLE IF EXISTS organizer_reputation;
DROP TABLE IF EXISTS referrals;

DROP TRIGGER IF EXISTS trg_event_slug ON events;
DROP FUNCTION IF EXISTS generate_event_slug();

ALTER TABLE events DROP COLUMN IF EXISTS slug;
ALTER TABLE events DROP COLUMN IF EXISTS view_count;

ALTER TABLE users DROP COLUMN IF EXISTS referred_by;
ALTER TABLE users DROP COLUMN IF EXISTS reward_points;
ALTER TABLE users DROP COLUMN IF EXISTS referral_code;
