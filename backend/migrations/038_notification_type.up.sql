-- 031: Add notification type and data columns for deep linking
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS notification_type VARCHAR(50) NOT NULL DEFAULT 'general';
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS data JSONB NOT NULL DEFAULT '{}';
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(user_id, notification_type);
