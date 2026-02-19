-- Phase 4: Rollback
-- =================

DROP FUNCTION IF EXISTS organizer_has_accepted_agreement(UUID);
DROP FUNCTION IF EXISTS user_has_accepted_current_policy(UUID, VARCHAR);

DROP INDEX IF EXISTS idx_system_switches_name;
DROP INDEX IF EXISTS idx_policies_current;
DROP INDEX IF EXISTS idx_organizer_agreements_organizer;
DROP INDEX IF EXISTS idx_policy_acceptances_policy;
DROP INDEX IF EXISTS idx_policy_acceptances_user;

DROP TABLE IF EXISTS system_switches;
DROP TABLE IF EXISTS organizer_agreements;
DROP TABLE IF EXISTS policy_acceptances;
DROP TABLE IF EXISTS policies;
