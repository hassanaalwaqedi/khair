-- Forward-only production migration. Restoring dropped legacy tables requires
-- the verified database backup taken before applying 039; do not run down.
DROP TABLE IF EXISTS event_announcements;
