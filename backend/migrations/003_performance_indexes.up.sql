-- Phase 3: Performance Indexes Migration
-- =======================================

-- Composite index for upcoming events by date and status
CREATE INDEX IF NOT EXISTS idx_events_start_date_status 
ON events(start_date, status) 
WHERE status = 'approved';

-- Composite index for city filtering with status
CREATE INDEX IF NOT EXISTS idx_events_city_status 
ON events(city, status) 
WHERE status = 'approved';

-- Composite index for country + city + date (common filter pattern)
CREATE INDEX IF NOT EXISTS idx_events_country_city_date 
ON events(country, city, start_date) 
WHERE status = 'approved';

-- Composite index for event type filtering
CREATE INDEX IF NOT EXISTS idx_events_type_date 
ON events(event_type, start_date) 
WHERE status = 'approved';

-- B-tree index on latitude/longitude for faster geo queries
CREATE INDEX IF NOT EXISTS idx_events_lat_lng 
ON events(latitude, longitude) 
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Partial index for pending events (admin queue)
CREATE INDEX IF NOT EXISTS idx_events_pending 
ON events(created_at) 
WHERE status = 'pending';

-- Partial index for pending organizers (admin queue)
CREATE INDEX IF NOT EXISTS idx_organizers_pending 
ON organizers(created_at) 
WHERE status = 'pending';

-- Index for trust state filtering
CREATE INDEX IF NOT EXISTS idx_organizers_trust_state_active 
ON organizers(trust_state) 
WHERE trust_state != 'banned';

-- Composite index for reports by status and date
CREATE INDEX IF NOT EXISTS idx_reports_status_date 
ON reports(status, created_at) 
WHERE status = 'pending';

-- Analyze tables to update statistics
ANALYZE events;
ANALYZE organizers;
ANALYZE reports;
