-- Rollback Migration 012: RBAC System

DROP TABLE IF EXISTS rbac_audit_log;

DROP INDEX IF EXISTS idx_events_reviewed_by;
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;
ALTER TABLE events ADD CONSTRAINT events_status_check
    CHECK (status IN ('draft', 'pending', 'approved', 'rejected'));
ALTER TABLE events DROP COLUMN IF EXISTS reviewed_by;
ALTER TABLE events DROP COLUMN IF EXISTS reviewed_at;

DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS role_permissions;
DROP TABLE IF EXISTS permissions;
DROP TABLE IF EXISTS roles;
