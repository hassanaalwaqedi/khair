-- Migration 019: Performance Optimization Indexes
-- Additional indexes for common query patterns

-- Event queries by status + date (admin dashboard, public listing)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_events_status_start ON events(status, start_date DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_events_organizer_status ON events(organizer_id, status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_events_country_status ON events(country, status) WHERE status = 'published';

-- Order queries by event (revenue dashboard)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_event_status ON orders(event_id, status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_created ON orders(created_at DESC);

-- Refresh token cleanup (expired token purge)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_refresh_tokens_cleanup ON refresh_tokens(expires_at) WHERE revoked_at IS NULL;

-- Organizer badge lookups
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_badges_active ON organizer_badges(organizer_id, badge_type) WHERE is_active = true;

-- Payout reporting
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payouts_period ON payouts(organizer_id, period_start, period_end);

-- Full-text search on event titles (for search API)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_events_title_trgm ON events USING gin(title gin_trgm_ops);

-- Partial index for upcoming published events (most common query)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_events_upcoming ON events(start_date)
    WHERE status = 'published' AND start_date > NOW();
