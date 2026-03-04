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
