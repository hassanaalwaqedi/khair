-- Rollback Phase 4: AI Personalization Layer

DROP INDEX IF EXISTS idx_ai_scores_event;
DROP INDEX IF EXISTS idx_ai_scores_user_rank;
DROP INDEX IF EXISTS idx_interactions_type;
DROP INDEX IF EXISTS idx_interactions_event;
DROP INDEX IF EXISTS idx_interactions_user_time;

DROP TABLE IF EXISTS user_profiles_ai;
DROP TABLE IF EXISTS ai_event_scores;
DROP TABLE IF EXISTS user_interactions;
