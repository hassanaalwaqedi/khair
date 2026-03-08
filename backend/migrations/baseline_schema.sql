-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Users table for authentication
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('organizer', 'admin')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Organizers table for organization profiles
CREATE TABLE organizers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    website VARCHAR(500),
    phone VARCHAR(50),
    logo_url VARCHAR(500),
    status VARCHAR(50) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'approved', 'rejected')),
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Events table with geospatial support
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id UUID REFERENCES organizers(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    event_type VARCHAR(100) NOT NULL,
    language VARCHAR(50),
    country VARCHAR(100),
    city VARCHAR(100),
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    location GEOGRAPHY(POINT, 4326),
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE,
    image_url VARCHAR(500),
    status VARCHAR(50) NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'pending', 'approved', 'rejected')),
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

CREATE INDEX idx_organizers_user_id ON organizers(user_id);
CREATE INDEX idx_organizers_status ON organizers(status);

CREATE INDEX idx_events_organizer_id ON events(organizer_id);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_country ON events(country);
CREATE INDEX idx_events_city ON events(city);
CREATE INDEX idx_events_country_city ON events(country, city);
CREATE INDEX idx_events_event_type ON events(event_type);
CREATE INDEX idx_events_language ON events(language);
CREATE INDEX idx_events_start_date ON events(start_date);
CREATE INDEX idx_events_location ON events USING GIST(location);

-- Trigger function to update location from lat/lng
CREATE OR REPLACE FUNCTION update_event_location()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.location = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_event_location
    BEFORE INSERT OR UPDATE ON events
    FOR EACH ROW
    EXECUTE FUNCTION update_event_location();

-- Trigger function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_organizers_updated_at
    BEFORE UPDATE ON organizers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_events_updated_at
    BEFORE UPDATE ON events
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Phase 2: Trust & Safety Layer Migration
-- =========================================

-- Extend organizers table with trust state
ALTER TABLE organizers 
ADD COLUMN IF NOT EXISTS trust_state VARCHAR(50) NOT NULL DEFAULT 'active'
    CHECK (trust_state IN ('active', 'warning', 'suspended', 'banned'));

-- Extend events table with moderation status
ALTER TABLE events
ADD COLUMN IF NOT EXISTS moderation_status VARCHAR(50) NOT NULL DEFAULT 'pending'
    CHECK (moderation_status IN ('pending', 'approved', 'flagged', 'rejected'));

ALTER TABLE events
ADD COLUMN IF NOT EXISTS moderation_reason TEXT;

-- Reports table for user/guest/system reports
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_type VARCHAR(50) NOT NULL CHECK (target_type IN ('event', 'organizer')),
    target_id UUID NOT NULL,
    reporter_type VARCHAR(50) NOT NULL CHECK (reporter_type IN ('guest', 'user', 'system')),
    reporter_id UUID, -- NULL for guests
    reporter_ip VARCHAR(45), -- For guest tracking
    reason_category VARCHAR(100) NOT NULL CHECK (reason_category IN (
        'political_content',
        'hate_speech',
        'misleading_charity',
        'spam',
        'inappropriate_content',
        'fake_event',
        'other'
    )),
    description TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'reviewing', 'resolved', 'dismissed')),
    resolution_action VARCHAR(100),
    resolution_notes TEXT,
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Organizer trust scores (internal metrics)
CREATE TABLE organizer_trust_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id UUID UNIQUE REFERENCES organizers(id) ON DELETE CASCADE,
    trust_score INTEGER NOT NULL DEFAULT 100 CHECK (trust_score >= 0 AND trust_score <= 100),
    approved_events_count INTEGER NOT NULL DEFAULT 0,
    rejected_events_count INTEGER NOT NULL DEFAULT 0,
    reports_received_count INTEGER NOT NULL DEFAULT 0,
    event_cancellations_count INTEGER NOT NULL DEFAULT 0,
    warnings_count INTEGER NOT NULL DEFAULT 0,
    last_calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Moderation flags from content checks
CREATE TABLE moderation_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    flag_type VARCHAR(100) NOT NULL CHECK (flag_type IN (
        'banned_keyword',
        'pattern_match',
        'ai_flagged',
        'manual_review'
    )),
    flag_reason TEXT NOT NULL,
    matched_content TEXT,
    severity VARCHAR(50) NOT NULL DEFAULT 'medium'
        CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Banned keywords for moderation
CREATE TABLE banned_keywords (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    keyword VARCHAR(255) NOT NULL,
    category VARCHAR(100) NOT NULL CHECK (category IN (
        'political',
        'hate_speech',
        'misleading_charity',
        'spam',
        'profanity',
        'other'
    )),
    severity VARCHAR(50) NOT NULL DEFAULT 'medium'
        CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    is_regex BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- CRITICAL: Immutable audit logs (no UPDATE/DELETE allowed)
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_type VARCHAR(50) NOT NULL CHECK (actor_type IN ('admin', 'system')),
    actor_id UUID, -- NULL for system actions
    action VARCHAR(100) NOT NULL,
    target_type VARCHAR(50) NOT NULL,
    target_id UUID NOT NULL,
    old_value JSONB,
    new_value JSONB,
    reason TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Prevent updates and deletes on audit_logs
CREATE OR REPLACE FUNCTION prevent_audit_log_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit logs are immutable. UPDATE and DELETE operations are not permitted.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_prevent_audit_log_update
    BEFORE UPDATE ON audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_log_modification();

CREATE TRIGGER trigger_prevent_audit_log_delete
    BEFORE DELETE ON audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_log_modification();

-- Indexes for performance
CREATE INDEX idx_reports_target ON reports(target_type, target_id);
CREATE INDEX idx_reports_status ON reports(status);
CREATE INDEX idx_reports_created_at ON reports(created_at);
CREATE INDEX idx_reports_reporter_type ON reports(reporter_type);

CREATE INDEX idx_trust_scores_organizer ON organizer_trust_scores(organizer_id);
CREATE INDEX idx_trust_scores_score ON organizer_trust_scores(trust_score);

CREATE INDEX idx_moderation_flags_event ON moderation_flags(event_id);
CREATE INDEX idx_moderation_flags_resolved ON moderation_flags(is_resolved);

CREATE INDEX idx_banned_keywords_category ON banned_keywords(category);
CREATE INDEX idx_banned_keywords_active ON banned_keywords(is_active);

CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_type, actor_id);
CREATE INDEX idx_audit_logs_target ON audit_logs(target_type, target_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);

CREATE INDEX idx_organizers_trust_state ON organizers(trust_state);
CREATE INDEX idx_events_moderation_status ON events(moderation_status);

-- Trigger for trust_scores updated_at
CREATE TRIGGER trigger_trust_scores_updated_at
    BEFORE UPDATE ON organizer_trust_scores
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert default banned keywords
INSERT INTO banned_keywords (keyword, category, severity, is_regex, is_active) VALUES
-- Political content
('election', 'political', 'medium', FALSE, TRUE),
('political party', 'political', 'high', FALSE, TRUE),
('campaign rally', 'political', 'high', FALSE, TRUE),
('vote for', 'political', 'high', FALSE, TRUE),
-- Hate speech patterns
('hate', 'hate_speech', 'high', FALSE, TRUE),
('discrimination', 'hate_speech', 'medium', FALSE, TRUE),
-- Misleading charity
('100% goes to', 'misleading_charity', 'high', FALSE, TRUE),
('guaranteed donation', 'misleading_charity', 'high', FALSE, TRUE),
('send money to', 'misleading_charity', 'critical', FALSE, TRUE),
-- Spam patterns
('click here now', 'spam', 'medium', FALSE, TRUE),
('limited time offer', 'spam', 'low', FALSE, TRUE),
('act now', 'spam', 'low', FALSE, TRUE);

