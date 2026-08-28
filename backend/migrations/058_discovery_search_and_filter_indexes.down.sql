DROP INDEX IF EXISTS idx_event_tags_tag_trgm;
DROP INDEX IF EXISTS idx_events_category_trgm;
DROP INDEX IF EXISTS idx_events_is_online;
DROP INDEX IF EXISTS idx_events_pricing_type;
DROP INDEX IF EXISTS idx_events_end_date;
DROP INDEX IF EXISTS idx_events_public_schedule;

DROP TRIGGER IF EXISTS trg_events_search_vector ON events;
CREATE TRIGGER trg_events_search_vector
    BEFORE INSERT OR UPDATE OF title, description, event_type, city, country
    ON events
    FOR EACH ROW
    EXECUTE FUNCTION events_search_vector_update();
