package discovery

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"

	"github.com/khair/backend/pkg/response"
)

const cacheTTL = 5 * time.Minute

// Service provides event discovery (featured, trending, nearby, categories).
type Service struct {
	db    *sql.DB
	redis *redis.Client
}

// NewService creates a new discovery service.
func NewService(db *sql.DB, redisClient *redis.Client) *Service {
	return &Service{db: db, redis: redisClient}
}

// ── Discovery models ──

// DiscoveryEvent is a lightweight event for discovery lists.
type DiscoveryEvent struct {
	ID            string  `json:"id"`
	Title         string  `json:"title"`
	EventType     string  `json:"event_type"`
	City          string  `json:"city"`
	Country       string  `json:"country"`
	ImageURL      *string `json:"image_url"`
	StartDate     string  `json:"start_date"`
	OrganizerName string  `json:"organizer_name"`
}

// Category is an event type with count.
type Category struct {
	Name  string `json:"name"`
	Count int64  `json:"count"`
}

// ── Cached queries ──

func (s *Service) cachedQuery(ctx context.Context, key string, dest interface{}, queryFn func() (interface{}, error)) error {
	// Try cache first
	if s.redis != nil {
		cached, err := s.redis.Get(ctx, key).Result()
		if err == nil {
			return json.Unmarshal([]byte(cached), dest)
		}
	}

	// Query DB
	result, err := queryFn()
	if err != nil {
		return err
	}

	// Cache result
	if s.redis != nil {
		data, _ := json.Marshal(result)
		s.redis.Set(ctx, key, data, cacheTTL)
	}

	// Copy into dest
	data, _ := json.Marshal(result)
	return json.Unmarshal(data, dest)
}

// GetFeatured returns admin-curated or most recent approved events.
func (s *Service) GetFeatured(ctx context.Context) ([]DiscoveryEvent, error) {
	var events []DiscoveryEvent
	err := s.cachedQuery(ctx, "discover:featured", &events, func() (interface{}, error) {
		return s.queryEvents(`
			SELECT e.id, e.title, e.event_type, COALESCE(e.city,''), COALESCE(e.country,''),
			       e.image_url, e.start_date, COALESCE(o.name,'')
			FROM events e
			LEFT JOIN organizers o ON o.id = e.organizer_id
			WHERE e.status = 'approved' AND e.is_published = true
			  AND e.start_date > NOW()
			ORDER BY e.start_date ASC
			LIMIT 10
		`)
	})
	return events, err
}

// GetTrending returns events with most registrations.
func (s *Service) GetTrending(ctx context.Context) ([]DiscoveryEvent, error) {
	var events []DiscoveryEvent
	err := s.cachedQuery(ctx, "discover:trending", &events, func() (interface{}, error) {
		return s.queryEvents(`
			SELECT e.id, e.title, e.event_type, COALESCE(e.city,''), COALESCE(e.country,''),
			       e.image_url, e.start_date, COALESCE(o.name,'')
			FROM events e
			LEFT JOIN organizers o ON o.id = e.organizer_id
			LEFT JOIN attendees a ON a.event_id = e.id
			WHERE e.status = 'approved' AND e.is_published = true
			  AND e.start_date > NOW()
			GROUP BY e.id, o.name
			ORDER BY COUNT(a.id) DESC
			LIMIT 10
		`)
	})
	return events, err
}

// GetNearby returns events near a lat/lng using PostGIS.
func (s *Service) GetNearby(ctx context.Context, lat, lng float64, radiusKm int) ([]DiscoveryEvent, error) {
	key := fmt.Sprintf("discover:nearby:%.2f:%.2f:%d", lat, lng, radiusKm)
	var events []DiscoveryEvent
	err := s.cachedQuery(ctx, key, &events, func() (interface{}, error) {
		return s.queryEvents(fmt.Sprintf(`
			SELECT e.id, e.title, e.event_type, COALESCE(e.city,''), COALESCE(e.country,''),
			       e.image_url, e.start_date, COALESCE(o.name,'')
			FROM events e
			LEFT JOIN organizers o ON o.id = e.organizer_id
			WHERE e.status = 'approved' AND e.is_published = true
			  AND e.start_date > NOW()
			  AND ST_DWithin(e.location, ST_MakePoint(%f, %f)::geography, %d)
			ORDER BY e.start_date ASC
			LIMIT 20
		`, lng, lat, radiusKm*1000))
	})
	return events, err
}

// GetCategories returns event types with counts.
func (s *Service) GetCategories(ctx context.Context) ([]Category, error) {
	var categories []Category
	err := s.cachedQuery(ctx, "discover:categories", &categories, func() (interface{}, error) {
		rows, err := s.db.QueryContext(ctx, `
			SELECT event_type, COUNT(*)
			FROM events
			WHERE status = 'approved' AND is_published = true AND start_date > NOW()
			GROUP BY event_type
			ORDER BY COUNT(*) DESC
		`)
		if err != nil {
			return nil, err
		}
		defer rows.Close()

		var cats []Category
		for rows.Next() {
			var c Category
			rows.Scan(&c.Name, &c.Count)
			cats = append(cats, c)
		}
		if cats == nil {
			cats = []Category{}
		}
		return cats, nil
	})
	return categories, err
}