-- Phase 3: Performance Indexes Migration
-- =======================================

-- Composite index for upcoming events by date and status
CREATE INDEX IF NOT EXISTS idx_events_start_date_status 
ON events(start_date, status) 
WHERE status = 'approved';

-- Composite index for city filtering with status
CREATE INDEX IF NOT EXISTS idx_events_city_status 
ON events(city, status) 
WHERE status = 'approved';

-- Composite index for country + city + date (common filter pattern)
CREATE INDEX IF NOT EXISTS idx_events_country_city_date 
ON events(country, city, start_date) 
WHERE status = 'approved';

-- Composite index for event type filtering
CREATE INDEX IF NOT EXISTS idx_events_type_date 
ON events(event_type, start_date) 
WHERE status = 'approved';

-- B-tree index on latitude/longitude for faster geo queries
CREATE INDEX IF NOT EXISTS idx_events_lat_lng 
ON events(latitude, longitude) 
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Partial index for pending events (admin queue)
CREATE INDEX IF NOT EXISTS idx_events_pending 
ON events(created_at) 
WHERE status = 'pending';

-- Partial index for pending organizers (admin queue)
CREATE INDEX IF NOT EXISTS idx_organizers_pending 
ON organizers(created_at) 
WHERE status = 'pending';

-- Index for trust state filtering
CREATE INDEX IF NOT EXISTS idx_organizers_trust_state_active 
ON organizers(trust_state) 
WHERE trust_state != 'banned';

-- Composite index for reports by status and date
CREATE INDEX IF NOT EXISTS idx_reports_status_date 
ON reports(status, created_at) 
WHERE status = 'pending';

-- Analyze tables to update statistics
ANALYZE events;
ANALYZE organizers;
ANALYZE reports;

-- Phase 4: Legal Compliance & Public Access
-- ==========================================

-- Policy/Terms version tracking
CREATE TABLE IF NOT EXISTS policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_type VARCHAR(50) NOT NULL, -- 'terms_of_service', 'privacy_policy', 'organizer_agreement'
    version VARCHAR(20) NOT NULL,
    content_hash VARCHAR(64) NOT NULL, -- SHA-256 hash of content
    effective_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_current BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(policy_type, version)
);

-- User policy acceptances
CREATE TABLE IF NOT EXISTS policy_acceptances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    policy_id UUID REFERENCES policies(id) ON DELETE CASCADE,
    accepted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT,
    
    UNIQUE(user_id, policy_id)
);

-- Organizer agreement acceptances (separate for legal clarity)
CREATE TABLE IF NOT EXISTS organizer_agreements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id UUID REFERENCES organizers(id) ON DELETE CASCADE,
    policy_id UUID REFERENCES policies(id) ON DELETE CASCADE,
    accepted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    accepted_by_user_id UUID REFERENCES users(id),
    ip_address INET,
    user_agent TEXT,
    
    UNIQUE(organizer_id, policy_id)
);

-- Emergency switches table (persisted state)
CREATE TABLE IF NOT EXISTS system_switches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    switch_name VARCHAR(100) UNIQUE NOT NULL,
    is_enabled BOOLEAN DEFAULT true,
    reason TEXT,
    changed_by UUID REFERENCES users(id),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE -- optional auto-expire
);

-- Insert default switches
INSERT INTO system_switches (switch_name, is_enabled, reason) VALUES
    ('event_publishing', true, 'Default enabled'),
    ('organizer_registration', true, 'Default enabled'),
    ('guest_access', true, 'Default enabled'),
    ('reporting_system', true, 'Default enabled'),
    ('full_lockdown', false, 'Emergency only')
ON CONFLICT (switch_name) DO NOTHING;

-- Insert current policy versions (placeholders - actual content managed externally)
INSERT INTO policies (policy_type, version, content_hash, effective_date, is_current) VALUES
    ('terms_of_service', '1.0.0', 'placeholder_hash_tos_v1', NOW(), true),
    ('privacy_policy', '1.0.0', 'placeholder_hash_pp_v1', NOW(), true),
    ('organizer_agreement', '1.0.0', 'placeholder_hash_oa_v1', NOW(), true)
ON CONFLICT (policy_type, version) DO NOTHING;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_policy_acceptances_user ON policy_acceptances(user_id);
CREATE INDEX IF NOT EXISTS idx_policy_acceptances_policy ON policy_acceptances(policy_id);
CREATE INDEX IF NOT EXISTS idx_organizer_agreements_organizer ON organizer_agreements(organizer_id);
CREATE INDEX IF NOT EXISTS idx_policies_current ON policies(policy_type, is_current) WHERE is_current = true;
CREATE INDEX IF NOT EXISTS idx_system_switches_name ON system_switches(switch_name);

-- Function to check if user has accepted current policy
CREATE OR REPLACE FUNCTION user_has_accepted_current_policy(
    p_user_id UUID,
    p_policy_type VARCHAR(50)
) RETURNS BOOLEAN AS $$
DECLARE
    v_accepted BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM policy_acceptances pa
        JOIN policies p ON pa.policy_id = p.id
        WHERE pa.user_id = p_user_id
        AND p.policy_type = p_policy_type
        AND p.is_current = true
    ) INTO v_accepted;
    
    RETURN v_accepted;
END;
$$ LANGUAGE plpgsql;

-- Function to check if organizer has accepted current agreement
CREATE OR REPLACE FUNCTION organizer_has_accepted_agreement(
    p_organizer_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_accepted BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM organizer_agreements oa
        JOIN policies p ON oa.policy_id = p.id
        WHERE oa.organizer_id = p_organizer_id
        AND p.policy_type = 'organizer_agreement'
        AND p.is_current = true
    ) INTO v_accepted;
    
    RETURN v_accepted;
END;
$$ LANGUAGE plpgsql;

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

-- AI relevance scores (cached per userÃ—event)
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

-- Migration 006: Multi-Role Registration System
-- Expands the platform from organizer-only to 5 roles with profiles, drafts, and audit logging

-- 1. Expand the role check constraint to support new roles
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check 
    CHECK (role IN ('organization', 'sheikh', 'new_muslim', 'student', 'community_organizer', 'admin', 'organizer'));

-- 2. Add new columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS status VARCHAR(50) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'active', 'suspended', 'deactivated'));
ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_token VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_expires TIMESTAMP WITH TIME ZONE;

