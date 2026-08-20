-- Some early deployments created the Support core tables before attachments
-- were introduced. `CREATE TABLE IF NOT EXISTS` in the initial migration does
-- not add missing columns to an already-existing table, so repair that state
-- explicitly before the messenger reads its optional attachment relation.
CREATE TABLE IF NOT EXISTS support_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES support_messages(id) ON DELETE CASCADE,
    file_url TEXT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    size_bytes BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

ALTER TABLE support_attachments
    ADD COLUMN IF NOT EXISTS message_id UUID,
    ADD COLUMN IF NOT EXISTS file_url TEXT,
    ADD COLUMN IF NOT EXISTS mime_type VARCHAR(100),
    ADD COLUMN IF NOT EXISTS size_bytes BIGINT,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_support_attachments_message
    ON support_attachments(message_id);
