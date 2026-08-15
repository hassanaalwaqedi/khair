# Organizer Hub data contract

The Organizer Hub is backed by `GET /api/v1/organizer/dashboard`. The endpoint
looks up the authenticated user's approved organizer profile and never accepts
an organization id from the client.

## Metrics

- Upcoming events are future events owned by the organizer with status
  `approved` or `published` and `is_published = true`.
- Attendees are distinct users with a `confirmed` registration in the selected
  range. Cancelled, expired, pending, and invalid registrations are excluded.
- Views are distinct event-detail viewers in the selected range. A logged-in
  viewer is identified by `viewer_user_id`; an anonymous viewer is identified
  by the privacy-safe client session id.
- A session can create at most one raw view for the same event in a 30-minute
  window. The raw event is retained for audit/reporting, while dashboard
  aggregation counts distinct identities.
- Join rate is confirmed unique joins divided by unique event-detail viewers.
  The UI renders `—` when the denominator is zero.

The selected analytics range is used for attendees, views, join rate, and the
performance time series. Supported ranges are `7d`, `30d`, `this_month`,
`last_month`, and bounded `custom` ranges.

## Authorization

`/organizer/dashboard` requires authentication and an organizer with
`status = 'approved'`. Organization-scoped mutation and attendee routes also
perform backend membership/ownership checks; client route guards are only a
navigation convenience.

## Announcements

`POST /api/v1/events/:id/notify-attendees` verifies event ownership, persists an
`event_announcements` row, queues delivery rows, creates in-app notifications,
and hands push delivery to the existing FCM service. Delivery state is kept in
`event_announcement_deliveries`.
