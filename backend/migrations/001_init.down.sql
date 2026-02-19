-- Drop triggers
DROP TRIGGER IF EXISTS trigger_events_updated_at ON events;
DROP TRIGGER IF EXISTS trigger_organizers_updated_at ON organizers;
DROP TRIGGER IF EXISTS trigger_users_updated_at ON users;
DROP TRIGGER IF EXISTS trigger_update_event_location ON events;

-- Drop functions
DROP FUNCTION IF EXISTS update_updated_at_column;
DROP FUNCTION IF EXISTS update_event_location;

-- Drop indexes
DROP INDEX IF EXISTS idx_events_location;
DROP INDEX IF EXISTS idx_events_start_date;
DROP INDEX IF EXISTS idx_events_language;
DROP INDEX IF EXISTS idx_events_event_type;
DROP INDEX IF EXISTS idx_events_country_city;
DROP INDEX IF EXISTS idx_events_city;
DROP INDEX IF EXISTS idx_events_country;
DROP INDEX IF EXISTS idx_events_status;
DROP INDEX IF EXISTS idx_events_organizer_id;
DROP INDEX IF EXISTS idx_organizers_status;
DROP INDEX IF EXISTS idx_organizers_user_id;
DROP INDEX IF EXISTS idx_users_role;
DROP INDEX IF EXISTS idx_users_email;

-- Drop tables
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS organizers;
DROP TABLE IF EXISTS users;

-- Drop PostGIS extension
DROP EXTENSION IF EXISTS postgis;
