DROP TABLE IF EXISTS event_update_requests;

UPDATE events SET status = 'draft' WHERE status = 'cancelled';
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;
ALTER TABLE events ADD CONSTRAINT events_status_check
    CHECK (status IN ('draft', 'pending', 'approved', 'rejected', 'needs_revision', 'published'));
