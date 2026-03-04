-- Rollback migration 006: Multi-Role Registration System

-- Drop triggers
DROP TRIGGER IF EXISTS trigger_registration_drafts_updated_at ON registration_drafts;
DROP TRIGGER IF EXISTS trigger_sheikhs_updated_at ON sheikhs;
DROP TRIGGER IF EXISTS trigger_profiles_updated_at ON profiles;

-- Drop tables
DROP TABLE IF EXISTS registration_audit_log;
DROP TABLE IF EXISTS registration_drafts;
DROP TABLE IF EXISTS sheikhs;
DROP TABLE IF EXISTS profiles;

-- Remove added columns from organizers
ALTER TABLE organizers DROP COLUMN IF EXISTS registration_number;
ALTER TABLE organizers DROP COLUMN IF EXISTS organization_type;
ALTER TABLE organizers DROP COLUMN IF EXISTS city;
ALTER TABLE organizers DROP COLUMN IF EXISTS country;

-- Remove added columns from users
ALTER TABLE users DROP COLUMN IF EXISTS verification_expires;
ALTER TABLE users DROP COLUMN IF EXISTS verification_token;
ALTER TABLE users DROP COLUMN IF EXISTS verified_at;
ALTER TABLE users DROP COLUMN IF EXISTS display_name;
ALTER TABLE users DROP COLUMN IF EXISTS status;

-- Restore original role constraint
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('organizer', 'admin'));
