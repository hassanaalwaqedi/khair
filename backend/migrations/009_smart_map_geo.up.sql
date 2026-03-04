-- Migration 009: Smart Islamic Event Map Geo Architecture
-- Adds normalized geo fields, spatial indexes, geo request logs, contextual places, and analytics metrics.

CREATE EXTENSION IF NOT EXISTS postgis;

-- 1) Event schema upgrades for geo discovery and recommendation filters
ALTER TABLE events
    ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizers(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS category VARCHAR(100),
    ADD COLUMN IF NOT EXISTS starts_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS ends_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS min_age INTEGER,
    ADD COLUMN IF NOT EXISTS max_age INTEGER,
    ADD COLUMN IF NOT EXISTS price_cents INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS location_point GEOGRAPHY(POINT, 4326),
    ADD COLUMN IF NOT EXISTS location_geometry GEOMETRY(POINT, 4326);

-- Backfill normalized fields from legacy columns
UPDATE events
SET
    organization_id = COALESCE(organization_id, organizer_id),
    category = COALESCE(category, event_type),
    starts_at = COALESCE(starts_at, start_date),
    ends_at = COALESCE(ends_at, end_date),
    min_age = COALESCE(min_age, age_min),
    max_age = COALESCE(max_age, age_max)
WHERE
    organization_id IS NULL
    OR category IS NULL
    OR starts_at IS NULL
    OR min_age IS NULL
    OR max_age IS NULL;

-- Backfill geo point if missing
UPDATE events
SET
    location_point = COALESCE(
        location_point,
        location,
        CASE
            WHEN latitude IS NOT NULL AND longitude IS NOT NULL
                THEN ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
            ELSE NULL
        END
    ),
    location_geometry = COALESCE(
        location_geometry,
        CASE
            WHEN location IS NOT NULL THEN location::geometry
            WHEN location_point IS NOT NULL THEN location_point::geometry
            WHEN latitude IS NOT NULL AND longitude IS NOT NULL
                THEN ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
            ELSE NULL
        END
    )
WHERE location_point IS NULL OR location_geometry IS NULL;

-- Keep legacy and normalized columns synchronized on write
CREATE OR REPLACE FUNCTION sync_event_geo_fields()
RETURNS TRIGGER AS $$
BEGIN
    NEW.organization_id := COALESCE(NEW.organization_id, NEW.organizer_id);
    NEW.category := COALESCE(NEW.category, NEW.event_type);
    NEW.event_type := COALESCE(NEW.event_type, NEW.category);

    NEW.starts_at := COALESCE(NEW.starts_at, NEW.start_date);
    NEW.start_date := COALESCE(NEW.start_date, NEW.starts_at);

    NEW.ends_at := COALESCE(NEW.ends_at, NEW.end_date);
    NEW.end_date := COALESCE(NEW.end_date, NEW.ends_at);

    NEW.min_age := COALESCE(NEW.min_age, NEW.age_min);
    NEW.age_min := COALESCE(NEW.age_min, NEW.min_age);

    NEW.max_age := COALESCE(NEW.max_age, NEW.age_max);
    NEW.age_max := COALESCE(NEW.age_max, NEW.max_age);

    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.location_point := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
        NEW.location := NEW.location_point;
        NEW.location_geometry := NEW.location_point::geometry;
    ELSIF NEW.location_point IS NOT NULL THEN
        NEW.location := NEW.location_point;
        NEW.location_geometry := NEW.location_point::geometry;
        NEW.longitude := ST_X(NEW.location_geometry);
        NEW.latitude := ST_Y(NEW.location_geometry);
    ELSIF NEW.location IS NOT NULL THEN
        NEW.location_point := NEW.location;
        NEW.location_geometry := NEW.location::geometry;
        NEW.longitude := ST_X(NEW.location::geometry);
        NEW.latitude := ST_Y(NEW.location::geometry);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_sync_event_geo_fields ON events;
CREATE TRIGGER trigger_sync_event_geo_fields
    BEFORE INSERT OR UPDATE ON events
    FOR EACH ROW
    EXECUTE FUNCTION sync_event_geo_fields();

-- Required spatial index
CREATE INDEX IF NOT EXISTS idx_events_location
ON events
USING GIST (location_point);

-- Additional geo/filter indexes for high-traffic map queries
CREATE INDEX IF NOT EXISTS idx_events_geo_status_starts
    ON events(status, starts_at)
    WHERE status = 'approved';

CREATE INDEX IF NOT EXISTS idx_events_geo_category_starts
    ON events(category, starts_at)
    WHERE status = 'approved';

CREATE INDEX IF NOT EXISTS idx_events_geo_gender
    ON events(gender_restriction)
    WHERE status = 'approved';

CREATE INDEX IF NOT EXISTS idx_events_geo_price_free
    ON events(price_cents)
    WHERE status = 'approved' AND price_cents = 0;

CREATE INDEX IF NOT EXISTS idx_events_geo_capacity
    ON events(capacity, reserved_count)
    WHERE status = 'approved' AND capacity IS NOT NULL;

-- 2) Suspicious geo-spam logging and geo request auditing
CREATE TABLE IF NOT EXISTS geo_request_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    ip_address INET,
    endpoint VARCHAR(120) NOT NULL,
    query_hash VARCHAR(64) NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    radius_km DOUBLE PRECISION,
    bbox JSONB DEFAULT '{}',
    filters JSONB DEFAULT '{}',
    is_flagged BOOLEAN NOT NULL DEFAULT false,
    flag_reason VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_geo_request_logs_created_at
    ON geo_request_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_geo_request_logs_query_hash
    ON geo_request_logs(query_hash);
CREATE INDEX IF NOT EXISTS idx_geo_request_logs_flagged
    ON geo_request_logs(is_flagged, created_at DESC)
    WHERE is_flagged = true;

-- 3) Contextual Islamic map layer entities
CREATE TABLE IF NOT EXISTS islamic_places (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    place_type VARCHAR(40) NOT NULL CHECK (place_type IN ('mosque', 'islamic_center', 'halal_restaurant')),
    address TEXT,
    city VARCHAR(120),
    country VARCHAR(120),
    location_point GEOGRAPHY(POINT, 4326) NOT NULL,
    verified BOOLEAN NOT NULL DEFAULT false,
    source VARCHAR(80),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_islamic_places_location
    ON islamic_places
    USING GIST (location_point);

CREATE INDEX IF NOT EXISTS idx_islamic_places_type
    ON islamic_places(place_type);

DROP TRIGGER IF EXISTS trigger_islamic_places_updated_at ON islamic_places;
CREATE TRIGGER trigger_islamic_places_updated_at
    BEFORE UPDATE ON islamic_places
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 4) Anonymous geo interaction metrics
CREATE TABLE IF NOT EXISTS geo_interaction_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(50) NOT NULL CHECK (
        event_type IN (
            'map_open',
            'marker_tap',
            'filter_use',
            'reservation_from_map',
            'distance_distribution'
        )
    ),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    session_hash VARCHAR(64) NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance_km DOUBLE PRECISION,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_geo_metrics_event_time
    ON geo_interaction_metrics(event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_geo_metrics_session
    ON geo_interaction_metrics(session_hash, created_at DESC);

ANALYZE events;
ANALYZE geo_request_logs;
ANALYZE islamic_places;
ANALYZE geo_interaction_metrics;
