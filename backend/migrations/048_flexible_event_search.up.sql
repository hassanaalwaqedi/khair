-- Support typo-tolerant, partial event search without weakening public-event
-- filters. PostgreSQL provides pg_trgm, and the indexes keep title/city/topic
-- lookups responsive as the event catalog grows.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_events_title_trgm
    ON events USING GIN (LOWER(title) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_events_city_trgm
    ON events USING GIN (LOWER(city) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_events_type_trgm
    ON events USING GIN (LOWER(event_type) gin_trgm_ops);
