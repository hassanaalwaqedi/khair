// Package sharing exposes event-only public links and social metadata.
package sharing

import (
	"database/sql"
	"fmt"
	"html"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/khair/backend/pkg/response"
)

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

type ShareURLs struct {
	WhatsApp string `json:"whatsapp"`
	Twitter  string `json:"twitter"`
	Telegram string `json:"telegram"`
	Facebook string `json:"facebook"`
}

type Service struct {
	db          *sql.DB
	baseURL     string
	frontendURL string
}

func NewService(db *sql.DB) *Service {
	base := strings.TrimRight(os.Getenv("PUBLIC_BASE_URL"), "/")
	frontend := strings.TrimRight(os.Getenv("FRONTEND_URL"), "/")
	return &Service{db: db, baseURL: base, frontendURL: frontend}
}

// GetShareData builds a crawler-readable link. The public base is configured
// in production and inferred from the request only for local development.
func (s *Service) GetShareData(eventID uuid.UUID, publicBaseURL string) (*EventShareData, error) {
	var data EventShareData
	var description, organizer, slug sql.NullString
	var date time.Time
	err := s.db.QueryRow(`SELECT e.id, e.title, e.description, e.slug, e.image_url, e.start_date, o.name
		FROM events e LEFT JOIN organizers o ON o.id = e.organizer_id
		WHERE e.id = $1 AND e.status = 'approved' AND e.is_published = true`, eventID).
		Scan(&data.EventID, &data.Title, &description, &slug, &data.ImageURL, &date, &organizer)
	if err != nil {
		return nil, fmt.Errorf("event not found")
	}
	if description.Valid {
		data.Description = description.String
	}
	if slug.Valid {
		data.Slug = slug.String
	}
	if organizer.Valid {
		data.Organizer = organizer.String
	}
	data.StartDate = date.Format(time.RFC3339)
	data.PublicURL = fmt.Sprintf("%s/events/%s", strings.TrimRight(publicBaseURL, "/"), data.EventID)
	text := fmt.Sprintf("Check out %q on Khair! %s", data.Title, data.PublicURL)
	data.ShareURLs = ShareURLs{WhatsApp: "https://wa.me/?text=" + urlEncode(text), Twitter: "https://twitter.com/intent/tweet?text=" + urlEncode(text), Telegram: "https://t.me/share/url?url=" + urlEncode(data.PublicURL), Facebook: "https://www.facebook.com/sharer/sharer.php?u=" + urlEncode(data.PublicURL)}
	_, _ = s.db.Exec(`UPDATE events SET view_count = view_count + 1 WHERE id = $1`, eventID)
	return &data, nil
}

func (s *Service) ogPage(data *EventShareData) string {
	title, desc := html.EscapeString(data.Title), html.EscapeString(truncate(data.Description, 200))
	if desc == "" {
		desc = "Discover meaningful events on Khair"
	}
	image := s.frontendURL + "/icons/Icon-512.png?v=khair-k1"
	if s.frontendURL == "" {
		image = strings.TrimRight(s.baseURL, "/") + "/icons/Icon-512.png?v=khair-k1"
	}
	if data.ImageURL != nil && *data.ImageURL != "" {
		image = *data.ImageURL
		if !strings.HasPrefix(image, "http") {
			image = s.baseURL + image
		}
	}
	frontend := fmt.Sprintf("%s/#/events/%s", s.frontendURL, data.EventID)
	return fmt.Sprintf(`<!doctype html><html><head><meta charset="utf-8"><title>%s — Khair</title><meta name="description" content="%s"><meta property="og:type" content="website"><meta property="og:title" content="%s"><meta property="og:description" content="%s"><meta property="og:image" content="%s"><meta property="og:url" content="%s"><meta http-equiv="refresh" content="0;url=%s"></head><body><h1>%s</h1><p>%s</p><a href="%s">Open on Khair</a></body></html>`, title, desc, title, desc, image, data.PublicURL, frontend, title, desc, frontend)
}

type Handler struct{ service *Service }

