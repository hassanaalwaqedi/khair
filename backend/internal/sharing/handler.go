package sharing

import (
	"database/sql"
	"fmt"
	"html"
	"net/http"
	"os"
	"strings"
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

// SheikhShareData contains data for sharing a sheikh profile.
type SheikhShareData struct {
	ID             uuid.UUID `json:"id"`
	Name           string    `json:"name"`
	Specialization string    `json:"specialization"`
	Bio            string    `json:"bio"`
	City           string    `json:"city"`
	Country        string    `json:"country"`
	ImageURL       *string   `json:"image_url"`
	IsVerified     bool      `json:"is_verified"`
	PublicURL      string    `json:"public_url"`
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
	db         *sql.DB
	baseURL    string
	frontendURL string
}

// NewService creates a new sharing service.
func NewService(db *sql.DB) *Service {
	baseURL := os.Getenv("PUBLIC_BASE_URL")
	if baseURL == "" {
		baseURL = "https://khair.it.com"
	}
	frontendURL := os.Getenv("FRONTEND_URL")
	if frontendURL == "" {
		frontendURL = "https://khair-it-app.web.app"
	}
	return &Service{db: db, baseURL: baseURL, frontendURL: frontendURL}
}

// isSocialBot checks if the request User-Agent belongs to a social media crawler.
func isSocialBot(userAgent string) bool {
	ua := strings.ToLower(userAgent)
	bots := []string{
		"whatsapp",
		"telegrambot",
		"twitterbot",
		"facebookexternalhit",
		"facebot",
		"linkedinbot",
		"slackbot",
		"discordbot",
		"googlebot",
		"bingbot",
		"yandexbot",
		"embedly",
		"quora link preview",
		"outbrain",
		"pinterest",
		"vkshare",
		"w3c_validator",
		"skypeuripreview",
		"applebot",
	}
	for _, bot := range bots {
		if strings.Contains(ua, bot) {
			return true
		}
	}
	return false
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

	// Build public URL — use the backend domain for OG links (bots hit this)
	data.PublicURL = fmt.Sprintf("%s/events/%s", s.baseURL, data.EventID)

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

// GetSheikhShareData builds share data for a sheikh.
func (s *Service) GetSheikhShareData(sheikhID uuid.UUID) (*SheikhShareData, error) {
	var data SheikhShareData
	var spec, bio, city, country sql.NullString

	err := s.db.QueryRow(`
		SELECT id, name, specialization, bio, city, country, image_url, is_verified
		FROM sheikhs
		WHERE id = $1
	`, sheikhID).Scan(&data.ID, &data.Name, &spec, &bio, &city, &country, &data.ImageURL, &data.IsVerified)
	if err != nil {
		return nil, fmt.Errorf("sheikh not found")
	}

	if spec.Valid {
		data.Specialization = spec.String
	}
	if bio.Valid {
		data.Bio = bio.String
	}
	if city.Valid {
		data.City = city.String
	}
	if country.Valid {
		data.Country = country.String
	}

	data.PublicURL = fmt.Sprintf("%s/sheikhs/%s", s.baseURL, data.ID)
	return &data, nil
}

// resolveImageURL converts a relative image URL to an absolute one.
func (s *Service) resolveImageURL(imgURL *string) string {
	if imgURL == nil || *imgURL == "" {
		// Default OG image — Khair branding
		return s.baseURL + "/api/v1/uploads/khair-og-default.png"
	}
	url := *imgURL
	if strings.HasPrefix(url, "http") {
		return url
	}
	return s.baseURL + url
}

// truncate limits a string to maxLen characters, adding "..." if truncated.
func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}

func urlEncode(s string) string {
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
		case '"':
			result += "%22"
		case '\'':
			result += "%27"
		default:
			result += string(c)
		}
	}
	return result
}

// ── OG HTML Templates ──

