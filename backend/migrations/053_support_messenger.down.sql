DROP INDEX IF EXISTS idx_support_tickets_context;
DROP INDEX IF EXISTS idx_support_tickets_active_conversation;

UPDATE support_tickets SET status = 'waiting_for_support'
WHERE status = 'waiting_for_agent';

UPDATE support_tickets SET status = 'in_progress'
WHERE status = 'human_active';

ALTER TABLE support_messages DROP COLUMN IF EXISTS metadata;
ALTER TABLE support_tickets
    DROP COLUMN IF EXISTS context_id,
    DROP COLUMN IF EXISTS context_type,
    DROP COLUMN IF EXISTS language;
