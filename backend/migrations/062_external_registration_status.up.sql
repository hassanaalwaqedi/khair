-- Track the attendee's progress through a third-party registration flow.
ALTER TABLE event_registrations
    ADD COLUMN IF NOT EXISTS external_registration_status TEXT NOT NULL DEFAULT 'not_required',
    ADD COLUMN IF NOT EXISTS external_registration_reminder_dismissed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS external_registration_link_opened_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS external_registration_self_reported_completed_at TIMESTAMPTZ;

ALTER TABLE event_registrations
    DROP CONSTRAINT IF EXISTS event_registrations_external_registration_status_check;
ALTER TABLE event_registrations
    ADD CONSTRAINT event_registrations_external_registration_status_check
    CHECK (external_registration_status IN (
        'not_required',
        'pending_external_registration',
        'external_link_opened',
        'self_reported_completed'
    ));

-- Existing registrations inherit the event's current registration mode.
UPDATE event_registrations er
SET external_registration_status = CASE
    WHEN e.registration_type IN ('external', 'both')
        THEN 'pending_external_registration'
    ELSE 'not_required'
END
FROM events e
WHERE e.id = er.event_id
  AND er.external_registration_status = 'not_required';

CREATE INDEX IF NOT EXISTS idx_event_reg_external_registration_status
    ON event_registrations(user_id, external_registration_status)
    WHERE external_registration_status <> 'not_required';
