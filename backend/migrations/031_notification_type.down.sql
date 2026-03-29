-- 031: Revert notification type and data columns
DROP INDEX IF EXISTS idx_notifications_type;
ALTER TABLE notifications DROP COLUMN IF EXISTS data;
ALTER TABLE notifications DROP COLUMN IF EXISTS notification_type;
