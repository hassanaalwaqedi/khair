-- Organizer edits to approved/published events are reviewed as immutable
-- snapshots. The currently published event remains the public version while
-- a request is pending.
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;
ALTER TABLE events ADD CONSTRAINT events_status_check
    CHECK (status IN ('draft', 'pending', 'approved', 'rejected', 'needs_revision', 'published', 'cancelled'));

CREATE TABLE IF NOT EXISTS event_update_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    organizer_id UUID NOT NULL REFERENCES organizers(id) ON DELETE CASCADE,
    requested_by UUID REFERENCES users(id) ON DELETE SET NULL,
    proposed_event JSONB NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected', 'needs_revision')),
    rejection_reason TEXT,
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_event_update_requests_one_pending
    ON event_update_requests(event_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_event_update_requests_status_created
    ON event_update_requests(status, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_event_update_requests_event
    ON event_update_requests(event_id, created_at DESC);

DROP TRIGGER IF EXISTS trigger_event_update_requests_updated_at ON event_update_requests;
CREATE TRIGGER trigger_event_update_requests_updated_at
    BEFORE UPDATE ON event_update_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
