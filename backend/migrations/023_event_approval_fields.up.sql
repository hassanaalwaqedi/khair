-- Add is_published and approved_at columns to events
ALTER TABLE events ADD COLUMN IF NOT EXISTS is_published BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE events ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;

-- Update the status check constraint to include 'published'
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;
ALTER TABLE events ADD CONSTRAINT events_status_check
    CHECK (status IN ('draft', 'pending', 'approved', 'rejected', 'needs_revision', 'published'));

-- Index for filtering published events
CREATE INDEX IF NOT EXISTS idx_events_is_published ON events(is_published);
CREATE INDEX IF NOT EXISTS idx_events_approved_at ON events(approved_at);

-- Composite index for the public listing query (status + is_published)
CREATE INDEX IF NOT EXISTS idx_events_status_published ON events(status, is_published);

-- Backfill: mark existing approved events as published
UPDATE events SET is_published = true, approved_at = COALESCE(reviewed_at, updated_at) WHERE status = 'approved' AND is_published = false;
