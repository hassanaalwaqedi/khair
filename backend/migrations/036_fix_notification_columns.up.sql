-- 036: Ensure notification_type and data columns exist (fixes skipped 031_notification_type migration)
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS notification_type VARCHAR(50) NOT NULL DEFAULT 'general';
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS data JSONB NOT NULL DEFAULT '{}';
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(user_id, notification_type);

-- Also ensure sheikh_trust columns exist (fixes skipped 031_sheikh_trust migration)
ALTER TABLE users ADD COLUMN IF NOT EXISTS trust_score INTEGER NOT NULL DEFAULT 50;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_featured BOOLEAN NOT NULL DEFAULT false;
