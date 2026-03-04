-- Rollback migration 017
DROP INDEX IF EXISTS idx_users_deleted;
DROP INDEX IF EXISTS idx_users_suspended;
ALTER TABLE users DROP COLUMN IF EXISTS deleted_at;
ALTER TABLE users DROP COLUMN IF EXISTS suspended_by;
ALTER TABLE users DROP COLUMN IF EXISTS suspended_reason;
ALTER TABLE users DROP COLUMN IF EXISTS suspended_at;
DROP TABLE IF EXISTS refresh_tokens;
