package sharing

import (
	"database/sql"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/response"
)

// EventShareData contains data for sharing an event.
type EventShareData struct {
	EventID     uuid.UUID `json:"event_id"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Slug        string    `json:"slug"`
	ImageURL    *string   `json:"image_url"`
	StartDate   string    `json:"start_date"`
	Organizer   string    `json:"organizer"`
	PublicURL   string    `json:"public_url"`
	ShareURLs   ShareURLs `json:"share_urls"`
}

// ShareURLs contains pre-built share links.
type ShareURLs struct {
	WhatsApp string `json:"whatsapp"`
	Twitter  string `json:"twitter"`
	Telegram string `json:"telegram"`
	Facebook string `json:"facebook"`
}

// Service handles social sharing and public event pages.
type Service struct {
	db      *sql.DB
	baseURL string
}

// NewService creates a new sharing service.
func NewService(db *sql.DB) *Service {
	baseURL := os.Getenv("PUBLIC_BASE_URL")
	if baseURL == "" {
		baseURL = "https://khair.it.com"
	}
	return &Service{db: db, baseURL: baseURL}
}

// GetShareData builds share data for an event.
func (s *Service) GetShareData(eventID uuid.UUID) (*EventShareData, error) {
	var data EventShareData
	var startDate time.Time
	var slug sql.NullString
	var desc sql.NullString
	var orgName sql.NullString

	err := s.db.QueryRow(`
		SELECT e.id, e.title, COALESCE(e.description, ''), e.slug, e.image_url,
		       e.start_date, COALESCE(o.name, '')
		FROM events e
		LEFT JOIN organizers o ON o.id = e.organizer_id
		WHERE e.id = $1 AND e.status = 'approved' AND e.is_published = true
	`, eventID).Scan(&data.EventID, &data.Title, &desc, &slug, &data.ImageURL, &startDate, &orgName)
	if err != nil {
		return nil, fmt.Errorf("event not found or not published")
	}

	if desc.Valid {
		data.Description = desc.String
	}
	if orgName.Valid {
		data.Organizer = orgName.String
	}
	if slug.Valid {
		data.Slug = slug.String
	}
	data.StartDate = startDate.Format(time.RFC3339)

	// Build public URL
	data.PublicURL = fmt.Sprintf("%s/events/%s", s.baseURL, data.Slug)

	// Build share URLs
	text := fmt.Sprintf("Check out \"%s\" on Khair! %s", data.Title, data.PublicURL)
	data.ShareURLs = ShareURLs{
		WhatsApp: fmt.Sprintf("https://wa.me/?text=%s", urlEncode(text)),
		Twitter:  fmt.Sprintf("https://twitter.com/intent/tweet?text=%s&url=%s", urlEncode(data.Title), urlEncode(data.PublicURL)),
		Telegram: fmt.Sprintf("https://t.me/share/url?url=%s&text=%s", urlEncode(data.PublicURL), urlEncode(data.Title)),
		Facebook: fmt.Sprintf("https://www.facebook.com/sharer/sharer.php?u=%s", urlEncode(data.PublicURL)),
	}

	// Increment view count
	s.db.Exec(`UPDATE events SET view_count = view_count + 1 WHERE id = $1`, eventID)

	return &data, nil
}

// GetPublicEventBySlug returns a public event page with OG meta tags.
func (s *Service) GetPublicEventBySlug(slug string) (*EventShareData, error) {
	var eventID uuid.UUID
	err := s.db.QueryRow(`SELECT id FROM events WHERE slug = $1 AND status = 'approved' AND is_published = true`, slug).Scan(&eventID)
	if err != nil {
		return nil, fmt.Errorf("event not found")
	}
	return s.GetShareData(eventID)
}

func urlEncode(s string) string {
	// Simple URL encoding for share links
	result := ""
	for _, c := range s {
		switch c {
		case ' ':
			result += "%20"
		case '&':
			result += "%26"
		case '?':
			result += "%3F"
		case '=':
			result += "%3D"
		case '#':
			result += "%23"
		default:
			result += string(c)
		}
	}
	return result
}

// ── Handler ──

// Handler handles sharing and public event HTTP endpoints.
type Handler struct {
	service *Service
}

// NewHandler creates a new sharing handler.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers sharing and public event routes.
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	r.GET("/events/:id/share", h.GetShareLinks)
	r.GET("/events/public/:slug", h.PublicEventPage)
}

// GetShareLinks handles GET /events/:id/share
func (h *Handler) GetShareLinks(c *gin.Context) {
	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	data, err := h.service.GetShareData(eventID)
	if err != nil {
		response.Error(c, http.StatusNotFound, "Event not found")
		return
	}
	response.Success(c, data)
}

// PublicEventPage handles GET /events/public/:slug
// Returns event data with OG meta tags + schema.org structured data.
func (h *Handler) PublicEventPage(c *gin.Context) {
	slug := c.Param("slug")

	data, err := h.service.GetPublicEventBySlug(slug)
	if err != nil {
		response.Error(c, http.StatusNotFound, "Event not found")
		return
	}

	imageURL := ""
	if data.ImageURL != nil {
		imageURL = *data.ImageURL
	}

	// Return HTML with OG tags for when crawlers hit this URL
	if c.GetHeader("Accept") == "text/html" || c.Query("format") == "html" {
		c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(fmt.Sprintf(`<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>%s - Khair</title>
<meta name="description" content="%s">
<meta property="og:title" content="%s">
<meta property="og:description" content="%s">
<meta property="og:image" content="%s">
<meta property="og:url" content="%s">
<meta property="og:type" content="website">
<meta name="twitter:card" content="summary_large_image">
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Event",
  "name": "%s",
  "description": "%s",
  "startDate": "%s",
  "organizer": {"@type": "Organization", "name": "%s"},
  "image": "%s"
}
</script>
</head>
<body><script>window.location.href='%s';</script></body>
</html>`, data.Title, data.Description, data.Title, data.Description,
			imageURL, data.PublicURL, data.Title, data.Description,
			data.StartDate, data.Organizer, imageURL, data.PublicURL)))
		return
	}

	// JSON response for API consumers
	response.Success(c, data)
}