-- 3. Profiles table (shared across all roles)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bio TEXT,
    location VARCHAR(255),
    city VARCHAR(100),
    country VARCHAR(100),
    avatar_url VARCHAR(500),
    preferred_language VARCHAR(10) DEFAULT 'en',
    profile_completion_score INTEGER DEFAULT 0 CHECK (profile_completion_score >= 0 AND profile_completion_score <= 100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Sheikhs table (role-specific)
CREATE TABLE IF NOT EXISTS sheikhs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    specialization VARCHAR(255),
    ijazah_info TEXT,
    certifications TEXT[] DEFAULT '{}',
    years_of_experience INTEGER,
    verification_status VARCHAR(50) NOT NULL DEFAULT 'unverified'
        CHECK (verification_status IN ('unverified', 'pending', 'verified', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Add organization-specific columns to organizers table
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS registration_number VARCHAR(100);
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS organization_type VARCHAR(100) DEFAULT 'community'
    CHECK (organization_type IN ('quran_center', 'mosque', 'community', 'charity', 'educational', 'other'));
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS city VARCHAR(100);
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS country VARCHAR(100);

-- 6. Registration drafts (save & continue later)
CREATE TABLE IF NOT EXISTS registration_drafts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL,
    current_step INTEGER NOT NULL DEFAULT 1 CHECK (current_step >= 1 AND current_step <= 5),
    role VARCHAR(50),
    form_data JSONB NOT NULL DEFAULT '{}',
    ip_address VARCHAR(45),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. Registration audit log
CREATE TABLE IF NOT EXISTS registration_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    email VARCHAR(255),
    step INTEGER,
    action VARCHAR(100) NOT NULL,
    details JSONB DEFAULT '{}',
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_sheikhs_user_id ON sheikhs(user_id);
CREATE INDEX IF NOT EXISTS idx_sheikhs_verification ON sheikhs(verification_status);
CREATE INDEX IF NOT EXISTS idx_registration_drafts_email ON registration_drafts(email);
CREATE INDEX IF NOT EXISTS idx_registration_drafts_expires ON registration_drafts(expires_at);
CREATE INDEX IF NOT EXISTS idx_registration_audit_user ON registration_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_registration_audit_email ON registration_audit_log(email);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_verification_token ON users(verification_token);

-- Triggers for updated_at
CREATE TRIGGER trigger_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_sheikhs_updated_at
    BEFORE UPDATE ON sheikhs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_registration_drafts_updated_at
    BEFORE UPDATE ON registration_drafts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Migration 007: Event Join System
-- Adds event capacity, event_registrations, user gender/age, member role

-- 1. Add 'member' to users role constraint
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (
    role IN ('organizer', 'admin', 'organization', 'sheikh', 'new_muslim', 'student', 'community_organizer', 'member')
);

-- 2. Add gender and age to users
ALTER TABLE users ADD COLUMN IF NOT EXISTS gender VARCHAR(10);
ALTER TABLE users ADD COLUMN IF NOT EXISTS age INT;

-- 3. Add capacity and reserved_count to events
ALTER TABLE events ADD COLUMN IF NOT EXISTS capacity INT;
ALTER TABLE events ADD COLUMN IF NOT EXISTS reserved_count INT NOT NULL DEFAULT 0;

-- 4. Create event_registrations table
CREATE TABLE IF NOT EXISTS event_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'expired', 'cancelled')),
    reserved_until TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, event_id)
);

-- 5. Indexes for event_registrations
CREATE INDEX IF NOT EXISTS idx_event_reg_user_id ON event_registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_event_reg_event_id ON event_registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_event_reg_status ON event_registrations(status);
CREATE INDEX IF NOT EXISTS idx_event_reg_reserved_until ON event_registrations(reserved_until) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_event_reg_user_event ON event_registrations(user_id, event_id);

-- 6. Trigger for updated_at on event_registrations
CREATE TRIGGER set_event_registrations_updated_at
    BEFORE UPDATE ON event_registrations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 7. Index for event capacity queries
CREATE INDEX IF NOT EXISTS idx_events_capacity ON events(capacity) WHERE capacity IS NOT NULL;

-- ============================================================
-- Migration 008: Organization Dashboard System
-- Adds: organization_members (RBAC), org_audit_logs, 
--        organizer extensions (trust_level, profile_completion, contact_email)
-- ============================================================

-- 1. Organization Members table for RBAC sub-roles
CREATE TABLE organization_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'viewer'
        CHECK (role IN ('owner', 'admin', 'event_manager', 'viewer')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(organization_id, user_id)
);

CREATE INDEX idx_org_members_org_id ON organization_members(organization_id);
CREATE INDEX idx_org_members_user_id ON organization_members(user_id);
CREATE INDEX idx_org_members_role ON organization_members(organization_id, role);

-- 2. Organization Audit Logs
CREATE TABLE org_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizers(id) ON DELETE CASCADE,
    actor_id UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    target_type VARCHAR(50),
    target_id UUID,
    metadata JSONB DEFAULT '{}',
    ip_address VARCHAR(45),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_org_audit_org_id ON org_audit_logs(organization_id);
CREATE INDEX idx_org_audit_created ON org_audit_logs(organization_id, created_at DESC);
CREATE INDEX idx_org_audit_action ON org_audit_logs(action);

-- 3. Extend organizers table
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS trust_level VARCHAR(20) NOT NULL DEFAULT 'basic'
    CHECK (trust_level IN ('basic', 'verified', 'trusted'));
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS profile_completion_score INTEGER NOT NULL DEFAULT 0;
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS contact_email VARCHAR(255);

-- 4. Add attended flag to event_registrations (if not already present)
ALTER TABLE event_registrations ADD COLUMN IF NOT EXISTS attended BOOLEAN NOT NULL DEFAULT false;

-- 5. Add gender/age restriction columns to events
ALTER TABLE events ADD COLUMN IF NOT EXISTS gender_restriction VARCHAR(20);
ALTER TABLE events ADD COLUMN IF NOT EXISTS age_min INTEGER;
ALTER TABLE events ADD COLUMN IF NOT EXISTS age_max INTEGER;

-- 6. Backfill: auto-create owner membership for every existing organizer
INSERT INTO organization_members (id, organization_id, user_id, role, joined_at)
SELECT gen_random_uuid(), o.id, o.user_id, 'owner', o.created_at
FROM organizers o
WHERE o.user_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM organization_members om
    WHERE om.organization_id = o.id AND om.user_id = o.user_id
  );

-- Migration 009: Smart Islamic Event Map Geo Architecture
-- Adds normalized geo fields, spatial indexes, geo request logs, contextual places, and analytics metrics.

CREATE EXTENSION IF NOT EXISTS postgis;

