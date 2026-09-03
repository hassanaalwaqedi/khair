DROP INDEX IF EXISTS idx_event_reg_external_registration_status;
ALTER TABLE event_registrations
    DROP CONSTRAINT IF EXISTS event_registrations_external_registration_status_check;
ALTER TABLE event_registrations
    DROP COLUMN IF EXISTS external_registration_self_reported_completed_at,
    DROP COLUMN IF EXISTS external_registration_link_opened_at,
    DROP COLUMN IF EXISTS external_registration_reminder_dismissed_at,
    DROP COLUMN IF EXISTS external_registration_status;
