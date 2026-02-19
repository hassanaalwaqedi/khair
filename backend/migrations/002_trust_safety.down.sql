-- Phase 2: Trust & Safety Layer Migration Rollback
-- =================================================

-- Remove default banned keywords
DELETE FROM banned_keywords;

-- Drop triggers
DROP TRIGGER IF EXISTS trigger_prevent_audit_log_update ON audit_logs;
DROP TRIGGER IF EXISTS trigger_prevent_audit_log_delete ON audit_logs;
DROP TRIGGER IF EXISTS trigger_trust_scores_updated_at ON organizer_trust_scores;

-- Drop function
DROP FUNCTION IF EXISTS prevent_audit_log_modification();

-- Drop indexes
DROP INDEX IF EXISTS idx_events_moderation_status;
DROP INDEX IF EXISTS idx_organizers_trust_state;
DROP INDEX IF EXISTS idx_audit_logs_created_at;
DROP INDEX IF EXISTS idx_audit_logs_action;
DROP INDEX IF EXISTS idx_audit_logs_target;
DROP INDEX IF EXISTS idx_audit_logs_actor;
DROP INDEX IF EXISTS idx_banned_keywords_active;
DROP INDEX IF EXISTS idx_banned_keywords_category;
DROP INDEX IF EXISTS idx_moderation_flags_resolved;
DROP INDEX IF EXISTS idx_moderation_flags_event;
DROP INDEX IF EXISTS idx_trust_scores_score;
DROP INDEX IF EXISTS idx_trust_scores_organizer;
DROP INDEX IF EXISTS idx_reports_reporter_type;
DROP INDEX IF EXISTS idx_reports_created_at;
DROP INDEX IF EXISTS idx_reports_status;
DROP INDEX IF EXISTS idx_reports_target;

-- Drop tables
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS banned_keywords;
DROP TABLE IF EXISTS moderation_flags;
DROP TABLE IF EXISTS organizer_trust_scores;
DROP TABLE IF EXISTS reports;

-- Remove added columns
ALTER TABLE events DROP COLUMN IF EXISTS moderation_reason;
ALTER TABLE events DROP COLUMN IF EXISTS moderation_status;
ALTER TABLE organizers DROP COLUMN IF EXISTS trust_state;