// socialPreviewPage is intentionally server-rendered. Social crawlers do not
// execute Flutter Web or understand hash routes, so they need these tags in
// the response body of the link that users share.
func (s *Service) socialPreviewPage(data *EventShareData) string {
	title := html.EscapeString(data.Title)
	description := html.EscapeString(truncate(data.Description, 200))
	if description == "" {
		description = "Discover meaningful events on Khair"
	}

	publicOrigin := data.PublicURL
	if index := strings.LastIndex(publicOrigin, "/events/"); index >= 0 {
		publicOrigin = publicOrigin[:index]
	}
	image := s.frontendURL + "/icons/Icon-512.png?v=khair-k1"
	if s.frontendURL == "" {
		image = publicOrigin + "/icons/Icon-512.png?v=khair-k1"
	}
	if data.ImageURL != nil && *data.ImageURL != "" {
		image = *data.ImageURL
		if !strings.HasPrefix(strings.ToLower(image), "http") {
			image = strings.TrimRight(publicOrigin, "/") + image
		}
	}

	image = html.EscapeString(image)
	publicURL := html.EscapeString(data.PublicURL)
	return fmt.Sprintf(`<!doctype html><html lang="en"><head><meta charset="utf-8"><title>%s - Khair</title><meta name="description" content="%s"><meta property="og:type" content="website"><meta property="og:site_name" content="Khair"><meta property="og:title" content="%s"><meta property="og:description" content="%s"><meta property="og:image" content="%s"><meta property="og:image:secure_url" content="%s"><meta property="og:image:alt" content="%s"><meta property="og:url" content="%s"><meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="%s"><meta name="twitter:description" content="%s"><meta name="twitter:image" content="%s"><meta name="twitter:image:alt" content="%s"><link rel="canonical" href="%s"></head><body><h1>%s</h1><p>%s</p></body></html>`, title, description, title, description, image, image, title, publicURL, title, description, image, title, publicURL, title, description)
}

func NewHandler(service *Service) *Handler { return &Handler{service: service} }
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	r.GET("/events/:id/share", h.GetShareLinks)
	r.GET("/events/public/:slug", h.PublicEventPage)
}
func (h *Handler) RegisterPublicRoutes(r *gin.Engine) { r.GET("/events/:id", h.HandleEventLink) }
func (h *Handler) HandleEventLink(c *gin.Context) {
	id := c.Param("id")
	eventID, err := uuid.Parse(id)
	if err != nil {
		err = h.service.db.QueryRow(`SELECT id FROM events WHERE slug = $1 AND status = 'approved' AND is_published = true`, id).Scan(&eventID)
	}
	if err != nil {
		c.Redirect(http.StatusFound, h.service.frontendEventURL(id))
		return
	}
	data, err := h.service.GetShareData(eventID, h.service.publicBaseURL(c.Request))
	if err != nil {
		c.Redirect(http.StatusFound, h.service.frontendEventURL(id))
		return
	}
	if isSocialBot(c.GetHeader("User-Agent")) {
		c.Header("Cache-Control", "public, max-age=300")
		c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(h.service.socialPreviewPage(data)))
		return
	}
	c.Redirect(http.StatusFound, h.service.frontendEventURL(eventID.String()))
}
func (h *Handler) GetShareLinks(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}
	data, err := h.service.GetShareData(id, h.service.publicBaseURL(c.Request))
	if err != nil {
		response.Error(c, http.StatusNotFound, "Event not found")
		return
	}
	response.Success(c, data)
}
func (h *Handler) PublicEventPage(c *gin.Context) {
	var id uuid.UUID
	if err := h.service.db.QueryRow(`SELECT id FROM events WHERE slug = $1 AND status = 'approved' AND is_published = true`, c.Param("slug")).Scan(&id); err != nil {
		response.Error(c, http.StatusNotFound, "Event not found")
		return
	}
	data, err := h.service.GetShareData(id, h.service.publicBaseURL(c.Request))
	if err != nil {
		response.Error(c, http.StatusNotFound, "Event not found")
		return
	}
	response.Success(c, data)
}
func truncate(value string, max int) string {
	if len(value) <= max {
		return value
	}
	return value[:max] + "..."
}
func urlEncode(value string) string {
	return url.QueryEscape(value)
}
func isSocialBot(agent string) bool {
	agent = strings.ToLower(agent)
	return strings.Contains(agent, "facebookexternalhit") ||
		strings.Contains(agent, "facebookcatalog") ||
		strings.Contains(agent, "meta-externalagent") ||
		strings.Contains(agent, "twitterbot") ||
		strings.Contains(agent, "linkedinbot") ||
		strings.Contains(agent, "whatsapp") ||
		strings.Contains(agent, "telegrambot") ||
		strings.Contains(agent, "discordbot") ||
		strings.Contains(agent, "slackbot") ||
		strings.Contains(agent, "pinterest") ||
		strings.Contains(agent, "skypeuripreview") ||
		strings.Contains(agent, "googlebot")
}

func (s *Service) publicBaseURL(request *http.Request) string {
	if s.baseURL != "" {
		return s.baseURL
	}

	scheme := "http"
	if request.TLS != nil {
		scheme = "https"
	}
	if forwarded := strings.Split(request.Header.Get("X-Forwarded-Proto"), ",")[0]; forwarded == "https" || forwarded == "http" {
		scheme = forwarded
	}
	if request.Host != "" {
		return fmt.Sprintf("%s://%s", scheme, request.Host)
	}
	return "https://api.khair.it.com"
}

func (s *Service) frontendEventURL(eventID string) string {
	frontend := s.frontendURL
	if frontend == "" {
		frontend = "https://khair.it.com"
	}
	return fmt.Sprintf("%s/#/events/%s", frontend, eventID)
}
