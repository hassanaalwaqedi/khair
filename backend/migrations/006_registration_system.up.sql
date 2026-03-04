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
