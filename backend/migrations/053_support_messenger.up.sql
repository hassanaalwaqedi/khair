-- Evolve the existing support ticket store into the persistent conversation
-- record used by the AI-first support messenger.
ALTER TABLE support_tickets
    ADD COLUMN IF NOT EXISTS language VARCHAR(10) NOT NULL DEFAULT 'en',
    ADD COLUMN IF NOT EXISTS context_type VARCHAR(50),
    ADD COLUMN IF NOT EXISTS context_id UUID;

ALTER TABLE support_messages
    ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

-- Keep historical conversations while making the state names explicit about
-- whether a human agent has joined.
UPDATE support_tickets SET status = 'waiting_for_agent'
WHERE status = 'waiting_for_support';

UPDATE support_tickets SET status = 'human_active'
WHERE status = 'in_progress';

CREATE INDEX IF NOT EXISTS idx_support_tickets_active_conversation
    ON support_tickets(user_id, updated_at DESC)
    WHERE status IN ('ai_active', 'waiting_for_agent', 'human_active');

CREATE INDEX IF NOT EXISTS idx_support_tickets_context
    ON support_tickets(user_id, context_type, context_id)
    WHERE context_type IS NOT NULL;

-- Reviewed, maintainable Khair-specific facts used by support retrieval. The
-- AI prompt forbids it from treating these as a source of policies beyond
-- their stated scope.
INSERT INTO support_articles (slug, title, content, category, language, is_published)
VALUES
    ('organizer-application', 'Organizer applications', 'To become an organizer, complete and submit an organizer application in Khair. Event creation becomes available after the application has been approved. If an application needs changes or is rejected, the application screen shows the review outcome when it is available.', 'organizer', 'en', true),
    ('event-meeting-link', 'Online event meeting links', 'For an online event you joined, open My Events and select the event. Meeting access is shown only when it is available for your registration. If the link is still unavailable, Khair Support can review the conversation context without asking you to repeat the issue.', 'events', 'en', true),
    ('event-registration', 'Event registrations', 'Use My Events to review events you joined or saved. Event details show the information made available to attendees, including online access when applicable.', 'events', 'en', true),
    ('language-settings', 'Changing language', 'You can change Khair language from your profile preferences. Khair currently supports Arabic, English, and Turkish.', 'account', 'en', true),
    ('notifications', 'Notifications', 'Khair notifications depend on the app and device notification permissions. Check your device settings if you are not receiving them, then return to Khair Support if the problem continues.', 'notifications', 'en', true)
ON CONFLICT (slug) DO UPDATE SET
    title = EXCLUDED.title,
    content = EXCLUDED.content,
    category = EXCLUDED.category,
    language = EXCLUDED.language,
    is_published = EXCLUDED.is_published,
    updated_at = NOW();
