-- Reverse Migration 008: Organization Dashboard System

-- Remove event restriction columns
ALTER TABLE events DROP COLUMN IF EXISTS age_max;
ALTER TABLE events DROP COLUMN IF EXISTS age_min;
ALTER TABLE events DROP COLUMN IF EXISTS gender_restriction;

-- Remove attended flag
ALTER TABLE event_registrations DROP COLUMN IF EXISTS attended;

-- Remove organizer extensions
ALTER TABLE organizers DROP COLUMN IF EXISTS contact_email;
ALTER TABLE organizers DROP COLUMN IF EXISTS profile_completion_score;
ALTER TABLE organizers DROP COLUMN IF EXISTS trust_level;

-- Drop audit logs
DROP TABLE IF EXISTS org_audit_logs;

-- Drop organization members
DROP TABLE IF EXISTS organization_members;
