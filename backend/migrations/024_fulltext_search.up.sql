-- Add full-text search to events table
-- Uses tsvector + GIN index for fast ranked search

-- 1. Add search vector column
ALTER TABLE events ADD COLUMN IF NOT EXISTS search_vector tsvector;

-- 2. Create GIN index for fast full-text search
CREATE INDEX IF NOT EXISTS idx_events_search ON events USING GIN (search_vector);

-- 3. Populate existing rows
UPDATE events SET search_vector =
    setweight(to_tsvector('simple', COALESCE(title, '')), 'A') ||
    setweight(to_tsvector('simple', COALESCE(description, '')), 'B') ||
    setweight(to_tsvector('simple', COALESCE(event_type, '')), 'C') ||
    setweight(to_tsvector('simple', COALESCE(city, '')), 'D') ||
    setweight(to_tsvector('simple', COALESCE(country, '')), 'D');

-- 4. Auto-update trigger on INSERT or UPDATE
CREATE OR REPLACE FUNCTION events_search_vector_update() RETURNS trigger AS $$
BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('simple', COALESCE(NEW.title, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(NEW.description, '')), 'B') ||
        setweight(to_tsvector('simple', COALESCE(NEW.event_type, '')), 'C') ||
        setweight(to_tsvector('simple', COALESCE(NEW.city, '')), 'D') ||
        setweight(to_tsvector('simple', COALESCE(NEW.country, '')), 'D');
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_events_search_vector ON events;
CREATE TRIGGER trg_events_search_vector
    BEFORE INSERT OR UPDATE OF title, description, event_type, city, country
    ON events
    FOR EACH ROW
    EXECUTE FUNCTION events_search_vector_update();
