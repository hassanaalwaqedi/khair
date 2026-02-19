package location

import (
	"net"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/khair/backend/pkg/response"
)

// Handler handles location HTTP requests
type Handler struct {
	service *Service
}

// NewHandler creates a new location handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers location routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	location := r.Group("/location")
	{
		location.GET("/resolve", h.Resolve)
	}
}

// Resolve resolves a location from coordinates or IP
// @Summary Resolve location
// @Description Resolve country, city, and timezone from coordinates or IP
// @Tags location
// @Accept json
// @Produce json
// @Param lat query number false "Latitude"
// @Param lng query number false "Longitude"
// @Success 200 {object} LocationResult
// @Router /location/resolve [get]
func (h *Handler) Resolve(c *gin.Context) {
	latStr := c.Query("lat")
	lngStr := c.Query("lng")

	// If coordinates provided, use reverse geocoding
	if latStr != "" && lngStr != "" {
		lat, err := strconv.ParseFloat(latStr, 64)
		if err != nil {
			response.BadRequest(c, "Invalid latitude")
			return
		}

		lng, err := strconv.ParseFloat(lngStr, 64)
		if err != nil {
			response.BadRequest(c, "Invalid longitude")
			return
		}

		result, err := h.service.ResolveByCoordinates(lat, lng)
		if err != nil {
			// Fallback to IP if Nominatim fails
			ip := getClientIP(c)
			result, err = h.service.ResolveByIP(ip)
			if err != nil {
				response.InternalServerError(c, "Failed to resolve location")
				return
			}
		}

		response.Success(c, result)
		return
	}

	// No coordinates — fallback to IP-based resolution
	ip := getClientIP(c)
	result, err := h.service.ResolveByIP(ip)
	if err != nil {
		response.InternalServerError(c, "Failed to resolve location from IP")
		return
	}

	response.Success(c, result)
}

// getClientIP extracts the real client IP from the request
func getClientIP(c *gin.Context) string {
	// Check X-Forwarded-For header first
	if xff := c.GetHeader("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		return strings.TrimSpace(parts[0])
	}

	// Check X-Real-IP
	if xri := c.GetHeader("X-Real-IP"); xri != "" {
		return xri
	}

	// Fall back to RemoteAddr
	ip, _, err := net.SplitHostPort(c.Request.RemoteAddr)
	if err != nil {
		return c.Request.RemoteAddr
	}
	return ip
}
