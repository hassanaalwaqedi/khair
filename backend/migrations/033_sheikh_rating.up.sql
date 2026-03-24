CREATE TABLE IF NOT EXISTS sheikh_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sheikh_id UUID NOT NULL REFERENCES sheikhs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating SMALLINT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sheikh_ratings_sheikh_id ON sheikh_ratings(sheikh_id);
CREATE INDEX idx_sheikh_ratings_user_id ON sheikh_ratings(user_id);
