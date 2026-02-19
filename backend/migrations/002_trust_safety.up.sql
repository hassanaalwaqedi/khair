-- Phase 2: Trust & Safety Layer Migration
-- =========================================

-- Extend organizers table with trust state
ALTER TABLE organizers 
ADD COLUMN IF NOT EXISTS trust_state VARCHAR(50) NOT NULL DEFAULT 'active'
    CHECK (trust_state IN ('active', 'warning', 'suspended', 'banned'));

-- Extend events table with moderation status
ALTER TABLE events
ADD COLUMN IF NOT EXISTS moderation_status VARCHAR(50) NOT NULL DEFAULT 'pending'
    CHECK (moderation_status IN ('pending', 'approved', 'flagged', 'rejected'));

ALTER TABLE events
ADD COLUMN IF NOT EXISTS moderation_reason TEXT;

-- Reports table for user/guest/system reports
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_type VARCHAR(50) NOT NULL CHECK (target_type IN ('event', 'organizer')),
    target_id UUID NOT NULL,
    reporter_type VARCHAR(50) NOT NULL CHECK (reporter_type IN ('guest', 'user', 'system')),
    reporter_id UUID, -- NULL for guests
    reporter_ip VARCHAR(45), -- For guest tracking
    reason_category VARCHAR(100) NOT NULL CHECK (reason_category IN (
        'political_content',
        'hate_speech',
        'misleading_charity',
        'spam',
        'inappropriate_content',
        'fake_event',
        'other'
    )),
    description TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'reviewing', 'resolved', 'dismissed')),
    resolution_action VARCHAR(100),
    resolution_notes TEXT,
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Organizer trust scores (internal metrics)
CREATE TABLE organizer_trust_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id UUID UNIQUE REFERENCES organizers(id) ON DELETE CASCADE,
    trust_score INTEGER NOT NULL DEFAULT 100 CHECK (trust_score >= 0 AND trust_score <= 100),
    approved_events_count INTEGER NOT NULL DEFAULT 0,
    rejected_events_count INTEGER NOT NULL DEFAULT 0,
    reports_received_count INTEGER NOT NULL DEFAULT 0,
    event_cancellations_count INTEGER NOT NULL DEFAULT 0,
    warnings_count INTEGER NOT NULL DEFAULT 0,
    last_calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Moderation flags from content checks
CREATE TABLE moderation_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    flag_type VARCHAR(100) NOT NULL CHECK (flag_type IN (
        'banned_keyword',
        'pattern_match',
        'ai_flagged',
        'manual_review'
    )),
    flag_reason TEXT NOT NULL,
    matched_content TEXT,
    severity VARCHAR(50) NOT NULL DEFAULT 'medium'
        CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Banned keywords for moderation
CREATE TABLE banned_keywords (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    keyword VARCHAR(255) NOT NULL,
    category VARCHAR(100) NOT NULL CHECK (category IN (
        'political',
        'hate_speech',
        'misleading_charity',
        'spam',
        'profanity',
        'other'
    )),
    severity VARCHAR(50) NOT NULL DEFAULT 'medium'
        CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    is_regex BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- CRITICAL: Immutable audit logs (no UPDATE/DELETE allowed)
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_type VARCHAR(50) NOT NULL CHECK (actor_type IN ('admin', 'system')),
    actor_id UUID, -- NULL for system actions
    action VARCHAR(100) NOT NULL,
    target_type VARCHAR(50) NOT NULL,
    target_id UUID NOT NULL,
    old_value JSONB,
    new_value JSONB,
    reason TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Prevent updates and deletes on audit_logs
CREATE OR REPLACE FUNCTION prevent_audit_log_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit logs are immutable. UPDATE and DELETE operations are not permitted.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_prevent_audit_log_update
    BEFORE UPDATE ON audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_log_modification();

CREATE TRIGGER trigger_prevent_audit_log_delete
    BEFORE DELETE ON audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_log_modification();

-- Indexes for performance
CREATE INDEX idx_reports_target ON reports(target_type, target_id);
CREATE INDEX idx_reports_status ON reports(status);
CREATE INDEX idx_reports_created_at ON reports(created_at);
CREATE INDEX idx_reports_reporter_type ON reports(reporter_type);

CREATE INDEX idx_trust_scores_organizer ON organizer_trust_scores(organizer_id);
CREATE INDEX idx_trust_scores_score ON organizer_trust_scores(trust_score);

CREATE INDEX idx_moderation_flags_event ON moderation_flags(event_id);
CREATE INDEX idx_moderation_flags_resolved ON moderation_flags(is_resolved);

CREATE INDEX idx_banned_keywords_category ON banned_keywords(category);
CREATE INDEX idx_banned_keywords_active ON banned_keywords(is_active);

CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_type, actor_id);
CREATE INDEX idx_audit_logs_target ON audit_logs(target_type, target_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);

CREATE INDEX idx_organizers_trust_state ON organizers(trust_state);
CREATE INDEX idx_events_moderation_status ON events(moderation_status);

-- Trigger for trust_scores updated_at
CREATE TRIGGER trigger_trust_scores_updated_at
    BEFORE UPDATE ON organizer_trust_scores
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert default banned keywords
INSERT INTO banned_keywords (keyword, category, severity, is_regex, is_active) VALUES
-- Political content
('election', 'political', 'medium', FALSE, TRUE),
('political party', 'political', 'high', FALSE, TRUE),
('campaign rally', 'political', 'high', FALSE, TRUE),
('vote for', 'political', 'high', FALSE, TRUE),
-- Hate speech patterns
('hate', 'hate_speech', 'high', FALSE, TRUE),
('discrimination', 'hate_speech', 'medium', FALSE, TRUE),
-- Misleading charity
('100% goes to', 'misleading_charity', 'high', FALSE, TRUE),
('guaranteed donation', 'misleading_charity', 'high', FALSE, TRUE),
('send money to', 'misleading_charity', 'critical', FALSE, TRUE),
-- Spam patterns
('click here now', 'spam', 'medium', FALSE, TRUE),
('limited time offer', 'spam', 'low', FALSE, TRUE),
('act now', 'spam', 'low', FALSE, TRUE);
