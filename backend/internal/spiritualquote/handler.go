package spiritualquote

import (
	"errors"

	"github.com/gin-gonic/gin"

	"github.com/khair/backend/pkg/response"
)

// Handler handles quote HTTP requests.
type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	quotes := r.Group("/quotes")
	{
		quotes.GET("/random", h.GetRandom)
	}
}

func (h *Handler) GetRandom(c *gin.Context) {
	location, err := ParseLocation(c.Query("location"))
	if err != nil {
		response.BadRequest(c, MessageInvalidLocation)
		return
	}

	quote, err := h.service.GetRandom(c.Request.Context(), location)
	if err != nil {
		if errors.Is(err, ErrQuoteNotFound) {
			response.NotFound(c, MessageQuoteNotFound)
			return
		}
		response.InternalServerError(c, MessageFetchFailed)
		return
	}

	response.Success(c, quote)
}