func (s *Service) buildEventOGPage(data *EventShareData) string {
	title := html.EscapeString(data.Title)
	desc := html.EscapeString(truncate(data.Description, 200))
	imageURL := s.resolveImageURL(data.ImageURL)
	organizer := html.EscapeString(data.Organizer)
	publicURL := html.EscapeString(data.PublicURL)
	frontendURL := fmt.Sprintf("%s/#/events/%s", s.frontendURL, data.EventID)

	ogDesc := desc
	if organizer != "" {
		ogDesc = fmt.Sprintf("By %s — %s", organizer, desc)
	}
	if ogDesc == "" {
		ogDesc = "Discover Islamic events on Khair"
	}

	return fmt.Sprintf(`<!DOCTYPE html>
<html lang="en" prefix="og: https://ogp.me/ns#">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s — Khair</title>
<meta name="description" content="%s">

<!-- Open Graph -->
<meta property="og:type" content="website">
<meta property="og:site_name" content="Khair">
<meta property="og:title" content="%s">
<meta property="og:description" content="%s">
<meta property="og:image" content="%s">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:url" content="%s">

<!-- Twitter Card -->
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="%s">
<meta name="twitter:description" content="%s">
<meta name="twitter:image" content="%s">

<!-- Schema.org -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Event",
  "name": "%s",
  "description": "%s",
  "startDate": "%s",
  "organizer": {"@type": "Organization", "name": "%s"},
  "image": "%s",
  "url": "%s"
}
</script>

<!-- Redirect non-bot browsers to frontend -->
<meta http-equiv="refresh" content="0;url=%s">
<link rel="canonical" href="%s">
</head>
<body>
<noscript>
  <h1>%s</h1>
  <p>%s</p>
  <p><a href="%s">Open on Khair</a></p>
</noscript>
<script>window.location.replace('%s');</script>
</body>
</html>`,
		title, ogDesc,
		title, ogDesc, imageURL, publicURL,
		title, ogDesc, imageURL,
		title, desc, data.StartDate, organizer, imageURL, publicURL,
		frontendURL, publicURL,
		title, ogDesc, frontendURL,
		frontendURL,
	)
}

func (s *Service) buildSheikhOGPage(data *SheikhShareData) string {
	name := html.EscapeString(data.Name)
	imageURL := s.resolveImageURL(data.ImageURL)
	publicURL := html.EscapeString(data.PublicURL)
	frontendURL := fmt.Sprintf("%s/#/sheikhs/%s", s.frontendURL, data.ID)

	// Build description
	parts := []string{}
	if data.Specialization != "" {
		parts = append(parts, data.Specialization)
	}
	location := ""
	if data.City != "" && data.Country != "" {
		location = data.City + ", " + data.Country
	} else if data.Country != "" {
		location = data.Country
	} else if data.City != "" {
		location = data.City
	}
	if location != "" {
		parts = append(parts, location)
	}
	if data.IsVerified {
		parts = append(parts, "✅ Verified Sheikh")
	}
	desc := strings.Join(parts, " · ")
	if desc == "" {
		desc = "Islamic scholar on Khair"
	}
	descEscaped := html.EscapeString(desc)

	bioEscaped := html.EscapeString(truncate(data.Bio, 200))
	ogDesc := descEscaped
	if bioEscaped != "" {
		ogDesc = descEscaped + " — " + bioEscaped
	}

	return fmt.Sprintf(`<!DOCTYPE html>
<html lang="en" prefix="og: https://ogp.me/ns#">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sheikh %s — Khair</title>
<meta name="description" content="%s">

<!-- Open Graph -->
<meta property="og:type" content="profile">
<meta property="og:site_name" content="Khair">
<meta property="og:title" content="Sheikh %s">
<meta property="og:description" content="%s">
<meta property="og:image" content="%s">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:url" content="%s">

<!-- Twitter Card -->
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="Sheikh %s">
<meta name="twitter:description" content="%s">
<meta name="twitter:image" content="%s">

<!-- Schema.org -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Person",
  "name": "Sheikh %s",
  "description": "%s",
  "image": "%s",
  "url": "%s"
}
</script>

<!-- Redirect non-bot browsers to frontend -->
<meta http-equiv="refresh" content="0;url=%s">
<link rel="canonical" href="%s">
</head>
<body>
<noscript>
  <h1>Sheikh %s</h1>
  <p>%s</p>
  <p><a href="%s">View on Khair</a></p>
</noscript>
<script>window.location.replace('%s');</script>
</body>
</html>`,
		name, ogDesc,
		name, ogDesc, imageURL, publicURL,
		name, ogDesc, imageURL,
		name, descEscaped, imageURL, publicURL,
		frontendURL, publicURL,
		name, ogDesc, frontendURL,
		frontendURL,
	)
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

// RegisterRoutes registers sharing API routes (under /api/v1).
func (h *Handler) RegisterRoutes(r *gin.RouterGroup) {
	r.GET("/events/:id/share", h.GetShareLinks)
	r.GET("/events/public/:slug", h.PublicEventPage)
	r.GET("/sheikhs/:id/share", h.GetSheikhShareLinks)
}

// RegisterPublicRoutes registers root-level routes for OG tag rendering
// These sit OUTSIDE /api/v1 so shared links resolve here.
func (h *Handler) RegisterPublicRoutes(r *gin.Engine) {
	r.GET("/events/:id", h.HandleEventLink)
	r.GET("/sheikhs/:id", h.HandleSheikhLink)
}

// HandleEventLink serves OG meta tags for bots, redirects users to frontend.
func (h *Handler) HandleEventLink(c *gin.Context) {
	idParam := c.Param("id")

	// Try parsing as UUID first
	eventID, err := uuid.Parse(idParam)
	if err != nil {
		// Try as slug
		var eid uuid.UUID
		err2 := h.service.db.QueryRow(
			`SELECT id FROM events WHERE slug = $1 AND status = 'approved' AND is_published = true`,
			idParam,
		).Scan(&eid)
		if err2 != nil {
			// Not found — redirect to frontend anyway (let Flutter show error)
			frontendURL := fmt.Sprintf("%s/#/events/%s", h.service.frontendURL, idParam)
			c.Redirect(http.StatusFound, frontendURL)
			return
		}
		eventID = eid
	}

	data, err := h.service.GetShareData(eventID)
	if err != nil {
		// Not found — redirect to frontend
		frontendURL := fmt.Sprintf("%s/#/events/%s", h.service.frontendURL, idParam)
		c.Redirect(http.StatusFound, frontendURL)
		return
	}

	// If social bot → serve HTML with OG tags
	if isSocialBot(c.GetHeader("User-Agent")) {
		htmlContent := h.service.buildEventOGPage(data)
		c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(htmlContent))
		return
	}

	// Regular user → redirect to frontend
	frontendURL := fmt.Sprintf("%s/#/events/%s", h.service.frontendURL, eventID)
	c.Redirect(http.StatusFound, frontendURL)
}

