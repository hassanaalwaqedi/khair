-- 055: Repair the historical rows where the legacy event_type label and the
-- canonical is_online flag disagree. Discovery already relies on is_online,
-- so keeping that flag authoritative preserves the event format selected by
-- the organizer and prevents the detail screen from rendering the wrong UI.
UPDATE events
SET
  event_type = CASE WHEN is_online THEN 'online' ELSE 'offline' END,
  updated_at = NOW()
WHERE LOWER(TRIM(event_type)) IN ('online', 'offline')
  AND LOWER(TRIM(event_type)) IS DISTINCT FROM CASE
    WHEN is_online THEN 'online'
    ELSE 'offline'
  END;
