package mapservice

import (
	"context"
	"errors"
	"fmt"
	"net"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/config"
	"github.com/khair/backend/pkg/middleware"
	"github.com/khair/backend/pkg/response"
)

// Handler handles map HTTP requests.
type Handler struct {
	service *Service
	cfg     *config.Config
}

// NewHandler creates a new map handler.
func NewHandler(service *Service, cfg *config.Config) *Handler {
	return &Handler{
		service: service,
		cfg:     cfg,
	}
}

// RegisterRoutes registers map routes.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, geoRateLimit gin.HandlerFunc) {
	mapGroup := r.Group("/map")
	if geoRateLimit != nil {
		mapGroup.Use(geoRateLimit)
	}
	{
		mapGroup.GET("/nearby", h.FindNearby)
		mapGroup.GET("/bounds", h.FindInBounds) // backward-compatible viewport endpoint
		mapGroup.GET("/contextual", h.ListContextualPlaces)
		mapGroup.GET("/filter-options", h.GetFilterOptions)
		mapGroup.POST("/geo-interactions", h.TrackGeoInteraction)
	}
}

// FindNearby finds events near a location.
// @Summary Find nearby events with smart geo filters
// @Description Radius + viewport optimized geo search with recommendation scoring
// @Tags map
// @Accept json
// @Produce json
// @Param lat query number true "Latitude"
// @Param lng query number true "Longitude"
// @Param radius_km query number false "Radius in km" default(10)
// @Param categories[] query []string false "Filter by categories"
// @Param gender query string false "Gender filter"
// @Param min_age query int false "Age compatibility"
// @Param date_from query string false "RFC3339 or YYYY-MM-DD"
// @Param date_to query string false "RFC3339 or YYYY-MM-DD"
// @Param free_only query bool false "Show free events only"
// @Param almost_full query bool false "Show almost full events"
// @Param sort query string false "distance|relevance"
// @Param personalized query bool false "Require auth and return personalized ranking"
// @Param page query int false "Pagination page" default(1)
// @Param page_size query int false "Pagination page size" default(60)
// @Success 200 {object} NearbyResponse
// @Failure 400 {object} response.Response
// @Failure 401 {object} response.Response
// @Router /map/nearby [get]
func (h *Handler) FindNearby(c *gin.Context) {
	filter, flagged, flagReason, err := h.parseNearbyFilter(c, false)
	if err != nil {
		if errors.Is(err, ErrAuthRequired) {
			response.Unauthorized(c, err.Error())
			return
		}
		response.BadRequest(c, err.Error())
		return
	}

	nearby, err := h.service.FindNearby(c.Request.Context(), filter)
	if err != nil {
		if errors.Is(err, ErrBoundingBoxAbuse) {
			h.logGeoRequest(c, "/map/nearby", filter, true, "bounding box abuse detected")
		}
		if errors.Is(err, ErrAuthRequired) {
			response.Unauthorized(c, err.Error())
			return
		}
		response.BadRequest(c, err.Error())
		return
	}

	h.logGeoRequest(c, "/map/nearby", filter, flagged, flagReason)
	response.Success(c, nearby)
}

// FindInBounds finds events within a viewport bounding box.
// @Summary Find map events in bounds
// @Description Viewport-driven map fetch with debounced client calls
// @Tags map
// @Accept json
// @Produce json
// @Param min_lat query number true "Minimum latitude"
// @Param min_lng query number true "Minimum longitude"
// @Param max_lat query number true "Maximum latitude"
// @Param max_lng query number true "Maximum longitude"
// @Param lat query number false "Center latitude (optional, auto-derived)"
// @Param lng query number false "Center longitude (optional, auto-derived)"
// @Success 200 {object} NearbyResponse
// @Failure 400 {object} response.Response
// @Router /map/bounds [get]
func (h *Handler) FindInBounds(c *gin.Context) {
	filter, flagged, flagReason, err := h.parseNearbyFilter(c, true)
	if err != nil {
		if errors.Is(err, ErrAuthRequired) {
			response.Unauthorized(c, err.Error())
			return
		}
		response.BadRequest(c, err.Error())
		return
	}

	nearby, err := h.service.FindNearby(c.Request.Context(), filter)
	if err != nil {
		if errors.Is(err, ErrBoundingBoxAbuse) {
			h.logGeoRequest(c, "/map/bounds", filter, true, "bounding box abuse detected")
		}
		if errors.Is(err, ErrAuthRequired) {
			response.Unauthorized(c, err.Error())
			return
		}
		response.BadRequest(c, err.Error())
		return
	}

	h.logGeoRequest(c, "/map/bounds", filter, flagged, flagReason)
	response.Success(c, nearby)
}

