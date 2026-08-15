DROP INDEX IF EXISTS idx_events_type_trgm;
DROP INDEX IF EXISTS idx_events_city_trgm;
DROP INDEX IF EXISTS idx_events_title_trgm;

-- Do not drop pg_trgm: it may be shared by other safe search indexes.
