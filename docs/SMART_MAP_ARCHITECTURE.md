# Smart Islamic Event Map Architecture

## Scope
Primary discovery engine for 100k+ users with:
- Geo-based discovery and viewport fetching
- Live smart filters
- Recommendation-first ranking
- Contextual Islamic layers
- Rate-limited and abuse-protected geo endpoints

## Text Architecture Diagram
```text
Flutter SmartMapScreen
  -> MapStateManager (debounce 300ms, cache, dedupe, pagination)
      -> GeoService
          -> GET /api/v1/events/nearby (alias to map engine)
          -> GET /api/v1/events/filter-options
          -> GET /api/v1/map/contextual
          -> POST /api/v1/map/geo-interactions

Go API (Gin)
  -> mapservice.Handler
      -> mapservice.Service
          -> mapservice.Repository
              -> PostgreSQL + PostGIS
                  -> events.location_point (GIST)
                  -> ST_DWithin + bbox envelope + viewport bounds
                  -> recommendation score projection
                  -> geo_request_logs / geo_interaction_metrics
                  -> islamic_places layer table
```

## Backend Endpoints
- `GET /api/v1/events/nearby`
- `GET /api/v1/events/filter-options`
- `GET /api/v1/map/nearby`
- `GET /api/v1/map/bounds`
- `GET /api/v1/map/contextual`
- `POST /api/v1/map/geo-interactions`

`/api/v1/events/nearby` is exposed as a compatibility alias through the existing `/events/:id` route dispatch.

## Geo Query Strategy
- Radius search via `ST_DWithin(location_point, user_point, radius_meters)`
- Bbox pre-filter via `location_point::geometry && ST_MakeEnvelope(...)`
- Optional viewport clip for map camera bounds
- Combined filters:
  - categories
  - gender compatibility
  - age compatibility
  - date range
  - free only
  - almost full
- Sort modes:
  - `distance`
  - `relevance`

## Recommendation Score (0..1)
Weighted blend of:
- proximity score
- popularity score (fill-rate or reserve density)
- category affinity from user interactions
- location affinity from user interaction geography
- age compatibility
- cached AI relevance score (`ai_event_scores`)

Returned flags:
- `is_trending`
- `recommended`
- `ending_soon`

## Security and Abuse Controls
- Geo endpoint rate limiting (`geo_search`)
- Lat/lng and bounds validation
- Bounding-box abuse rejection
- Personalized mode (`personalized=true`) requires auth
- Suspicious geo requests logged to `geo_request_logs`

## Performance Controls
- Debounced map movement fetch (300ms)
- Viewport-result cache in `MapStateManager`
- In-flight request dedupe by viewport/filter key
- Lazy page-2 prefetch at high zoom
- Marker cap and cluster aggregation
- Offline fallback to cached viewport payload

## Analytics Events
Stored in `geo_interaction_metrics`:
- `map_open`
- `marker_tap`
- `filter_use`
- `reservation_from_map`
- `distance_distribution`

## Migration
`backend/migrations/009_smart_map_geo.up.sql` adds:
- normalized event geo/filter columns
- `location_point` + spatial index
- geo request logs
- contextual Islamic places table
- anonymized geo interaction metrics