-- 1) Event schema upgrades for geo discovery and recommendation filters
ALTER TABLE events
    ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizers(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS category VARCHAR(100),
    ADD COLUMN IF NOT EXISTS starts_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS ends_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS min_age INTEGER,
    ADD COLUMN IF NOT EXISTS max_age INTEGER,
    ADD COLUMN IF NOT EXISTS price_cents INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS location_point GEOGRAPHY(POINT, 4326),
    ADD COLUMN IF NOT EXISTS location_geometry GEOMETRY(POINT, 4326);

-- Backfill normalized fields from legacy columns
UPDATE events
SET
    organization_id = COALESCE(organization_id, organizer_id),
    category = COALESCE(category, event_type),
    starts_at = COALESCE(starts_at, start_date),
    ends_at = COALESCE(ends_at, end_date),
    min_age = COALESCE(min_age, age_min),
    max_age = COALESCE(max_age, age_max)
WHERE
    organization_id IS NULL
    OR category IS NULL
    OR starts_at IS NULL
    OR min_age IS NULL
    OR max_age IS NULL;

-- Backfill geo point if missing
UPDATE events
SET
    location_point = COALESCE(
        location_point,
        location,
        CASE
            WHEN latitude IS NOT NULL AND longitude IS NOT NULL
                THEN ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
            ELSE NULL
        END
    ),
    location_geometry = COALESCE(
        location_geometry,
        CASE
            WHEN location IS NOT NULL THEN location::geometry
            WHEN location_point IS NOT NULL THEN location_point::geometry
            WHEN latitude IS NOT NULL AND longitude IS NOT NULL
                THEN ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
            ELSE NULL
        END
    )
WHERE location_point IS NULL OR location_geometry IS NULL;

-- Keep legacy and normalized columns synchronized on write
CREATE OR REPLACE FUNCTION sync_event_geo_fields()
RETURNS TRIGGER AS $$
BEGIN
    NEW.organization_id := COALESCE(NEW.organization_id, NEW.organizer_id);
    NEW.category := COALESCE(NEW.category, NEW.event_type);
    NEW.event_type := COALESCE(NEW.event_type, NEW.category);

    NEW.starts_at := COALESCE(NEW.starts_at, NEW.start_date);
    NEW.start_date := COALESCE(NEW.start_date, NEW.starts_at);

    NEW.ends_at := COALESCE(NEW.ends_at, NEW.end_date);
    NEW.end_date := COALESCE(NEW.end_date, NEW.ends_at);

    NEW.min_age := COALESCE(NEW.min_age, NEW.age_min);
    NEW.age_min := COALESCE(NEW.age_min, NEW.min_age);

    NEW.max_age := COALESCE(NEW.max_age, NEW.age_max);
    NEW.age_max := COALESCE(NEW.age_max, NEW.max_age);

    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.location_point := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
        NEW.location := NEW.location_point;
        NEW.location_geometry := NEW.location_point::geometry;
    ELSIF NEW.location_point IS NOT NULL THEN
        NEW.location := NEW.location_point;
        NEW.location_geometry := NEW.location_point::geometry;
        NEW.longitude := ST_X(NEW.location_geometry);
        NEW.latitude := ST_Y(NEW.location_geometry);
    ELSIF NEW.location IS NOT NULL THEN
        NEW.location_point := NEW.location;
        NEW.location_geometry := NEW.location::geometry;
        NEW.longitude := ST_X(NEW.location::geometry);
        NEW.latitude := ST_Y(NEW.location::geometry);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_sync_event_geo_fields ON events;
CREATE TRIGGER trigger_sync_event_geo_fields
    BEFORE INSERT OR UPDATE ON events
    FOR EACH ROW
    EXECUTE FUNCTION sync_event_geo_fields();

-- Required spatial index
CREATE INDEX IF NOT EXISTS idx_events_location
ON events
USING GIST (location_point);

-- Additional geo/filter indexes for high-traffic map queries
CREATE INDEX IF NOT EXISTS idx_events_geo_status_starts
    ON events(status, starts_at)
    WHERE status = 'approved';

CREATE INDEX IF NOT EXISTS idx_events_geo_category_starts
    ON events(category, starts_at)
    WHERE status = 'approved';

CREATE INDEX IF NOT EXISTS idx_events_geo_gender
    ON events(gender_restriction)
    WHERE status = 'approved';

CREATE INDEX IF NOT EXISTS idx_events_geo_price_free
    ON events(price_cents)
    WHERE status = 'approved' AND price_cents = 0;

CREATE INDEX IF NOT EXISTS idx_events_geo_capacity
    ON events(capacity, reserved_count)
    WHERE status = 'approved' AND capacity IS NOT NULL;

-- 2) Suspicious geo-spam logging and geo request auditing
CREATE TABLE IF NOT EXISTS geo_request_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    ip_address INET,
    endpoint VARCHAR(120) NOT NULL,
    query_hash VARCHAR(64) NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    radius_km DOUBLE PRECISION,
    bbox JSONB DEFAULT '{}',
    filters JSONB DEFAULT '{}',
    is_flagged BOOLEAN NOT NULL DEFAULT false,
    flag_reason VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_geo_request_logs_created_at
    ON geo_request_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_geo_request_logs_query_hash
    ON geo_request_logs(query_hash);
CREATE INDEX IF NOT EXISTS idx_geo_request_logs_flagged
    ON geo_request_logs(is_flagged, created_at DESC)
    WHERE is_flagged = true;

-- 3) Contextual Islamic map layer entities
CREATE TABLE IF NOT EXISTS islamic_places (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    place_type VARCHAR(40) NOT NULL CHECK (place_type IN ('mosque', 'islamic_center', 'halal_restaurant')),
    address TEXT,
    city VARCHAR(120),
    country VARCHAR(120),
    location_point GEOGRAPHY(POINT, 4326) NOT NULL,
    verified BOOLEAN NOT NULL DEFAULT false,
    source VARCHAR(80),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_islamic_places_location
    ON islamic_places
    USING GIST (location_point);

CREATE INDEX IF NOT EXISTS idx_islamic_places_type
    ON islamic_places(place_type);

DROP TRIGGER IF EXISTS trigger_islamic_places_updated_at ON islamic_places;
CREATE TRIGGER trigger_islamic_places_updated_at
    BEFORE UPDATE ON islamic_places
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 4) Anonymous geo interaction metrics
CREATE TABLE IF NOT EXISTS geo_interaction_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(50) NOT NULL CHECK (
        event_type IN (
            'map_open',
            'marker_tap',
            'filter_use',
            'reservation_from_map',
            'distance_distribution'
        )
    ),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    session_hash VARCHAR(64) NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance_km DOUBLE PRECISION,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_geo_metrics_event_time
    ON geo_interaction_metrics(event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_geo_metrics_session
    ON geo_interaction_metrics(session_hash, created_at DESC);

ANALYZE events;
ANALYZE geo_request_logs;
ANALYZE islamic_places;
ANALYZE geo_interaction_metrics;

-- Migration 010: Email Verification on Registration
-- Adds is_verified flag, verification_code (6-digit), and expiration for email verification flow

-- 1. Add email verification columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_code VARCHAR(6);
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_expires_at TIMESTAMP WITH TIME ZONE;

-- 2. Backfill: mark existing verified users as is_verified = true
UPDATE users SET is_verified = TRUE WHERE verified_at IS NOT NULL;

-- 3. Index for code lookups
CREATE INDEX IF NOT EXISTS idx_users_verification_code ON users(verification_code);
CREATE INDEX IF NOT EXISTS idx_users_is_verified ON users(is_verified);

-- Migration 011: Email verification records table + status compatibility
-- Keeps existing verification columns for backward compatibility.

CREATE TABLE IF NOT EXISTS email_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    otp_hash VARCHAR(64) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    last_sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_email_verifications_user_id
    ON email_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_email_verifications_expires_at
    ON email_verifications(expires_at);

-- Allow pending_verification status used by auth + registration flows.
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_status_check;
ALTER TABLE users ADD CONSTRAINT users_status_check
    CHECK (status IN ('pending', 'pending_verification', 'active', 'suspended', 'deactivated'));

ALTER TABLE users ALTER COLUMN status SET DEFAULT 'pending_verification';


-- ============================================================================
-- Migration 012: Role-Based Access Control (RBAC) System
-- ============================================================================

-- â”€â”€ RBAC Core Tables â”€â”€

CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE user_roles (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    PRIMARY KEY (user_id, role_id)
);

-- â”€â”€ Indexes â”€â”€

CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_roles_role_id ON user_roles(role_id);
CREATE INDEX idx_role_permissions_role_id ON role_permissions(role_id);
CREATE INDEX idx_role_permissions_permission_id ON role_permissions(permission_id);

-- â”€â”€ Seed Roles â”€â”€

INSERT INTO roles (name, description) VALUES
    ('user', 'Standard platform user'),
    ('organizer', 'Event organizer with creation privileges'),
    ('admin', 'Platform administrator'),
    ('super_admin', 'Super administrator with full system access');

-- â”€â”€ Seed Permissions â”€â”€

INSERT INTO permissions (name, description) VALUES
    ('create_event', 'Create new events'),
    ('edit_event', 'Edit existing events'),
    ('delete_event', 'Delete events'),
    ('approve_event', 'Approve pending events'),
    ('reject_event', 'Reject pending events'),
    ('manage_users', 'Manage user accounts and roles'),
    ('view_admin_dashboard', 'Access the admin dashboard');

-- â”€â”€ Map Permissions to Roles â”€â”€

-- organizer: create, edit, delete own events
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.name = 'organizer' AND p.name IN ('create_event', 'edit_event', 'delete_event');

-- admin: all event moderation + dashboard
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.name = 'admin' AND p.name IN (
    'create_event', 'edit_event', 'delete_event',
    'approve_event', 'reject_event',
    'view_admin_dashboard'
);

-- super_admin: everything
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.name = 'super_admin';

-- â”€â”€ Migrate Existing Users to user_roles â”€â”€

INSERT INTO user_roles (user_id, role_id, assigned_at)
SELECT u.id, r.id, u.created_at
FROM users u
JOIN roles r ON r.name = u.role
ON CONFLICT DO NOTHING;

-- â”€â”€ Event Moderation Columns â”€â”€

ALTER TABLE events
    ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP WITH TIME ZONE;

-- Expand event status CHECK to include needs_revision
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;
ALTER TABLE events ADD CONSTRAINT events_status_check
    CHECK (status IN ('draft', 'pending', 'approved', 'rejected', 'needs_revision', 'published'));

CREATE INDEX idx_events_reviewed_by ON events(reviewed_by);

-- â”€â”€ RBAC Audit Log â”€â”€

CREATE TABLE rbac_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL,
    target_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    role_name VARCHAR(50),
    permission_name VARCHAR(100),
    details JSONB,
    ip_address INET,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_rbac_audit_actor ON rbac_audit_log(actor_id);
CREATE INDEX idx_rbac_audit_target ON rbac_audit_log(target_user_id);
CREATE INDEX idx_rbac_audit_created ON rbac_audit_log(created_at);

ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;
ALTER TABLE events ADD CONSTRAINT events_status_check
    CHECK (status IN ('draft', 'pending', 'approved', 'rejected', 'needs_revision', 'published', 'under_review'));

CREATE TABLE IF NOT EXISTS moderation_scans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    scanned_text TEXT NOT NULL,
    ai_risk_score DOUBLE PRECISION NOT NULL DEFAULT 0,
    ai_decision VARCHAR(30) NOT NULL DEFAULT 'safe'
        CHECK (ai_decision IN ('safe', 'review_required', 'high_risk')),
    detected_flags JSONB NOT NULL DEFAULT '{}',
    compliance_flags JSONB NOT NULL DEFAULT '{}',
    scanned_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    provider VARCHAR(50) NOT NULL DEFAULT 'local',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_moderation_scans_event_id ON moderation_scans(event_id);
CREATE INDEX idx_moderation_scans_ai_decision ON moderation_scans(ai_decision);
CREATE INDEX idx_moderation_scans_risk_score ON moderation_scans(ai_risk_score DESC);
CREATE INDEX idx_moderation_scans_scanned_at ON moderation_scans(scanned_at DESC);

CREATE TABLE IF NOT EXISTS organizer_trust_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organizer_id UUID NOT NULL REFERENCES organizers(id) ON DELETE CASCADE,
    trust_score DOUBLE PRECISION NOT NULL DEFAULT 75,
    violations_count INT NOT NULL DEFAULT 0,
    approved_events_count INT NOT NULL DEFAULT 0,
    rejected_events_count INT NOT NULL DEFAULT 0,
    high_risk_count INT NOT NULL DEFAULT 0,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id),
    UNIQUE(organizer_id)
);

