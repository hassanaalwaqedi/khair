-- Legal texts table for Terms of Service and Privacy Policy
CREATE TABLE IF NOT EXISTS legal_texts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(50) UNIQUE NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL DEFAULT '',
    updated_by VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed default legal texts
INSERT INTO legal_texts (key, title, content) VALUES
    ('terms', 'Terms of Service', 'Khair Terms of Service - To be updated by admin.'),
    ('privacy', 'Privacy Policy', 'Khair Privacy Policy - To be updated by admin.')
ON CONFLICT (key) DO NOTHING;
