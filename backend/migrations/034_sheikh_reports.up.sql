CREATE TABLE IF NOT EXISTS sheikh_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sheikh_id UUID NOT NULL REFERENCES sheikhs(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sheikh_reports_sheikh_id ON sheikh_reports(sheikh_id);
CREATE INDEX idx_sheikh_reports_reporter_id ON sheikh_reports(reporter_id);
