-- Migration 007: Event Join System
-- Adds event capacity, event_registrations, user gender/age, member role

-- 1. Add 'member' to users role constraint
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (
    role IN ('organizer', 'admin', 'organization', 'sheikh', 'new_muslim', 'student', 'community_organizer', 'member')
);

-- 2. Add gender and age to users
ALTER TABLE users ADD COLUMN IF NOT EXISTS gender VARCHAR(10);
ALTER TABLE users ADD COLUMN IF NOT EXISTS age INT;

-- 3. Add capacity and reserved_count to events
ALTER TABLE events ADD COLUMN IF NOT EXISTS capacity INT;
ALTER TABLE events ADD COLUMN IF NOT EXISTS reserved_count INT NOT NULL DEFAULT 0;

-- 4. Create event_registrations table
CREATE TABLE IF NOT EXISTS event_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'expired', 'cancelled')),
    reserved_until TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, event_id)
);

-- 5. Indexes for event_registrations
CREATE INDEX IF NOT EXISTS idx_event_reg_user_id ON event_registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_event_reg_event_id ON event_registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_event_reg_status ON event_registrations(status);
CREATE INDEX IF NOT EXISTS idx_event_reg_reserved_until ON event_registrations(reserved_until) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_event_reg_user_event ON event_registrations(user_id, event_id);

-- 6. Trigger for updated_at on event_registrations
CREATE TRIGGER set_event_registrations_updated_at
    BEFORE UPDATE ON event_registrations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 7. Index for event capacity queries
CREATE INDEX IF NOT EXISTS idx_events_capacity ON events(capacity) WHERE capacity IS NOT NULL;
