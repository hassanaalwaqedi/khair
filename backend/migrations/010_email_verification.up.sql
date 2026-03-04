-- Migration 010: Email Verification on Registration
-- Adds is_verified flag, verification_code (6-digit), and expiration for email verification flow

-- 1. Add email verification columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_code VARCHAR(6);
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_expires_at TIMESTAMP WITH TIME ZONE;

-- 2. Backfill: mark existing verified users as is_verified = true
UPDATE users SET is_verified = TRUE WHERE verified_at IS NOT NULL;

-- 3. Index for code lookups
CREATE INDEX IF NOT EXISTS idx_users_verification_code ON users(verification_code);
CREATE INDEX IF NOT EXISTS idx_users_is_verified ON users(is_verified);
