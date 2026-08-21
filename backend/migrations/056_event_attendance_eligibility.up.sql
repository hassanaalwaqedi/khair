-- Stable, server-enforced attendance eligibility.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS gender_updated_at TIMESTAMP WITH TIME ZONE;

UPDATE users
SET gender = CASE LOWER(TRIM(gender))
    WHEN 'male' THEN 'MAN'
    WHEN 'man' THEN 'MAN'
    WHEN 'female' THEN 'WOMAN'
    WHEN 'woman' THEN 'WOMAN'
    ELSE NULL
END
WHERE gender IS NOT NULL;

ALTER TABLE events
    ADD COLUMN IF NOT EXISTS attendance_policy VARCHAR(20) NOT NULL DEFAULT 'EVERYONE';

UPDATE events
SET attendance_policy = CASE LOWER(COALESCE(gender_restriction, ''))
    WHEN 'female_only' THEN 'WOMEN_ONLY'
    WHEN 'women_only' THEN 'WOMEN_ONLY'
    WHEN 'male_only' THEN 'MEN_ONLY'
    WHEN 'men_only' THEN 'MEN_ONLY'
    ELSE 'EVERYONE'
END;

ALTER TABLE events DROP CONSTRAINT IF EXISTS events_attendance_policy_check;
ALTER TABLE events
    ADD CONSTRAINT events_attendance_policy_check
    CHECK (attendance_policy IN ('EVERYONE', 'WOMEN_ONLY', 'MEN_ONLY'));

ALTER TABLE event_registrations
    ADD COLUMN IF NOT EXISTS eligibility_review_required BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS eligibility_reviewed_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX IF NOT EXISTS idx_event_reg_eligibility_review
    ON event_registrations(event_id, eligibility_review_required)
    WHERE eligibility_review_required = true;
