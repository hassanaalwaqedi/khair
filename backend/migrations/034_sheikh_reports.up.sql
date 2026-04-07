-- sheikh_reports was already created in 031_sheikh_trust with column 'reported_by'.
-- This migration adds the 'reporter_id' alias column and updates indexes for compatibility.

-- Add reporter_id column if not present (031 used 'reported_by' instead)
ALTER TABLE sheikh_reports ADD COLUMN IF NOT EXISTS reporter_id UUID REFERENCES users(id) ON DELETE CASCADE;

-- Backfill reporter_id from reported_by if both exist
UPDATE sheikh_reports SET reporter_id = reported_by WHERE reporter_id IS NULL AND reported_by IS NOT NULL;

-- Add reason column if not present
ALTER TABLE sheikh_reports ADD COLUMN IF NOT EXISTS reason TEXT;

CREATE INDEX IF NOT EXISTS idx_sheikh_reports_sheikh_id ON sheikh_reports(sheikh_id);
CREATE INDEX IF NOT EXISTS idx_sheikh_reports_reporter_id ON sheikh_reports(reporter_id);