CREATE INDEX idx_organizer_trust_scores_user_id ON organizer_trust_scores(user_id);
CREATE INDEX idx_organizer_trust_scores_organizer_id ON organizer_trust_scores(organizer_id);
CREATE INDEX idx_organizer_trust_scores_score ON organizer_trust_scores(trust_score);

CREATE TABLE IF NOT EXISTS abuse_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action_type VARCHAR(100) NOT NULL,
    risk_score DOUBLE PRECISION NOT NULL DEFAULT 0,
    details JSONB,
    ip_address INET,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_abuse_logs_user_id ON abuse_logs(user_id);
CREATE INDEX idx_abuse_logs_action_type ON abuse_logs(action_type);
CREATE INDEX idx_abuse_logs_created_at ON abuse_logs(created_at DESC);
CREATE INDEX idx_abuse_logs_user_created ON abuse_logs(user_id, created_at DESC);

ALTER TABLE events ADD COLUMN IF NOT EXISTS ai_risk_score DOUBLE PRECISION;
ALTER TABLE events ADD COLUMN IF NOT EXISTS ai_decision VARCHAR(30);
ALTER TABLE events ADD COLUMN IF NOT EXISTS compliance_flags JSONB;
ALTER TABLE events ADD COLUMN IF NOT EXISTS meeting_link_encrypted TEXT;

-- Migration 014: Spiritual quotes for Quran/Hadith surfaces

CREATE TABLE IF NOT EXISTS spiritual_quotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(16) NOT NULL CHECK (type IN ('quran', 'hadith')),
    text_ar TEXT NOT NULL,
    source VARCHAR(255) NOT NULL,
    reference VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    show_on_dashboard BOOLEAN NOT NULL DEFAULT FALSE,
    show_on_home BOOLEAN NOT NULL DEFAULT FALSE,
    show_on_login BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_spiritual_quotes_active
    ON spiritual_quotes(is_active)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_spiritual_quotes_dashboard
    ON spiritual_quotes(show_on_dashboard)
    WHERE show_on_dashboard = TRUE;

CREATE INDEX IF NOT EXISTS idx_spiritual_quotes_home
    ON spiritual_quotes(show_on_home)
    WHERE show_on_home = TRUE;

CREATE INDEX IF NOT EXISTS idx_spiritual_quotes_login
    ON spiritual_quotes(show_on_login)
    WHERE show_on_login = TRUE;

INSERT INTO spiritual_quotes (
    type,
    text_ar,
    source,
    reference,
    is_active,
    show_on_dashboard,
    show_on_home,
    show_on_login
)
SELECT
    seed.type,
    seed.text_ar,
    seed.source,
    seed.reference,
    seed.is_active,
    seed.show_on_dashboard,
    seed.show_on_home,
    seed.show_on_login
FROM (
    VALUES
        ('quran', 'ÙÙŽØ¥ÙÙ†Ù‘ÙŽ Ù…ÙŽØ¹ÙŽ Ø§Ù„Ù’Ø¹ÙØ³Ù’Ø±Ù ÙŠÙØ³Ù’Ø±Ù‹Ø§', 'Ø³ÙˆØ±Ø© Ø§Ù„Ø´Ø±Ø­', '94:6', TRUE, TRUE, TRUE, TRUE),
        ('quran', 'ÙŠÙŽØ§ Ø£ÙŽÙŠÙ‘ÙÙ‡ÙŽØ§ Ø§Ù„Ù†Ù‘ÙŽØ§Ø³Ù Ø¥ÙÙ†Ù‘ÙŽØ§ Ø®ÙŽÙ„ÙŽÙ‚Ù’Ù†ÙŽØ§ÙƒÙÙ… Ù…Ù‘ÙÙ† Ø°ÙŽÙƒÙŽØ±Ù ÙˆÙŽØ£ÙÙ†Ø«ÙŽÙ‰Ù° ÙˆÙŽØ¬ÙŽØ¹ÙŽÙ„Ù’Ù†ÙŽØ§ÙƒÙÙ…Ù’ Ø´ÙØ¹ÙÙˆØ¨Ù‹Ø§ ÙˆÙŽÙ‚ÙŽØ¨ÙŽØ§Ø¦ÙÙ„ÙŽ Ù„ÙØªÙŽØ¹ÙŽØ§Ø±ÙŽÙÙÙˆØ§', 'Ø³ÙˆØ±Ø© Ø§Ù„Ø­Ø¬Ø±Ø§Øª', '49:13', TRUE, TRUE, TRUE, FALSE),
        ('hadith', 'Ø¥ÙÙ†Ù‘ÙŽÙ…ÙŽØ§ Ø§Ù„Ø£ÙŽØ¹Ù’Ù…ÙŽØ§Ù„Ù Ø¨ÙØ§Ù„Ù†Ù‘ÙÙŠÙ‘ÙŽØ§ØªÙ', 'ØµØ­ÙŠØ­ Ø§Ù„Ø¨Ø®Ø§Ø±ÙŠ', '1', TRUE, TRUE, FALSE, TRUE),
        ('hadith', 'Ù…ÙŽÙ†Ù’ Ù„ÙŽØ§ ÙŠÙŽØ±Ù’Ø­ÙŽÙ…Ù’ Ù„ÙŽØ§ ÙŠÙØ±Ù’Ø­ÙŽÙ…Ù’', 'ØµØ­ÙŠØ­ Ø§Ù„Ø¨Ø®Ø§Ø±ÙŠ', '7376', TRUE, FALSE, TRUE, FALSE)
) AS seed(type, text_ar, source, reference, is_active, show_on_dashboard, show_on_home, show_on_login)
WHERE NOT EXISTS (
    SELECT 1 FROM spiritual_quotes
);

