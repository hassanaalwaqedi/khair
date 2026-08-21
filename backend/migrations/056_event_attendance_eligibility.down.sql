DROP INDEX IF EXISTS idx_event_reg_eligibility_review;
ALTER TABLE event_registrations
    DROP COLUMN IF EXISTS eligibility_reviewed_at,
    DROP COLUMN IF EXISTS eligibility_review_required;
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_attendance_policy_check;
ALTER TABLE events DROP COLUMN IF EXISTS attendance_policy;
ALTER TABLE users DROP COLUMN IF EXISTS gender_updated_at;
