-- Migration 016 DOWN: Platform Infrastructure Upgrade rollback

DROP TRIGGER IF EXISTS trigger_verification_requests_updated_at ON verification_requests;

DROP TABLE IF EXISTS verification_requests;
DROP TABLE IF EXISTS user_goals;

ALTER TABLE profiles DROP COLUMN IF EXISTS country_id;
ALTER TABLE profiles DROP COLUMN IF EXISTS timezone;

ALTER TABLE users DROP COLUMN IF EXISTS verification_status;

ALTER TABLE organizers DROP COLUMN IF EXISTS established_year;
ALTER TABLE organizers DROP COLUMN IF EXISTS attendance_estimate;
ALTER TABLE organizers DROP COLUMN IF EXISTS official_email;

DROP INDEX IF EXISTS idx_countries_iso;
DROP INDEX IF EXISTS idx_countries_region;
DROP INDEX IF EXISTS idx_countries_active;
DROP INDEX IF EXISTS idx_countries_name;
DROP INDEX IF EXISTS idx_user_goals_user;
DROP INDEX IF EXISTS idx_verification_user;
DROP INDEX IF EXISTS idx_verification_status;

DROP TABLE IF EXISTS countries;