DO $$
BEGIN
    IF current_setting('server_encoding') <> 'UTF8' THEN
        RAISE EXCEPTION 'Database encoding must be UTF8, got %', current_setting('server_encoding');
    END IF;
END
$$;

-- Migration 016: Platform Infrastructure Upgrade
-- Countries database, user goals, verification requests, geo-architecture

-- ============================================
-- 1. Countries Reference Table
-- ============================================
CREATE TABLE IF NOT EXISTS countries (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    iso_code CHAR(2) NOT NULL UNIQUE,
    iso3_code CHAR(3),
    phone_code VARCHAR(10) NOT NULL,
    flag_emoji VARCHAR(10) NOT NULL DEFAULT '',
    region VARCHAR(50) NOT NULL DEFAULT 'Other',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_countries_iso ON countries(iso_code);
CREATE INDEX IF NOT EXISTS idx_countries_region ON countries(region);
CREATE INDEX IF NOT EXISTS idx_countries_active ON countries(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_countries_name ON countries(name);

-- ============================================
-- 2. Add country_id + timezone to profiles
-- ============================================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS country_id INTEGER REFERENCES countries(id);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS timezone VARCHAR(50);

-- Add verification_status to users (distinct from email verified_at)
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_status VARCHAR(50) DEFAULT 'none'
    CHECK (verification_status IN ('none', 'pending_review', 'verified', 'rejected'));

-- ============================================
-- 3. User Goals Table
-- ============================================
CREATE TABLE IF NOT EXISTS user_goals (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    goal_key VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, goal_key)
);

CREATE INDEX IF NOT EXISTS idx_user_goals_user ON user_goals(user_id);

-- ============================================
-- 4. Verification Requests Table
-- ============================================
CREATE TABLE IF NOT EXISTS verification_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    profile_image_path VARCHAR(500),
    document_path VARCHAR(500),
    document_type VARCHAR(50) DEFAULT 'general',
    notes TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'pending_review'
        CHECK (status IN ('pending_review', 'approved', 'rejected', 'more_info_needed')),
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    review_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_verification_user ON verification_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_verification_status ON verification_requests(status);

CREATE TRIGGER trigger_verification_requests_updated_at
    BEFORE UPDATE ON verification_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 5. Add organizer-specific fields
-- ============================================
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS established_year INTEGER;
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS attendance_estimate INTEGER;
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS official_email VARCHAR(255);

-- ============================================
-- 6. Seed Countries (195 countries)
-- ============================================
INSERT INTO countries (name, iso_code, iso3_code, phone_code, flag_emoji, region) VALUES
-- Middle East & North Africa
('Saudi Arabia', 'SA', 'SAU', '+966', 'ðŸ‡¸ðŸ‡¦', 'Middle East'),
('United Arab Emirates', 'AE', 'ARE', '+971', 'ðŸ‡¦ðŸ‡ª', 'Middle East'),
('Qatar', 'QA', 'QAT', '+974', 'ðŸ‡¶ðŸ‡¦', 'Middle East'),
('Kuwait', 'KW', 'KWT', '+965', 'ðŸ‡°ðŸ‡¼', 'Middle East'),
('Bahrain', 'BH', 'BHR', '+973', 'ðŸ‡§ðŸ‡­', 'Middle East'),
('Oman', 'OM', 'OMN', '+968', 'ðŸ‡´ðŸ‡²', 'Middle East'),
('Yemen', 'YE', 'YEM', '+967', 'ðŸ‡¾ðŸ‡ª', 'Middle East'),
('Iraq', 'IQ', 'IRQ', '+964', 'ðŸ‡®ðŸ‡¶', 'Middle East'),
('Jordan', 'JO', 'JOR', '+962', 'ðŸ‡¯ðŸ‡´', 'Middle East'),
('Lebanon', 'LB', 'LBN', '+961', 'ðŸ‡±ðŸ‡§', 'Middle East'),
('Palestine', 'PS', 'PSE', '+970', 'ðŸ‡µðŸ‡¸', 'Middle East'),
('Syria', 'SY', 'SYR', '+963', 'ðŸ‡¸ðŸ‡¾', 'Middle East'),
('Iran', 'IR', 'IRN', '+98', 'ðŸ‡®ðŸ‡·', 'Middle East'),
('Turkey', 'TR', 'TUR', '+90', 'ðŸ‡¹ðŸ‡·', 'Middle East'),
('Egypt', 'EG', 'EGY', '+20', 'ðŸ‡ªðŸ‡¬', 'North Africa'),
('Libya', 'LY', 'LBY', '+218', 'ðŸ‡±ðŸ‡¾', 'North Africa'),
('Tunisia', 'TN', 'TUN', '+216', 'ðŸ‡¹ðŸ‡³', 'North Africa'),
('Algeria', 'DZ', 'DZA', '+213', 'ðŸ‡©ðŸ‡¿', 'North Africa'),
('Morocco', 'MA', 'MAR', '+212', 'ðŸ‡²ðŸ‡¦', 'North Africa'),
('Sudan', 'SD', 'SDN', '+249', 'ðŸ‡¸ðŸ‡©', 'North Africa'),
('Mauritania', 'MR', 'MRT', '+222', 'ðŸ‡²ðŸ‡·', 'North Africa'),
-- South & Central Asia
('Pakistan', 'PK', 'PAK', '+92', 'ðŸ‡µðŸ‡°', 'South Asia'),
('India', 'IN', 'IND', '+91', 'ðŸ‡®ðŸ‡³', 'South Asia'),
('Bangladesh', 'BD', 'BGD', '+880', 'ðŸ‡§ðŸ‡©', 'South Asia'),
('Afghanistan', 'AF', 'AFG', '+93', 'ðŸ‡¦ðŸ‡«', 'South Asia'),
('Sri Lanka', 'LK', 'LKA', '+94', 'ðŸ‡±ðŸ‡°', 'South Asia'),
('Nepal', 'NP', 'NPL', '+977', 'ðŸ‡³ðŸ‡µ', 'South Asia'),
('Maldives', 'MV', 'MDV', '+960', 'ðŸ‡²ðŸ‡»', 'South Asia'),
-- Southeast Asia
('Indonesia', 'ID', 'IDN', '+62', 'ðŸ‡®ðŸ‡©', 'Southeast Asia'),
('Malaysia', 'MY', 'MYS', '+60', 'ðŸ‡²ðŸ‡¾', 'Southeast Asia'),
('Brunei', 'BN', 'BRN', '+673', 'ðŸ‡§ðŸ‡³', 'Southeast Asia'),
('Philippines', 'PH', 'PHL', '+63', 'ðŸ‡µðŸ‡­', 'Southeast Asia'),
('Thailand', 'TH', 'THA', '+66', 'ðŸ‡¹ðŸ‡­', 'Southeast Asia'),
('Singapore', 'SG', 'SGP', '+65', 'ðŸ‡¸ðŸ‡¬', 'Southeast Asia'),
('Myanmar', 'MM', 'MMR', '+95', 'ðŸ‡²ðŸ‡²', 'Southeast Asia'),
('Vietnam', 'VN', 'VNM', '+84', 'ðŸ‡»ðŸ‡³', 'Southeast Asia'),
('Cambodia', 'KH', 'KHM', '+855', 'ðŸ‡°ðŸ‡­', 'Southeast Asia'),
-- Central Asia
('Uzbekistan', 'UZ', 'UZB', '+998', 'ðŸ‡ºðŸ‡¿', 'Central Asia'),
('Kazakhstan', 'KZ', 'KAZ', '+7', 'ðŸ‡°ðŸ‡¿', 'Central Asia'),
('Tajikistan', 'TJ', 'TJK', '+992', 'ðŸ‡¹ðŸ‡¯', 'Central Asia'),
('Kyrgyzstan', 'KG', 'KGZ', '+996', 'ðŸ‡°ðŸ‡¬', 'Central Asia'),
('Turkmenistan', 'TM', 'TKM', '+993', 'ðŸ‡¹ðŸ‡²', 'Central Asia'),
('Azerbaijan', 'AZ', 'AZE', '+994', 'ðŸ‡¦ðŸ‡¿', 'Central Asia'),
-- Sub-Saharan Africa
('Nigeria', 'NG', 'NGA', '+234', 'ðŸ‡³ðŸ‡¬', 'West Africa'),
('Senegal', 'SN', 'SEN', '+221', 'ðŸ‡¸ðŸ‡³', 'West Africa'),
('Mali', 'ML', 'MLI', '+223', 'ðŸ‡²ðŸ‡±', 'West Africa'),
('Guinea', 'GN', 'GIN', '+224', 'ðŸ‡¬ðŸ‡³', 'West Africa'),
('Gambia', 'GM', 'GMB', '+220', 'ðŸ‡¬ðŸ‡²', 'West Africa'),
('Sierra Leone', 'SL', 'SLE', '+232', 'ðŸ‡¸ðŸ‡±', 'West Africa'),
('Niger', 'NE', 'NER', '+227', 'ðŸ‡³ðŸ‡ª', 'West Africa'),
('Burkina Faso', 'BF', 'BFA', '+226', 'ðŸ‡§ðŸ‡«', 'West Africa'),
('Ghana', 'GH', 'GHA', '+233', 'ðŸ‡¬ðŸ‡­', 'West Africa'),
('Ivory Coast', 'CI', 'CIV', '+225', 'ðŸ‡¨ðŸ‡®', 'West Africa'),
('Somalia', 'SO', 'SOM', '+252', 'ðŸ‡¸ðŸ‡´', 'East Africa'),
('Ethiopia', 'ET', 'ETH', '+251', 'ðŸ‡ªðŸ‡¹', 'East Africa'),
('Kenya', 'KE', 'KEN', '+254', 'ðŸ‡°ðŸ‡ª', 'East Africa'),
('Tanzania', 'TZ', 'TZA', '+255', 'ðŸ‡¹ðŸ‡¿', 'East Africa'),
('Uganda', 'UG', 'UGA', '+256', 'ðŸ‡ºðŸ‡¬', 'East Africa'),
('Mozambique', 'MZ', 'MOZ', '+258', 'ðŸ‡²ðŸ‡¿', 'East Africa'),
('Djibouti', 'DJ', 'DJI', '+253', 'ðŸ‡©ðŸ‡¯', 'East Africa'),
('Comoros', 'KM', 'COM', '+269', 'ðŸ‡°ðŸ‡²', 'East Africa'),
('Eritrea', 'ER', 'ERI', '+291', 'ðŸ‡ªðŸ‡·', 'East Africa'),
('Chad', 'TD', 'TCD', '+235', 'ðŸ‡¹ðŸ‡©', 'Central Africa'),
('Cameroon', 'CM', 'CMR', '+237', 'ðŸ‡¨ðŸ‡²', 'Central Africa'),
('South Africa', 'ZA', 'ZAF', '+27', 'ðŸ‡¿ðŸ‡¦', 'Southern Africa'),
-- Europe
('United Kingdom', 'GB', 'GBR', '+44', 'ðŸ‡¬ðŸ‡§', 'Europe'),
('France', 'FR', 'FRA', '+33', 'ðŸ‡«ðŸ‡·', 'Europe'),
('Germany', 'DE', 'DEU', '+49', 'ðŸ‡©ðŸ‡ª', 'Europe'),
('Netherlands', 'NL', 'NLD', '+31', 'ðŸ‡³ðŸ‡±', 'Europe'),
('Belgium', 'BE', 'BEL', '+32', 'ðŸ‡§ðŸ‡ª', 'Europe'),
('Sweden', 'SE', 'SWE', '+46', 'ðŸ‡¸ðŸ‡ª', 'Europe'),
('Norway', 'NO', 'NOR', '+47', 'ðŸ‡³ðŸ‡´', 'Europe'),
('Denmark', 'DK', 'DNK', '+45', 'ðŸ‡©ðŸ‡°', 'Europe'),
('Finland', 'FI', 'FIN', '+358', 'ðŸ‡«ðŸ‡®', 'Europe'),
('Austria', 'AT', 'AUT', '+43', 'ðŸ‡¦ðŸ‡¹', 'Europe'),
('Switzerland', 'CH', 'CHE', '+41', 'ðŸ‡¨ðŸ‡­', 'Europe'),
('Italy', 'IT', 'ITA', '+39', 'ðŸ‡®ðŸ‡¹', 'Europe'),
('Spain', 'ES', 'ESP', '+34', 'ðŸ‡ªðŸ‡¸', 'Europe'),
('Portugal', 'PT', 'PRT', '+351', 'ðŸ‡µðŸ‡¹', 'Europe'),
('Greece', 'GR', 'GRC', '+30', 'ðŸ‡¬ðŸ‡·', 'Europe'),
('Poland', 'PL', 'POL', '+48', 'ðŸ‡µðŸ‡±', 'Europe'),
('Romania', 'RO', 'ROU', '+40', 'ðŸ‡·ðŸ‡´', 'Europe'),
('Bulgaria', 'BG', 'BGR', '+359', 'ðŸ‡§ðŸ‡¬', 'Europe'),
('Ireland', 'IE', 'IRL', '+353', 'ðŸ‡®ðŸ‡ª', 'Europe'),
('Bosnia and Herzegovina', 'BA', 'BIH', '+387', 'ðŸ‡§ðŸ‡¦', 'Europe'),
('Albania', 'AL', 'ALB', '+355', 'ðŸ‡¦ðŸ‡±', 'Europe'),
('Kosovo', 'XK', 'XKX', '+383', 'ðŸ‡½ðŸ‡°', 'Europe'),
('Russia', 'RU', 'RUS', '+7', 'ðŸ‡·ðŸ‡º', 'Europe'),
('Ukraine', 'UA', 'UKR', '+380', 'ðŸ‡ºðŸ‡¦', 'Europe'),
('Czech Republic', 'CZ', 'CZE', '+420', 'ðŸ‡¨ðŸ‡¿', 'Europe'),
('Hungary', 'HU', 'HUN', '+36', 'ðŸ‡­ðŸ‡º', 'Europe'),
-- Americas
('United States', 'US', 'USA', '+1', 'ðŸ‡ºðŸ‡¸', 'North America'),
('Canada', 'CA', 'CAN', '+1', 'ðŸ‡¨ðŸ‡¦', 'North America'),
('Mexico', 'MX', 'MEX', '+52', 'ðŸ‡²ðŸ‡½', 'North America'),
('Brazil', 'BR', 'BRA', '+55', 'ðŸ‡§ðŸ‡·', 'South America'),
('Argentina', 'AR', 'ARG', '+54', 'ðŸ‡¦ðŸ‡·', 'South America'),
('Colombia', 'CO', 'COL', '+57', 'ðŸ‡¨ðŸ‡´', 'South America'),
('Chile', 'CL', 'CHL', '+56', 'ðŸ‡¨ðŸ‡±', 'South America'),
('Peru', 'PE', 'PER', '+51', 'ðŸ‡µðŸ‡ª', 'South America'),
('Venezuela', 'VE', 'VEN', '+58', 'ðŸ‡»ðŸ‡ª', 'South America'),
('Trinidad and Tobago', 'TT', 'TTO', '+1', 'ðŸ‡¹ðŸ‡¹', 'Caribbean'),
('Guyana', 'GY', 'GUY', '+592', 'ðŸ‡¬ðŸ‡¾', 'South America'),
('Suriname', 'SR', 'SUR', '+597', 'ðŸ‡¸ðŸ‡·', 'South America'),
-- Oceania
('Australia', 'AU', 'AUS', '+61', 'ðŸ‡¦ðŸ‡º', 'Oceania'),
('New Zealand', 'NZ', 'NZL', '+64', 'ðŸ‡³ðŸ‡¿', 'Oceania'),
('Fiji', 'FJ', 'FJI', '+679', 'ðŸ‡«ðŸ‡¯', 'Oceania'),
-- East Asia
('China', 'CN', 'CHN', '+86', 'ðŸ‡¨ðŸ‡³', 'East Asia'),
('Japan', 'JP', 'JPN', '+81', 'ðŸ‡¯ðŸ‡µ', 'East Asia'),
('South Korea', 'KR', 'KOR', '+82', 'ðŸ‡°ðŸ‡·', 'East Asia'),
('Taiwan', 'TW', 'TWN', '+886', 'ðŸ‡¹ðŸ‡¼', 'East Asia'),
('Hong Kong', 'HK', 'HKG', '+852', 'ðŸ‡­ðŸ‡°', 'East Asia')
ON CONFLICT (iso_code) DO NOTHING;

-- Migration 017: Auth & Compliance Hardening
-- Adds refresh tokens table and user suspension support

-- Refresh tokens for JWT renewal
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMP,
    replaced_by UUID REFERENCES refresh_tokens(id),
    user_agent TEXT,
    ip_address VARCHAR(45)
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_token_hash ON refresh_tokens(token_hash);
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);

