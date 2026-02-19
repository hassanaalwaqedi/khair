-- Phase 4: AI Personalization Layer
-- User interaction signals, AI scores, and AI profiles

-- User interaction signals (views, joins, saves, searches)
CREATE TABLE IF NOT EXISTS user_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id UUID REFERENCES events(id) ON DELETE SET NULL,
    interaction_type VARCHAR(20) NOT NULL CHECK (interaction_type IN ('view', 'join', 'save', 'search', 'filter', 'click')),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- AI relevance scores (cached per user×event)
CREATE TABLE IF NOT EXISTS ai_event_scores (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    relevance_score FLOAT NOT NULL DEFAULT 0 CHECK (relevance_score >= 0 AND relevance_score <= 1),
    reasoning TEXT,
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, event_id)
);

-- User interest profiles (invisible AI layer)
CREATE TABLE IF NOT EXISTS user_profiles_ai (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    top_categories JSONB DEFAULT '[]',
    preferred_countries JSONB DEFAULT '[]',
    active_hours JSONB DEFAULT '{}',
    social_vs_professional FLOAT DEFAULT 0.5 CHECK (social_vs_professional >= 0 AND social_vs_professional <= 1),
    raw_profile JSONB DEFAULT '{}',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_interactions_user_time ON user_interactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_interactions_event ON user_interactions(event_id);
CREATE INDEX IF NOT EXISTS idx_interactions_type ON user_interactions(interaction_type);
CREATE INDEX IF NOT EXISTS idx_ai_scores_user_rank ON ai_event_scores(user_id, relevance_score DESC);
CREATE INDEX IF NOT EXISTS idx_ai_scores_event ON ai_event_scores(event_id);
