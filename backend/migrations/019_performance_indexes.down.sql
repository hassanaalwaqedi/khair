-- Rollback migration 019
DROP INDEX CONCURRENTLY IF EXISTS idx_events_upcoming;
DROP INDEX CONCURRENTLY IF EXISTS idx_events_title_trgm;
DROP INDEX CONCURRENTLY IF EXISTS idx_payouts_period;
DROP INDEX CONCURRENTLY IF EXISTS idx_badges_active;
DROP INDEX CONCURRENTLY IF EXISTS idx_refresh_tokens_cleanup;
DROP INDEX CONCURRENTLY IF EXISTS idx_orders_created;
DROP INDEX CONCURRENTLY IF EXISTS idx_orders_event_status;
DROP INDEX CONCURRENTLY IF EXISTS idx_events_country_status;
DROP INDEX CONCURRENTLY IF EXISTS idx_events_organizer_status;
DROP INDEX CONCURRENTLY IF EXISTS idx_events_status_start;
