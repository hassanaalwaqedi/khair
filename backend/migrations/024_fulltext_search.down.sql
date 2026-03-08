-- Revert full-text search changes
DROP TRIGGER IF EXISTS trg_events_search_vector ON events;
DROP FUNCTION IF EXISTS events_search_vector_update();
DROP INDEX IF EXISTS idx_events_search;
ALTER TABLE events DROP COLUMN IF EXISTS search_vector;
