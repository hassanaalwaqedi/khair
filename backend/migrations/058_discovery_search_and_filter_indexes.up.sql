-- Discovery query indexes and richer public-event search.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_events_public_schedule
    ON events (status, is_published, start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_events_end_date
    ON events (end_date);

CREATE INDEX IF NOT EXISTS idx_events_pricing_type
    ON events (pricing_type);

CREATE INDEX IF NOT EXISTS idx_events_is_online
    ON events (is_online);

CREATE INDEX IF NOT EXISTS idx_events_category_trgm
    ON events USING GIN (LOWER(category) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_event_tags_tag_trgm
    ON event_tags USING GIN (LOWER(tag) gin_trgm_ops);

-- Include category and tags in full-text relevance while keeping the existing
-- title/description weighting. Organizer names are queried through the join.
CREATE OR REPLACE FUNCTION events_search_vector_update() RETURNS trigger AS $$
BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('simple', COALESCE(NEW.title, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(NEW.description, '')), 'B') ||
        setweight(to_tsvector('simple', COALESCE(NEW.category, '')), 'C') ||
        setweight(to_tsvector('simple', COALESCE(NEW.event_type, '')), 'C') ||
        setweight(to_tsvector('simple', COALESCE(NEW.city, '')), 'D') ||
        setweight(to_tsvector('simple', COALESCE(NEW.country, '')), 'D') ||
        setweight(to_tsvector('simple', COALESCE(NEW.address, '')), 'D') ||
        setweight(to_tsvector('simple', COALESCE(NEW.venue_name, '')), 'D');
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_events_search_vector ON events;
CREATE TRIGGER trg_events_search_vector
    BEFORE INSERT OR UPDATE OF title, description, category, event_type, city,
    country, address, venue_name
    ON events
    FOR EACH ROW
    EXECUTE FUNCTION events_search_vector_update();

UPDATE events e
SET search_vector =
    setweight(to_tsvector('simple', COALESCE(e.title, '')), 'A') ||
    setweight(to_tsvector('simple', COALESCE(e.description, '')), 'B') ||
    setweight(to_tsvector('simple', COALESCE(e.category, '')), 'C') ||
    setweight(to_tsvector('simple', COALESCE(e.event_type, '')), 'C') ||
    setweight(to_tsvector('simple', COALESCE(e.city, '')), 'D') ||
    setweight(to_tsvector('simple', COALESCE(e.country, '')), 'D') ||
    setweight(to_tsvector('simple', COALESCE(e.address, '')), 'D') ||
    setweight(to_tsvector('simple', COALESCE(e.venue_name, '')), 'D');