-- Add suspension fields to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_at TIMESTAMP;
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_reason TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_by UUID REFERENCES users(id);
ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP;

-- Index for finding suspended users
CREATE INDEX IF NOT EXISTS idx_users_suspended ON users(suspended_at) WHERE suspended_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_deleted ON users(deleted_at) WHERE deleted_at IS NOT NULL;

-- Migration 018: Badge System & Anti-Fraud
-- Adds organizer badge tracking and event validation rules

-- Badge system for organizers
CREATE TABLE IF NOT EXISTS organizer_badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id UUID NOT NULL REFERENCES organizers(id) ON DELETE CASCADE,
    badge_type VARCHAR(50) NOT NULL,  -- 'verified', 'trusted', 'premium', 'scholar'
    awarded_at TIMESTAMP NOT NULL DEFAULT NOW(),
    awarded_by UUID REFERENCES users(id),
    expires_at TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT true,
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_badges_organizer ON organizer_badges(organizer_id);
CREATE INDEX idx_badges_type ON organizer_badges(badge_type);

-- Add badge display field to organizers
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS verification_badge VARCHAR(50) DEFAULT 'none';
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP;
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS total_events_hosted INT DEFAULT 0;
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS total_attendees INT DEFAULT 0;
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS avg_rating NUMERIC(3,2) DEFAULT 0;