// GetRecommended returns personalized event recommendations for a user.
// Uses past registrations and location to find similar events.
func (s *Service) GetRecommended(ctx context.Context, userID string) ([]DiscoveryEvent, error) {
	key := fmt.Sprintf("discover:recommended:%s", userID)
	var events []DiscoveryEvent
	err := s.cachedQuery(ctx, key, &events, func() (interface{}, error) {
		// Find events matching categories the user has attended before
		return s.queryEvents(fmt.Sprintf(`
			SELECT DISTINCT e.id, e.title, e.event_type, COALESCE(e.city,''), COALESCE(e.country,''),
			       e.image_url, e.start_date, COALESCE(o.name,'')
			FROM events e
			LEFT JOIN organizers o ON o.id = e.organizer_id
			WHERE e.status = 'approved' AND e.is_published = true
			  AND e.start_date > NOW()
			  AND (
			    e.event_type IN (
			      SELECT DISTINCT ev.event_type FROM events ev
			      JOIN attendees a ON a.event_id = ev.id
			      WHERE a.user_id = '%s'
			    )
			    OR e.country IN (
			      SELECT DISTINCT ev.country FROM events ev
			      JOIN attendees a ON a.event_id = ev.id
			      WHERE a.user_id = '%s'
			    )
			  )
			  AND e.id NOT IN (
			    SELECT event_id FROM attendees WHERE user_id = '%s'
			  )
			ORDER BY e.start_date ASC
			LIMIT 15
		`, userID, userID, userID))
	})

	// Fallback to featured if no recommendations
	if len(events) == 0 {
		return s.GetFeatured(ctx)
	}

	return events, err
}

func (s *Service) queryEvents(query string) (interface{}, error) {
	rows, err := s.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var events []DiscoveryEvent
	for rows.Next() {
		var e DiscoveryEvent
		var startDate time.Time
		if err := rows.Scan(&e.ID, &e.Title, &e.EventType, &e.City, &e.Country, &e.ImageURL, &startDate, &e.OrganizerName); err != nil {
			log.Printf("[DISCOVERY] Scan error: %v", err)
			continue
		}
		e.StartDate = startDate.Format(time.RFC3339)
		events = append(events, e)
	}
	if events == nil {
		events = []DiscoveryEvent{}
	}
	return events, nil
}

// ── Handler ──

// Handler handles discovery HTTP endpoints.
type Handler struct {
	service *Service
}

// NewHandler creates a new discovery handler.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers discovery routes.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	discover := r.Group("/discover")
	{
		discover.GET("/featured", h.Featured)
		discover.GET("/trending", h.Trending)
		discover.GET("/nearby", h.Nearby)
		discover.GET("/categories", h.Categories)
		discover.GET("/recommended", h.Recommended)
	}
}

// Featured handles GET /discover/featured
func (h *Handler) Featured(c *gin.Context) {
	events, err := h.service.GetFeatured(c.Request.Context())
	if err != nil {
		response.InternalServerError(c, "Failed to get featured events")
		return
	}
	response.Success(c, events)
}

// Trending handles GET /discover/trending
func (h *Handler) Trending(c *gin.Context) {
	events, err := h.service.GetTrending(c.Request.Context())
	if err != nil {
		response.InternalServerError(c, "Failed to get trending events")
		return
	}
	response.Success(c, events)
}

// Nearby handles GET /discover/nearby?lat=X&lng=Y&radius=Z
func (h *Handler) Nearby(c *gin.Context) {
	lat, err := strconv.ParseFloat(c.Query("lat"), 64)
	if err != nil {
		response.BadRequest(c, "lat is required")
		return
	}
	lng, err := strconv.ParseFloat(c.Query("lng"), 64)
	if err != nil {
		response.BadRequest(c, "lng is required")
		return
	}
	radius := 50 // default 50km
	if r := c.Query("radius"); r != "" {
		if parsed, err := strconv.Atoi(r); err == nil && parsed > 0 && parsed <= 500 {
			radius = parsed
		}
	}

	events, err := h.service.GetNearby(c.Request.Context(), lat, lng, radius)
	if err != nil {
		response.InternalServerError(c, "Failed to get nearby events")
		return
	}
	response.Success(c, events)
}

// Categories handles GET /discover/categories
func (h *Handler) Categories(c *gin.Context) {
	cats, err := h.service.GetCategories(c.Request.Context())
	if err != nil {
		response.Error(c, http.StatusInternalServerError, "Failed to get categories")
		return
	}
	response.Success(c, cats)
}

// Recommended handles GET /discover/recommended?user_id=X
func (h *Handler) Recommended(c *gin.Context) {
	userID := c.Query("user_id")
	if userID == "" {
		// Fallback to featured for anonymous users
		h.Featured(c)
		return
	}

	events, err := h.service.GetRecommended(c.Request.Context(), userID)
	if err != nil {
		response.InternalServerError(c, "Failed to get recommendations")
		return
	}
	response.Success(c, events)
}
