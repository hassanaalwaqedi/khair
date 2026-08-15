-- 045: Persist the online meeting provider selected in Create Event.
ALTER TABLE events ADD COLUMN IF NOT EXISTS online_platform VARCHAR(32);
