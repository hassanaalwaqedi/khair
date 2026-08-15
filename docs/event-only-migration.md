# Event-only database migration

Migration `039_event_only_cleanup` is intentionally forward-only. Before running it in production:

1. Put the API in maintenance mode and take a tested PostgreSQL logical backup, for example `pg_dump --format=custom --file=khair-before-039.dump khair`.
2. Restore that backup into a staging database and run migration 039 there first.
3. Review `legacy_sheikh_accounts_backup`; each former sheikh account and its metadata is retained there for audit and any manual organizer conversion.
4. Confirm event CRUD, registrations, organizer announcements, and notification deep links in staging.
5. Apply 039 once, monitor errors, and retain the backup according to the retention policy.

Legacy student/member/new-muslim accounts become `user`. A legacy organization/community organizer becomes `organizer` only if it already owns an organizer profile; otherwise it becomes `user`. Sheikh data is archived before deletion, so a manual decision can be made from the backup.
