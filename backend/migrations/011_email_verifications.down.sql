DROP INDEX IF EXISTS idx_email_verifications_expires_at;
DROP INDEX IF EXISTS idx_email_verifications_user_id;
DROP TABLE IF EXISTS email_verifications;

ALTER TABLE users DROP CONSTRAINT IF EXISTS users_status_check;
ALTER TABLE users ADD CONSTRAINT users_status_check
    CHECK (status IN ('pending', 'active', 'suspended', 'deactivated'));

ALTER TABLE users ALTER COLUMN status SET DEFAULT 'pending';

