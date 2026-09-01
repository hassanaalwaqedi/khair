DROP TABLE IF EXISTS event_external_registration_clicks;
ALTER TABLE events
    DROP COLUMN IF EXISTS application_approval_required,
    DROP COLUMN IF EXISTS registration_requirements,
    DROP COLUMN IF EXISTS external_registration_instructions,
    DROP COLUMN IF EXISTS external_registration_url,
    DROP COLUMN IF EXISTS external_platform_name,
    DROP COLUMN IF EXISTS registration_type,
    DROP COLUMN IF EXISTS registration_required;
