-- Sheikh Trust Systems
-- 1. Reviews / Ratings
CREATE TABLE IF NOT EXISTS sheikh_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sheikh_id UUID NOT NULL REFERENCES sheikhs(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    lesson_request_id UUID REFERENCES lesson_requests(id) ON DELETE SET NULL,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE UNIQUE INDEX idx_sheikh_reviews_unique ON sheikh_reviews(student_id, sheikh_id, lesson_request_id);
CREATE INDEX idx_sheikh_reviews_sheikh ON sheikh_reviews(sheikh_id);

-- 2. Reports
CREATE TABLE IF NOT EXISTS sheikh_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sheikh_id UUID NOT NULL REFERENCES sheikhs(id) ON DELETE CASCADE,
    reported_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX idx_sheikh_reports_sheikh ON sheikh_reports(sheikh_id);
CREATE INDEX idx_sheikh_reports_reporter ON sheikh_reports(reported_by);

-- 3. Booking fields on lesson_requests
ALTER TABLE lesson_requests
    ADD COLUMN IF NOT EXISTS meeting_link TEXT,
    ADD COLUMN IF NOT EXISTS meeting_platform TEXT,
    ADD COLUMN IF NOT EXISTS scheduled_time TIMESTAMP WITH TIME ZONE;