-- Anti-fraud: event validation audit
CREATE TABLE IF NOT EXISTS event_validation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    check_type VARCHAR(50) NOT NULL,  -- 'duplicate_title', 'suspicious_date', 'missing_details', 'spam_content'
    check_result VARCHAR(20) NOT NULL, -- 'pass', 'warn', 'fail'
    details TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_validation_event ON event_validation_logs(event_id);

-- Payment system tables (preparation for Weeks 5-6)
CREATE TABLE IF NOT EXISTS payment_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id UUID NOT NULL UNIQUE REFERENCES organizers(id) ON DELETE CASCADE,
    stripe_account_id VARCHAR(255),
    stripe_onboarded BOOLEAN DEFAULT false,
    payout_enabled BOOLEAN DEFAULT false,
    commission_rate NUMERIC(5,4) DEFAULT 0.1000, -- 10% platform commission
    currency VARCHAR(3) DEFAULT 'USD',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'USD',
    quantity INT NOT NULL DEFAULT 0,
    sold_count INT NOT NULL DEFAULT 0,
    is_free BOOLEAN NOT NULL DEFAULT true,
    sale_start TIMESTAMP,
    sale_end TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tickets_event ON tickets(event_id);

CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    event_id UUID NOT NULL REFERENCES events(id),
    ticket_id UUID NOT NULL REFERENCES tickets(id),
    quantity INT NOT NULL DEFAULT 1,
    total_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    platform_fee NUMERIC(10,2) NOT NULL DEFAULT 0,
    organizer_payout NUMERIC(10,2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, completed, refunded, cancelled
    stripe_payment_intent_id VARCHAR(255),
    stripe_checkout_session_id VARCHAR(255),
    refund_id VARCHAR(255),
    refund_reason TEXT,
    refunded_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_orders_event ON orders(event_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_stripe ON orders(stripe_payment_intent_id);

CREATE TABLE IF NOT EXISTS payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id UUID NOT NULL REFERENCES organizers(id),
    amount NUMERIC(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, processing, completed, failed
    stripe_transfer_id VARCHAR(255),
    period_start TIMESTAMP NOT NULL,
    period_end TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP
);

CREATE INDEX idx_payouts_organizer ON payouts(organizer_id);
CREATE INDEX idx_payouts_status ON payouts(status);

-- Migration 019: Performance Optimization Indexes
-- Additional indexes for common query patterns

-- Event queries by status + date (admin dashboard, public listing)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_events_status_start ON events(status, start_date DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_events_organizer_status ON events(organizer_id, status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_events_country_status ON events(country, status) WHERE status = 'published';

-- Order queries by event (revenue dashboard)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_event_status ON orders(event_id, status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_created ON orders(created_at DESC);

-- Refresh token cleanup (expired token purge)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_refresh_tokens_cleanup ON refresh_tokens(expires_at) WHERE revoked_at IS NULL;

-- Organizer badge lookups
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_badges_active ON organizer_badges(organizer_id, badge_type) WHERE is_active = true;

-- Payout reporting
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payouts_period ON payouts(organizer_id, period_start, period_end);

-- Full-text search on event titles (for search API)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_events_title_trgm ON events USING gin(title gin_trgm_ops);

-- Partial index for upcoming published events (most common query)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_events_upcoming ON events(start_date)
    WHERE status = 'published' AND start_date > NOW();

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

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false;

-- Verify and promote hassanalwaqedi2@gmail.com as the platform owner ("Khair")
UPDATE users
SET is_verified = TRUE,
    verified_at = NOW(),
    status = 'active',
    role = 'admin',
    updated_at = NOW()
WHERE email = 'hassanalwaqedi2@gmail.com';

-- Clean up any pending verification records for this email
DELETE FROM email_verifications WHERE email = 'hassanalwaqedi2@gmail.com';

