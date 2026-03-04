-- Migration 017: Auth & Compliance Hardening
-- Adds refresh tokens table and user suspension support

-- Refresh tokens for JWT renewal
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMP,
    replaced_by UUID REFERENCES refresh_tokens(id),
    user_agent TEXT,
    ip_address VARCHAR(45)
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_token_hash ON refresh_tokens(token_hash);
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);

-- Add suspension fields to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_at TIMESTAMP;
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_reason TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_by UUID REFERENCES users(id);
ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP;

-- Index for finding suspended users
CREATE INDEX IF NOT EXISTS idx_users_suspended ON users(suspended_at) WHERE suspended_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_deleted ON users(deleted_at) WHERE deleted_at IS NOT NULL;
