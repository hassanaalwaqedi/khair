-- Remove indexes
DROP INDEX IF EXISTS idx_events_status_published;
DROP INDEX IF EXISTS idx_events_approved_at;
DROP INDEX IF EXISTS idx_events_is_published;

-- Restore original status constraint
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;
ALTER TABLE events ADD CONSTRAINT events_status_check
    CHECK (status IN ('draft', 'pending', 'approved', 'rejected'));

-- Remove columns
ALTER TABLE events DROP COLUMN IF EXISTS approved_at;
ALTER TABLE events DROP COLUMN IF EXISTS is_published;