// ListContextualPlaces returns optional contextual Islamic layers.
func (h *Handler) ListContextualPlaces(c *gin.Context) {
	minLat, err := parseFloatRequired(c, "min_lat")
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	minLng, err := parseFloatRequired(c, "min_lng")
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	maxLat, err := parseFloatRequired(c, "max_lat")
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	maxLng, err := parseFloatRequired(c, "max_lng")
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	pageSize := 120
	if raw := c.Query("page_size"); raw != "" {
		if parsed, parseErr := strconv.Atoi(raw); parseErr == nil {
			pageSize = parsed
		}
	}

	placeTypes := parseStringArray(c, "layers")
	if len(placeTypes) == 0 {
		placeTypes = parseStringArray(c, "layers[]")
	}

	places, err := h.service.ListContextualPlaces(c.Request.Context(), &ContextualQuery{
		MinLat:     minLat,
		MinLng:     minLng,
		MaxLat:     maxLat,
		MaxLng:     maxLng,
		PlaceTypes: placeTypes,
		PageSize:   pageSize,
	})
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Success(c, places)
}

// GetFilterOptions returns dynamic category/gender/radius options.
func (h *Handler) GetFilterOptions(c *gin.Context) {
	options, err := h.service.GetFilterOptions(c.Request.Context())
	if err != nil {
		response.InternalServerError(c, "Failed to load filter options")
		return
	}
	response.Success(c, options)
}

// TrackGeoInteraction stores anonymized geo interaction events.
func (h *Handler) TrackGeoInteraction(c *gin.Context) {
	var metric GeoInteractionMetric
	if err := c.ShouldBindJSON(&metric); err != nil {
		response.BadRequest(c, "Invalid interaction payload")
		return
	}

	if metric.SessionHash == "" {
		response.BadRequest(c, "session_hash is required")
		return
	}
	switch metric.EventType {
	case "map_open", "marker_tap", "filter_use", "reservation_from_map", "distance_distribution":
	default:
		response.BadRequest(c, "invalid event_type")
		return
	}

	userID, _ := h.resolveOptionalUserID(c)
	metric.UserID = userID

	if err := h.service.TrackGeoInteraction(c.Request.Context(), &metric); err != nil {
		response.InternalServerError(c, "Failed to track interaction")
		return
	}
	response.SuccessWithMessage(c, "Interaction tracked", nil)
}

func (h *Handler) parseNearbyFilter(c *gin.Context, requireBounds bool) (*NearbyFilter, bool, string, error) {
	lat, err := parseFloatRequired(c, "lat")
	if err != nil && requireBounds {
		lat = 0
	} else if err != nil {
		return nil, false, "", err
	}
	lng, err := parseFloatRequired(c, "lng")
	if err != nil && requireBounds {
		lng = 0
	} else if err != nil {
		return nil, false, "", err
	}

	minLat := parseFloatDefault(c, "min_lat", 0)
	minLng := parseFloatDefault(c, "min_lng", 0)
	maxLat := parseFloatDefault(c, "max_lat", 0)
	maxLng := parseFloatDefault(c, "max_lng", 0)

	useViewport := requireBounds || (c.Query("min_lat") != "" && c.Query("max_lat") != "" && c.Query("min_lng") != "" && c.Query("max_lng") != "")
	if useViewport {
		if maxLat <= minLat || maxLng <= minLng {
			return nil, false, "", fmt.Errorf("invalid viewport bounds")
		}
		if lat == 0 && lng == 0 {
			lat = (minLat + maxLat) / 2.0
			lng = (minLng + maxLng) / 2.0
		}
	}

	radiusKm := parseFloatDefault(c, "radius_km", defaultRadiusKm)
	if radiusKm <= 0 {
		radiusKm = parseFloatDefault(c, "radius", defaultRadiusKm)
	}

	if radiusKm <= 0 {
		radiusKm = defaultRadiusKm
	}

	dateFrom, err := parseOptionalDate(c.Query("date_from"))
	if err != nil {
		return nil, false, "", fmt.Errorf("invalid date_from")
	}
	dateTo, err := parseOptionalDate(c.Query("date_to"))
	if err != nil {
		return nil, false, "", fmt.Errorf("invalid date_to")
	}

	categories := parseStringArray(c, "categories")
	if len(categories) == 0 {
		categories = parseStringArray(c, "categories[]")
	}

	age := parseIntDefault(c, "min_age", 0)
	page := parseIntDefault(c, "page", defaultPage)
	pageSize := parseIntDefault(c, "page_size", defaultPageSize)
	sortBy := c.DefaultQuery("sort", "relevance")

	personalized := strings.EqualFold(c.DefaultQuery("personalized", "false"), "true")
	userID, userErr := h.resolveOptionalUserID(c)
	if personalized && (userErr != nil || userID == nil) {
		return nil, false, "", ErrAuthRequired
	}

	flagged := false
	flagReason := ""
	if parseFloatDefault(c, "radius_km", radiusKm) > maxRadiusKm*3 {
		flagged = true
		flagReason = "radius_km exceeds normal safety range"
	}
	if pageSize > maxPageSize*2 {
		flagged = true
		if flagReason == "" {
			flagReason = "page_size exceeds normal safety range"
		}
	}

	return &NearbyFilter{
		Latitude:     lat,
		Longitude:    lng,
		RadiusKm:     radiusKm,
		UseViewport:  useViewport,
		MinLat:       minLat,
		MinLng:       minLng,
		MaxLat:       maxLat,
		MaxLng:       maxLng,
		Categories:   categories,
		Gender:       c.Query("gender"),
		Age:          age,
		DateFrom:     dateFrom,
		DateTo:       dateTo,
		FreeOnly:     parseBoolDefault(c, "free_only", false),
		AlmostFull:   parseBoolDefault(c, "almost_full", false),
		Search:       strings.TrimSpace(c.Query("search")),
		SortBy:       sortBy,
		Page:         page,
		PageSize:     pageSize,
		Personalized: personalized,
		UserID:       userID,
	}, flagged, flagReason, nil
}

