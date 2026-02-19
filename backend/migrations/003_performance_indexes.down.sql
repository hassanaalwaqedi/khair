-- Phase 3: Performance Indexes Rollback
-- ======================================

DROP INDEX IF EXISTS idx_reports_status_date;
DROP INDEX IF EXISTS idx_organizers_trust_state_active;
DROP INDEX IF EXISTS idx_organizers_pending;
DROP INDEX IF EXISTS idx_events_pending;
DROP INDEX IF EXISTS idx_events_lat_lng;
DROP INDEX IF EXISTS idx_events_type_date;
DROP INDEX IF EXISTS idx_events_country_city_date;
DROP INDEX IF EXISTS idx_events_city_status;
DROP INDEX IF EXISTS idx_events_start_date_status;
