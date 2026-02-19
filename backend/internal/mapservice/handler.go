package mapservice

import (
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/khair/backend/pkg/response"
)

// Handler handles map HTTP requests
type Handler struct {
	service *Service
}

// NewHandler creates a new map handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers map routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	mapGroup := r.Group("/map")
	{
		mapGroup.GET("/nearby", h.FindNearby)
		mapGroup.GET("/bounds", h.FindInBounds)
	}
}

// FindNearby finds events near a location
// @Summary Find nearby events
// @Description Find events within a radius of a given location
// @Tags map
// @Accept json
// @Produce json
// @Param lat query number true "Latitude"
// @Param lng query number true "Longitude"
// @Param radius query number false "Radius in km" default(10)
// @Param event_type query string false "Filter by event type"
// @Param language query string false "Filter by language"
// @Param limit query int false "Maximum results" default(50)
// @Success 200 {object} []models.EventWithOrganizer
// @Failure 400 {object} response.Response
// @Router /map/nearby [get]
func (h *Handler) FindNearby(c *gin.Context) {
	lat, err := strconv.ParseFloat(c.Query("lat"), 64)
	if err != nil {
		response.BadRequest(c, "Invalid latitude")
		return
	}

	lng, err := strconv.ParseFloat(c.Query("lng"), 64)
	if err != nil {
		response.BadRequest(c, "Invalid longitude")
		return
	}

	filter := &NearbyFilter{
		Latitude:  lat,
		Longitude: lng,
		RadiusKm:  10, // Default
		Limit:     50, // Default
	}

	if radius := c.Query("radius"); radius != "" {
		if r, err := strconv.ParseFloat(radius, 64); err == nil {
			filter.RadiusKm = r
		}
	}

	if eventType := c.Query("event_type"); eventType != "" {
		filter.EventType = &eventType
	}

	if language := c.Query("language"); language != "" {
		filter.Language = &language
	}

	if limit := c.Query("limit"); limit != "" {
		if l, err := strconv.Atoi(limit); err == nil {
			filter.Limit = l
		}
	}

	events, err := h.service.FindNearby(filter)
	if err != nil {
		response.InternalServerError(c, "Failed to search events")
		return
	}

	response.Success(c, events)
}

// FindInBounds finds events within a bounding box
// @Summary Find events in bounds
// @Description Find events within a geographic bounding box
// @Tags map
// @Accept json
// @Produce json
// @Param min_lat query number true "Minimum latitude"
// @Param max_lat query number true "Maximum latitude"
// @Param min_lng query number true "Minimum longitude"
// @Param max_lng query number true "Maximum longitude"
// @Param event_type query string false "Filter by event type"
// @Param language query string false "Filter by language"
// @Param limit query int false "Maximum results" default(50)
// @Success 200 {object} []models.EventWithOrganizer
// @Failure 400 {object} response.Response
// @Router /map/bounds [get]
func (h *Handler) FindInBounds(c *gin.Context) {
	minLat, err := strconv.ParseFloat(c.Query("min_lat"), 64)
	if err != nil {
		response.BadRequest(c, "Invalid min_lat")
		return
	}

	maxLat, err := strconv.ParseFloat(c.Query("max_lat"), 64)
	if err != nil {
		response.BadRequest(c, "Invalid max_lat")
		return
	}

	minLng, err := strconv.ParseFloat(c.Query("min_lng"), 64)
	if err != nil {
		response.BadRequest(c, "Invalid min_lng")
		return
	}

	maxLng, err := strconv.ParseFloat(c.Query("max_lng"), 64)
	if err != nil {
		response.BadRequest(c, "Invalid max_lng")
		return
	}

	filter := &BoundsFilter{
		MinLat: minLat,
		MaxLat: maxLat,
		MinLng: minLng,
		MaxLng: maxLng,
		Limit:  50, // Default
	}

	if eventType := c.Query("event_type"); eventType != "" {
		filter.EventType = &eventType
	}

	if language := c.Query("language"); language != "" {
		filter.Language = &language
	}

	if limit := c.Query("limit"); limit != "" {
		if l, err := strconv.Atoi(limit); err == nil {
			filter.Limit = l
		}
	}

	events, err := h.service.FindInBounds(filter)
	if err != nil {
		response.InternalServerError(c, "Failed to search events")
		return
	}

	response.Success(c, events)
}
