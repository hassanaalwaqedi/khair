DROP INDEX IF EXISTS uq_notifications_user_dedupe_key;
ALTER TABLE notifications DROP COLUMN IF EXISTS dedupe_key;

DROP INDEX IF EXISTS idx_device_tokens_active_user;
DROP INDEX IF EXISTS uq_device_tokens_token;
ALTER TABLE device_tokens DROP COLUMN IF EXISTS is_active;
ALTER TABLE device_tokens DROP COLUMN IF EXISTS last_seen_at;

ALTER TABLE device_tokens
    ADD CONSTRAINT device_tokens_user_id_token_key UNIQUE (user_id, token);
CREATE INDEX IF NOT EXISTS idx_device_tokens_token ON device_tokens(token);
