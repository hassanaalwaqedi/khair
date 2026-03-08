-- Phase 4: Growth Engine schema additions

-- ── 1. Referral System ──

-- Unique referral code per user
ALTER TABLE users ADD COLUMN IF NOT EXISTS referral_code VARCHAR(12) UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS reward_points INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS referred_by UUID REFERENCES users(id);

CREATE TABLE IF NOT EXISTS referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inviter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'rewarded')),
    inviter_reward INTEGER NOT NULL DEFAULT 100,
    invitee_reward INTEGER NOT NULL DEFAULT 50,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(invitee_id) -- each user can only be referred once
);

CREATE INDEX IF NOT EXISTS idx_referrals_inviter ON referrals(inviter_id);

-- ── 5. Public Event Pages (SEO) ──

ALTER TABLE events ADD COLUMN IF NOT EXISTS slug VARCHAR(255) UNIQUE;
ALTER TABLE events ADD COLUMN IF NOT EXISTS view_count INTEGER NOT NULL DEFAULT 0;

-- Auto-generate slug from title on insert (if not set)
CREATE OR REPLACE FUNCTION generate_event_slug() RETURNS trigger AS $$
BEGIN
    IF NEW.slug IS NULL OR NEW.slug = '' THEN
        NEW.slug := LOWER(REGEXP_REPLACE(
            REGEXP_REPLACE(NEW.title, '[^a-zA-Z0-9\s-]', '', 'g'),
            '\s+', '-', 'g'
        )) || '-' || SUBSTRING(NEW.id::text, 1, 8);
    END IF;
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_event_slug ON events;
CREATE TRIGGER trg_event_slug
    BEFORE INSERT ON events
    FOR EACH ROW
    EXECUTE FUNCTION generate_event_slug();

-- Backfill slugs for existing events
UPDATE events SET slug = LOWER(REGEXP_REPLACE(
    REGEXP_REPLACE(title, '[^a-zA-Z0-9\s-]', '', 'g'),
    '\s+', '-', 'g'
)) || '-' || SUBSTRING(id::text, 1, 8)
WHERE slug IS NULL;

-- ── 6. Organizer Reputation ──

CREATE TABLE IF NOT EXISTS organizer_reputation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id UUID NOT NULL REFERENCES organizers(id) ON DELETE CASCADE UNIQUE,
    completed_events INTEGER NOT NULL DEFAULT 0,
    cancelled_events INTEGER NOT NULL DEFAULT 0,
    total_attendees INTEGER NOT NULL DEFAULT 0,
    avg_rating NUMERIC(3,2) NOT NULL DEFAULT 0,
    reputation_score NUMERIC(5,2) NOT NULL DEFAULT 0,
    is_verified BOOLEAN NOT NULL DEFAULT false,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ── 7. Event Reviews ──

CREATE TABLE IF NOT EXISTS event_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    overall_rating INTEGER NOT NULL CHECK (overall_rating BETWEEN 1 AND 5),
    organization_rating INTEGER CHECK (organization_rating BETWEEN 1 AND 5),
    venue_rating INTEGER CHECK (venue_rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(event_id, user_id) -- one review per user per event
);

CREATE INDEX IF NOT EXISTS idx_event_reviews_event ON event_reviews(event_id);

-- ── 8. Event Reminders ──

CREATE TABLE IF NOT EXISTS event_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reminder_type VARCHAR(10) NOT NULL CHECK (reminder_type IN ('24h', '2h')),
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(event_id, user_id, reminder_type)
);

-- ── 9. Waitlist ──

CREATE TABLE IF NOT EXISTS event_waitlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'offered', 'accepted', 'expired')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(event_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_event_waitlist_event ON event_waitlist(event_id, position);
