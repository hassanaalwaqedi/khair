ALTER TABLE events DROP COLUMN IF EXISTS meeting_link_encrypted;
ALTER TABLE events DROP COLUMN IF EXISTS compliance_flags;
ALTER TABLE events DROP COLUMN IF EXISTS ai_decision;
ALTER TABLE events DROP COLUMN IF EXISTS ai_risk_score;

DROP TABLE IF EXISTS abuse_logs;
DROP TABLE IF EXISTS organizer_trust_scores;
DROP TABLE IF EXISTS moderation_scans;

ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;
ALTER TABLE events ADD CONSTRAINT events_status_check
    CHECK (status IN ('draft', 'pending', 'approved', 'rejected', 'needs_revision', 'published'));
