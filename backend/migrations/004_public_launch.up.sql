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
