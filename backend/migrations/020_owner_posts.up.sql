CREATE TABLE IF NOT EXISTS owner_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    short_description TEXT NOT NULL,
    image_url TEXT,
    external_link TEXT,
    location VARCHAR(255),
    published_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL REFERENCES users(id),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_owner_posts_active ON owner_posts (is_active, published_at DESC);
