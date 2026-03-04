-- Rollback Migration 010: Email Verification
DROP INDEX IF EXISTS idx_users_is_verified;
DROP INDEX IF EXISTS idx_users_verification_code;
ALTER TABLE users DROP COLUMN IF EXISTS verification_expires_at;
ALTER TABLE users DROP COLUMN IF EXISTS verification_code;
ALTER TABLE users DROP COLUMN IF EXISTS is_verified;
