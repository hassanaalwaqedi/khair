-- 039: Khair event-only product cleanup. Never edit historical migrations.
-- Before applying in production, take a verified logical backup and review
-- legacy_sheikh_accounts_backup. See docs/event-only-migration.md.

CREATE TABLE IF NOT EXISTS legacy_sheikh_accounts_backup AS
SELECT u.*, s.specialization, s.ijazah_info, s.certifications,
       s.years_of_experience, s.verification_status AS legacy_verification_status
FROM users u JOIN sheikhs s ON s.user_id = u.id
WITH NO DATA;

INSERT INTO legacy_sheikh_accounts_backup
SELECT u.*, s.specialization, s.ijazah_info, s.certifications,
       s.years_of_experience, s.verification_status
FROM users u JOIN sheikhs s ON s.user_id = u.id
WHERE NOT EXISTS (SELECT 1 FROM legacy_sheikh_accounts_backup b WHERE b.id = u.id);

-- All legacy learner accounts become event attendees. Sheikh accounts are
-- converted only after their complete metadata was archived above; operators
-- must review the backup before running this migration in production.
UPDATE users SET role = 'user'
WHERE role IN ('member', 'student', 'new_muslim', 'sheikh');
UPDATE users SET role = 'organizer'
WHERE role IN ('organization', 'community_organizer')
  AND EXISTS (SELECT 1 FROM organizers o WHERE o.user_id = users.id);
UPDATE users SET role = 'user'
WHERE role IN ('organization', 'community_organizer');

ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('user', 'organizer', 'admin'));
UPDATE registration_drafts SET role = 'user' WHERE role IS NULL OR role <> 'user';

CREATE TABLE IF NOT EXISTS event_announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  organizer_user_id UUID NOT NULL REFERENCES users(id),
  message TEXT NOT NULL CHECK (char_length(trim(message)) > 0),
  include_link BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_event_announcements_event ON event_announcements(event_id, created_at DESC);

DROP TABLE IF EXISTS messages;
DROP TABLE IF EXISTS conversations;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS availability_rules;
DROP TABLE IF EXISTS booking_settings;
DROP TABLE IF EXISTS blocked_times;
DROP TABLE IF EXISTS sheikh_ratings;
DROP TABLE IF EXISTS sheikh_reviews;
DROP TABLE IF EXISTS sheikh_reports;
DROP TABLE IF EXISTS lesson_requests;
DROP TABLE IF EXISTS sheikhs;
