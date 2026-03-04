ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;
ALTER TABLE events ADD CONSTRAINT events_status_check
    CHECK (status IN ('draft', 'pending', 'approved', 'rejected', 'needs_revision', 'published', 'under_review'));

CREATE TABLE IF NOT EXISTS moderation_scans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    scanned_text TEXT NOT NULL,
    ai_risk_score DOUBLE PRECISION NOT NULL DEFAULT 0,
    ai_decision VARCHAR(30) NOT NULL DEFAULT 'safe'
        CHECK (ai_decision IN ('safe', 'review_required', 'high_risk')),
    detected_flags JSONB NOT NULL DEFAULT '{}',
    compliance_flags JSONB NOT NULL DEFAULT '{}',
    scanned_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    provider VARCHAR(50) NOT NULL DEFAULT 'local',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_moderation_scans_event_id ON moderation_scans(event_id);
CREATE INDEX idx_moderation_scans_ai_decision ON moderation_scans(ai_decision);
CREATE INDEX idx_moderation_scans_risk_score ON moderation_scans(ai_risk_score DESC);
CREATE INDEX idx_moderation_scans_scanned_at ON moderation_scans(scanned_at DESC);

CREATE TABLE IF NOT EXISTS organizer_trust_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organizer_id UUID NOT NULL REFERENCES organizers(id) ON DELETE CASCADE,
    trust_score DOUBLE PRECISION NOT NULL DEFAULT 75,
    violations_count INT NOT NULL DEFAULT 0,
    approved_events_count INT NOT NULL DEFAULT 0,
    rejected_events_count INT NOT NULL DEFAULT 0,
    high_risk_count INT NOT NULL DEFAULT 0,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id),
    UNIQUE(organizer_id)
);

CREATE INDEX idx_organizer_trust_scores_user_id ON organizer_trust_scores(user_id);
CREATE INDEX idx_organizer_trust_scores_organizer_id ON organizer_trust_scores(organizer_id);
CREATE INDEX idx_organizer_trust_scores_score ON organizer_trust_scores(trust_score);

CREATE TABLE IF NOT EXISTS abuse_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action_type VARCHAR(100) NOT NULL,
    risk_score DOUBLE PRECISION NOT NULL DEFAULT 0,
    details JSONB,
    ip_address INET,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_abuse_logs_user_id ON abuse_logs(user_id);
CREATE INDEX idx_abuse_logs_action_type ON abuse_logs(action_type);
CREATE INDEX idx_abuse_logs_created_at ON abuse_logs(created_at DESC);
CREATE INDEX idx_abuse_logs_user_created ON abuse_logs(user_id, created_at DESC);

ALTER TABLE events ADD COLUMN IF NOT EXISTS ai_risk_score DOUBLE PRECISION;
ALTER TABLE events ADD COLUMN IF NOT EXISTS ai_decision VARCHAR(30);
ALTER TABLE events ADD COLUMN IF NOT EXISTS compliance_flags JSONB;
ALTER TABLE events ADD COLUMN IF NOT EXISTS meeting_link_encrypted TEXT;
