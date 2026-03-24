-- 029: Add online event access fields
ALTER TABLE events ADD COLUMN IF NOT EXISTS is_online BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE events ADD COLUMN IF NOT EXISTS online_link TEXT;
ALTER TABLE events ADD COLUMN IF NOT EXISTS join_instructions TEXT;
ALTER TABLE events ADD COLUMN IF NOT EXISTS join_link_visible_before_minutes INT NOT NULL DEFAULT 15;
