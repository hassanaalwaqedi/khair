-- Rollback Migration 009: Smart Islamic Event Map Geo Architecture

DROP TABLE IF EXISTS geo_interaction_metrics;
DROP TABLE IF EXISTS islamic_places;
DROP TABLE IF EXISTS geo_request_logs;

DROP TRIGGER IF EXISTS trigger_sync_event_geo_fields ON events;
DROP FUNCTION IF EXISTS sync_event_geo_fields;

DROP INDEX IF EXISTS idx_events_location;
DROP INDEX IF EXISTS idx_events_geo_status_starts;
DROP INDEX IF EXISTS idx_events_geo_category_starts;
DROP INDEX IF EXISTS idx_events_geo_gender;
DROP INDEX IF EXISTS idx_events_geo_price_free;
DROP INDEX IF EXISTS idx_events_geo_capacity;

ALTER TABLE events
    DROP COLUMN IF EXISTS location_geometry,
    DROP COLUMN IF EXISTS location_point,
    DROP COLUMN IF EXISTS price_cents,
    DROP COLUMN IF EXISTS max_age,
    DROP COLUMN IF EXISTS min_age,
    DROP COLUMN IF EXISTS ends_at,
    DROP COLUMN IF EXISTS starts_at,
    DROP COLUMN IF EXISTS category,
    DROP COLUMN IF EXISTS organization_id;
