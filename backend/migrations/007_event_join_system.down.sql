-- Rollback migration 007: Event Join System

-- 1. Drop event_registrations
DROP TRIGGER IF EXISTS set_event_registrations_updated_at ON event_registrations;
DROP INDEX IF EXISTS idx_event_reg_user_id;
DROP INDEX IF EXISTS idx_event_reg_event_id;
DROP INDEX IF EXISTS idx_event_reg_status;
DROP INDEX IF EXISTS idx_event_reg_reserved_until;
DROP INDEX IF EXISTS idx_event_reg_user_event;
DROP INDEX IF EXISTS idx_events_capacity;
DROP TABLE IF EXISTS event_registrations;

-- 2. Remove capacity and reserved_count from events
ALTER TABLE events DROP COLUMN IF EXISTS capacity;
ALTER TABLE events DROP COLUMN IF EXISTS reserved_count;

-- 3. Remove gender and age from users
ALTER TABLE users DROP COLUMN IF EXISTS gender;
ALTER TABLE users DROP COLUMN IF EXISTS age;

-- 4. Restore original role constraint (from migration 006)
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (
    role IN ('organizer', 'admin', 'organization', 'sheikh', 'new_muslim', 'student', 'community_organizer')
);