func (h *Handler) resolveOptionalUserID(c *gin.Context) (*uuid.UUID, error) {
	if value, exists := c.Get("user_id"); exists && value != nil {
		switch v := value.(type) {
		case uuid.UUID:
			id := v
			return &id, nil
		case string:
			id, err := uuid.Parse(v)
			if err != nil {
				return nil, err
			}
			return &id, nil
		}
	}

	authHeader := c.GetHeader("Authorization")
	if authHeader == "" {
		return nil, nil
	}
	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		return nil, errors.New("invalid authorization header format")
	}

	token, err := jwt.ParseWithClaims(parts[1], &middleware.Claims{}, func(token *jwt.Token) (interface{}, error) {
		return []byte(h.cfg.JWT.Secret), nil
	})
	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(*middleware.Claims)
	if !ok || !token.Valid {
		return nil, errors.New("invalid auth token")
	}

	id, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, err
	}

	return &id, nil
}

func (h *Handler) logGeoRequest(c *gin.Context, endpoint string, filter *NearbyFilter, flagged bool, flagReason string) {
	logPayload := h.service.BuildGeoRequestLog(
		endpoint,
		clientIP(c),
		filter,
		filter.UserID,
		flagged,
		flagReason,
	)
	ctx, cancel := context.WithTimeout(context.Background(), 250*time.Millisecond)
	defer cancel()
	h.service.LogGeoRequest(ctx, logPayload)
}

func parseFloatRequired(c *gin.Context, key string) (float64, error) {
	raw := c.Query(key)
	if raw == "" {
		return 0, fmt.Errorf("%s is required", key)
	}
	value, err := strconv.ParseFloat(raw, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid %s", key)
	}
	return value, nil
}

func parseFloatDefault(c *gin.Context, key string, fallback float64) float64 {
	raw := c.Query(key)
	if raw == "" {
		return fallback
	}
	value, err := strconv.ParseFloat(raw, 64)
	if err != nil {
		return fallback
	}
	return value
}

func parseIntDefault(c *gin.Context, key string, fallback int) int {
	raw := c.Query(key)
	if raw == "" {
		return fallback
	}
	value, err := strconv.Atoi(raw)
	if err != nil {
		return fallback
	}
	return value
}

func parseBoolDefault(c *gin.Context, key string, fallback bool) bool {
	raw := c.Query(key)
	if raw == "" {
		return fallback
	}
	value, err := strconv.ParseBool(raw)
	if err != nil {
		return fallback
	}
	return value
}

func parseStringArray(c *gin.Context, key string) []string {
	values := c.QueryArray(key)
	if len(values) > 0 {
		return cleanArray(values)
	}
	raw := c.Query(key)
	if raw == "" {
		return nil
	}
	return cleanArray(strings.Split(raw, ","))
}

func cleanArray(values []string) []string {
	out := make([]string, 0, len(values))
	seen := map[string]struct{}{}
	for _, value := range values {
		v := strings.TrimSpace(value)
		if v == "" {
			continue
		}
		if _, exists := seen[v]; exists {
			continue
		}
		seen[v] = struct{}{}
		out = append(out, v)
	}
	return out
}

func parseOptionalDate(raw string) (*time.Time, error) {
	if raw == "" {
		return nil, nil
	}
	layouts := []string{time.RFC3339, "2006-01-02"}
	for _, layout := range layouts {
		if parsed, err := time.Parse(layout, raw); err == nil {
			value := parsed.UTC()
			return &value, nil
		}
	}
	return nil, fmt.Errorf("invalid date format")
}

func clientIP(c *gin.Context) string {
	if xff := c.GetHeader("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		return strings.TrimSpace(parts[0])
	}
	if xri := c.GetHeader("X-Real-IP"); xri != "" {
		return xri
	}
	host, _, err := net.SplitHostPort(c.Request.RemoteAddr)
	if err != nil {
		return c.Request.RemoteAddr
	}
	return host
}
