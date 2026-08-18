-- Create Support Agent Role
INSERT INTO roles (name, description) VALUES ('support_agent', 'Customer Support Agent') ON CONFLICT (name) DO NOTHING;

-- Permissions for support agent
INSERT INTO permissions (name, description) VALUES 
('view_support_tickets', 'View all support tickets'),
('respond_support_tickets', 'Respond to support tickets'),
('resolve_support_tickets', 'Resolve support tickets')
ON CONFLICT (name) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.name = 'support_agent' AND p.name IN ('view_support_tickets', 'respond_support_tickets', 'resolve_support_tickets')
ON CONFLICT DO NOTHING;

-- Admins also get support permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.name IN ('admin', 'super_admin') AND p.name IN ('view_support_tickets', 'respond_support_tickets', 'resolve_support_tickets')
ON CONFLICT DO NOTHING;

-- Support Articles (Knowledge Base)
CREATE TABLE IF NOT EXISTS support_articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(255) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    category VARCHAR(100) NOT NULL,
    language VARCHAR(10) NOT NULL DEFAULT 'en',
    is_published BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_support_articles_published ON support_articles(is_published, language);

-- Support Tickets
CREATE TABLE IF NOT EXISTS support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
    category VARCHAR(100) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'ai_active',
    priority VARCHAR(50) NOT NULL DEFAULT 'normal',
    ai_summary TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    first_human_response_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    closed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_support_tickets_user ON support_tickets(user_id);
CREATE INDEX idx_support_tickets_status ON support_tickets(status);
CREATE INDEX idx_support_tickets_assigned ON support_tickets(assigned_to);

-- Support Messages
CREATE TABLE IF NOT EXISTS support_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
    sender_type VARCHAR(50) NOT NULL, -- 'user', 'ai', 'support_agent', 'system'
    sender_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    body TEXT NOT NULL,
    message_type VARCHAR(50) NOT NULL DEFAULT 'text', -- 'text', 'attachment', 'internal_note'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_support_messages_ticket ON support_messages(ticket_id, created_at);

-- Support Attachments
CREATE TABLE IF NOT EXISTS support_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES support_messages(id) ON DELETE CASCADE,
    file_url TEXT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    size_bytes BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Triggers for updated_at
CREATE TRIGGER trigger_support_articles_updated_at
    BEFORE UPDATE ON support_articles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_support_tickets_updated_at
    BEFORE UPDATE ON support_tickets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
