-- 029: Remove online event access fields
ALTER TABLE events DROP COLUMN IF EXISTS join_link_visible_before_minutes;
ALTER TABLE events DROP COLUMN IF EXISTS join_instructions;
ALTER TABLE events DROP COLUMN IF EXISTS online_link;
ALTER TABLE events DROP COLUMN IF EXISTS is_online;