// HandleSheikhLink serves OG meta tags for bots, redirects users to frontend.
func (h *Handler) HandleSheikhLink(c *gin.Context) {
	idParam := c.Param("id")

	sheikhID, err := uuid.Parse(idParam)
	if err != nil {
		frontendURL := fmt.Sprintf("%s/#/sheikhs/%s", h.service.frontendURL, idParam)
		c.Redirect(http.StatusFound, frontendURL)
		return
	}

	data, err := h.service.GetSheikhShareData(sheikhID)
	if err != nil {
		frontendURL := fmt.Sprintf("%s/#/sheikhs/%s", h.service.frontendURL, idParam)
		c.Redirect(http.StatusFound, frontendURL)
		return
	}

	// If social bot → serve HTML with OG tags
	if isSocialBot(c.GetHeader("User-Agent")) {
		htmlContent := h.service.buildSheikhOGPage(data)
		c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(htmlContent))
		return
	}

	// Regular user → redirect to frontend
	frontendURL := fmt.Sprintf("%s/#/sheikhs/%s", h.service.frontendURL, sheikhID)
	c.Redirect(http.StatusFound, frontendURL)
}

// GetShareLinks handles GET /api/v1/events/:id/share
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

// GetSheikhShareLinks handles GET /api/v1/sheikhs/:id/share
func (h *Handler) GetSheikhShareLinks(c *gin.Context) {
	sheikhID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid sheikh ID")
		return
	}

	data, err := h.service.GetSheikhShareData(sheikhID)
	if err != nil {
		response.Error(c, http.StatusNotFound, "Sheikh not found")
		return
	}
	response.Success(c, data)
}

// PublicEventPage handles GET /api/v1/events/public/:slug
// Returns event data with OG meta tags + schema.org structured data.
func (h *Handler) PublicEventPage(c *gin.Context) {
	slug := c.Param("slug")

	var eventID uuid.UUID
	err := h.service.db.QueryRow(
		`SELECT id FROM events WHERE slug = $1 AND status = 'approved' AND is_published = true`,
		slug,
	).Scan(&eventID)
	if err != nil {
		response.Error(c, http.StatusNotFound, "Event not found")
		return
	}

	data, err := h.service.GetShareData(eventID)
	if err != nil {
		response.Error(c, http.StatusNotFound, "Event not found")
		return
	}

	// JSON response for API consumers
	response.Success(c, data)
}
