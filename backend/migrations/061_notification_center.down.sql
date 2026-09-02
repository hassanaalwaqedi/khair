DROP TABLE IF EXISTS notification_delivery_logs;
DROP TABLE IF EXISTS notification_preferences;
DROP INDEX IF EXISTS idx_notifications_user_created;
DROP INDEX IF EXISTS idx_notifications_related_event;
ALTER TABLE notifications
    DROP COLUMN IF EXISTS read_at,
    DROP COLUMN IF EXISTS action_url,
    DROP COLUMN IF EXISTS related_message_id,
    DROP COLUMN IF EXISTS related_conversation_id,
    DROP COLUMN IF EXISTS related_event_id,
    DROP COLUMN IF EXISTS actor_user_id;
