ALTER TABLE lesson_requests
    DROP COLUMN IF EXISTS meeting_link,
    DROP COLUMN IF EXISTS meeting_platform,
    DROP COLUMN IF EXISTS scheduled_time;

DROP TABLE IF EXISTS sheikh_reports;
DROP TABLE IF EXISTS sheikh_reviews;
