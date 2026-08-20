-- Device token ownership and activity state. A token represents one physical
-- app installation, so it must be associated with at most one user at a time.
ALTER TABLE device_tokens
    ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

UPDATE device_tokens
SET last_seen_at = COALESCE(last_seen_at, updated_at, created_at, NOW()),
    is_active = COALESCE(is_active, true);

-- Keep the most recently seen row when legacy data contains the same device
-- token under more than one account.
DELETE FROM device_tokens older
USING device_tokens newer
WHERE older.token = newer.token
  AND (older.last_seen_at, older.updated_at, older.created_at, older.id)
      < (newer.last_seen_at, newer.updated_at, newer.created_at, newer.id);

ALTER TABLE device_tokens DROP CONSTRAINT IF EXISTS device_tokens_user_id_token_key;
DROP INDEX IF EXISTS idx_device_tokens_token;
CREATE UNIQUE INDEX IF NOT EXISTS uq_device_tokens_token ON device_tokens(token);
CREATE INDEX IF NOT EXISTS idx_device_tokens_active_user
    ON device_tokens(user_id)
    WHERE is_active = true;

-- A bounded idempotency key prevents duplicate system pushes when a business
-- action or background worker is retried.
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS dedupe_key TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_user_dedupe_key
    ON notifications(user_id, dedupe_key)
    WHERE dedupe_key IS NOT NULL;
