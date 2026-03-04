-- Migration 011: Email verification records table + status compatibility
-- Keeps existing verification columns for backward compatibility.

CREATE TABLE IF NOT EXISTS email_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    otp_hash VARCHAR(64) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    last_sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_email_verifications_user_id
    ON email_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_email_verifications_expires_at
    ON email_verifications(expires_at);

-- Allow pending_verification status used by auth + registration flows.
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_status_check;
ALTER TABLE users ADD CONSTRAINT users_status_check
    CHECK (status IN ('pending', 'pending_verification', 'active', 'suspended', 'deactivated'));

ALTER TABLE users ALTER COLUMN status SET DEFAULT 'pending_verification';

