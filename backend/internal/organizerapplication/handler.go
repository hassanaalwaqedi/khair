package organizerapplication

import (
	"bytes"
	"database/sql"
	"encoding/binary"
	"errors"
	"fmt"
	"image"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/middleware"
	"github.com/khair/backend/pkg/response"
)

type Handler struct{ service *Service }

func NewHandler(service *Service) *Handler { return &Handler{service: service} }

func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	public := r.Group("/organizer/application/public")
	public.GET("/:id/logo", h.PublicLogo)

	application := r.Group("/organizer/application")
	application.Use(authMiddleware)
	{
		application.GET("/me", h.GetMine)
		application.PUT("/me", h.SaveDraft)
		application.POST("/me/submit", h.Submit)
		application.POST("/me/resubmit", h.Resubmit)
		application.POST("/me/logo", h.UploadLogo)
		application.POST("/me/representative-photo", h.UploadRepresentativePhoto)
		application.POST("/me/documents", h.UploadDocument)
	}

	admin := r.Group("/admin/organizer-applications")
	admin.Use(authMiddleware, middleware.AdminOnly())
	{
		admin.GET("", h.ListForAdmin)
		admin.GET("/:id", h.GetForAdmin)
		admin.POST("/:id/approve", h.Approve)
		admin.POST("/:id/request-changes", h.RequestChanges)
		admin.POST("/:id/reject", h.Reject)
		admin.POST("/:id/media/:kind/access", h.MediaAccess)
		admin.POST("/:id/documents/:fileId/access", h.DocumentAccess)
	}
}

func (h *Handler) GetMine(c *gin.Context) {
	app, err := h.service.GetMine(c.Request.Context(), currentUserID(c))
	if errors.Is(err, sql.ErrNoRows) {
		response.NotFound(c, "No organizer application yet")
		return
	}
	if err != nil {
		response.InternalServerError(c, "Could not load organizer application")
		return
	}
	response.Success(c, app)
}

func (h *Handler) SaveDraft(c *gin.Context) {
	var input DraftInput
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Enter valid organizer application details")
		return
	}
	app, err := h.service.SaveDraft(c.Request.Context(), currentUserID(c), input)
	if err != nil {
		applicationError(c, err)
		return
	}
	response.Success(c, app)
}

func (h *Handler) Submit(c *gin.Context)   { h.submit(c, false) }
func (h *Handler) Resubmit(c *gin.Context) { h.submit(c, true) }
func (h *Handler) submit(c *gin.Context, resubmission bool) {
	app, err := h.service.Submit(c.Request.Context(), currentUserID(c), resubmission)
	if err != nil {
		applicationError(c, err)
		return
	}
	response.SuccessWithMessage(c, "Organizer application submitted for review", app)
}

func (h *Handler) UploadLogo(c *gin.Context)                { h.uploadImage(c, "logo") }
func (h *Handler) UploadRepresentativePhoto(c *gin.Context) { h.uploadImage(c, "representative photo") }
func (h *Handler) uploadImage(c *gin.Context, kind string) {
	filename, mime, data, err := readMultipartFile(c, "file", 5*1024*1024)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	if err := validateImageDimensions(data, mime); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	var app *Application
	if kind == "logo" {
		app, err = h.service.UploadLogo(c.Request.Context(), currentUserID(c), filename, mime, data)
	} else {
		app, err = h.service.UploadRepresentativePhoto(c.Request.Context(), currentUserID(c), filename, mime, data)
	}
	if err != nil {
		applicationError(c, err)
		return
	}
	response.Success(c, app)
}

func (h *Handler) UploadDocument(c *gin.Context) {
	filename, mime, data, err := readMultipartFile(c, "file", 10*1024*1024)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	file, err := h.service.UploadVerificationFile(c.Request.Context(), currentUserID(c), strings.TrimSpace(c.PostForm("file_type")), strings.TrimSpace(c.PostForm("note")), filename, mime, data)
	if err != nil {
		applicationError(c, err)
		return
	}
	response.Created(c, file)
}

func (h *Handler) ListForAdmin(c *gin.Context) {
	status := strings.TrimSpace(c.Query("status"))
	if status != "" && !isKnownStatus(status) {
		response.BadRequest(c, "Invalid organizer application status")
		return
	}
	apps, err := h.service.ListForAdmin(c.Request.Context(), status)
	if err != nil {
		response.InternalServerError(c, "Could not load organizer applications")
		return
	}
	response.Success(c, apps)
}

func (h *Handler) GetForAdmin(c *gin.Context) {
	applicationID, ok := requiredUUID(c, "id")
	if !ok {
		return
	}
	app, err := h.service.GetForAdmin(c.Request.Context(), applicationID)
	if errors.Is(err, sql.ErrNoRows) {
		response.NotFound(c, "Organizer application not found")
		return
	}
	if err != nil {
		response.InternalServerError(c, "Could not load organizer application")
		return
	}
	response.Success(c, app.AdminView())
}

func (h *Handler) Approve(c *gin.Context)        { h.decision(c, StatusApproved) }
func (h *Handler) RequestChanges(c *gin.Context) { h.decision(c, StatusNeedsRevision) }
func (h *Handler) Reject(c *gin.Context)         { h.decision(c, StatusRejected) }
func (h *Handler) decision(c *gin.Context, decision string) {
	applicationID, ok := requiredUUID(c, "id")
	if !ok {
		return
	}
	var input DecisionInput
	if err := c.ShouldBindJSON(&input); err != nil {
		response.BadRequest(c, "Enter a valid review decision")
		return
	}
	app, err := h.service.Decide(c.Request.Context(), currentUserID(c), applicationID, decision, input)
	if err != nil {
		applicationError(c, err)
		return
	}
	response.Success(c, app.AdminView())
}

func (h *Handler) DocumentAccess(c *gin.Context) {
	applicationID, ok := requiredUUID(c, "id")
	if !ok {
		return
	}
	fileID, ok := requiredUUID(c, "fileId")
	if !ok {
		return
	}
	url, err := h.service.AdminDocumentURL(c.Request.Context(), currentUserID(c), applicationID, fileID)
	if errors.Is(err, sql.ErrNoRows) {
		response.NotFound(c, "Verification document not found")
		return
	}
	if err != nil {
		applicationError(c, err)
		return
	}
	response.Success(c, gin.H{"url": url, "expires_in_seconds": 600})
}

func (h *Handler) MediaAccess(c *gin.Context) {
	applicationID, ok := requiredUUID(c, "id")
	if !ok {
		return
	}
	url, err := h.service.AdminMediaURL(c.Request.Context(), currentUserID(c), applicationID, c.Param("kind"))
	if errors.Is(err, sql.ErrNoRows) {
		response.NotFound(c, "Organizer media not found")
		return
	}
	if err != nil {
		applicationError(c, err)
		return
	}
	response.Success(c, gin.H{"url": url, "expires_in_seconds": 600})
}

func (h *Handler) PublicLogo(c *gin.Context) {
	applicationID, ok := requiredUUID(c, "id")
	if !ok {
		return
	}
	app, err := h.service.GetForAdmin(c.Request.Context(), applicationID)
	if err != nil || app.Status != StatusApproved || app.PublicLogoKey == "" {
		response.NotFound(c, "Organizer logo not found")
		return
	}
	url, err := h.service.media.SignedGetURL(app.PublicLogoKey, 5*time.Minute)
	if err != nil {
		response.NotFound(c, "Organizer logo not available")
		return
	}
	c.Redirect(http.StatusFound, url)
}

func currentUserID(c *gin.Context) uuid.UUID {
	value, _ := c.Get("user_id")
	id, _ := value.(uuid.UUID)
	return id
}
func requiredUUID(c *gin.Context, name string) (uuid.UUID, bool) {
	id, err := uuid.Parse(c.Param(name))
	if err != nil {
		response.BadRequest(c, "Invalid identifier")
		return uuid.Nil, false
	}
	return id, true
}
func isKnownStatus(status string) bool {
	_, ok := map[string]struct{}{StatusDraft: {}, StatusPending: {}, StatusNeedsRevision: {}, StatusApproved: {}, StatusRejected: {}, StatusSuspended: {}}[status]
	return ok
}
func applicationError(c *gin.Context, err error) {
	if errors.Is(err, sql.ErrNoRows) {
		response.NotFound(c, "Organizer application not found")
		return
	}
	message := err.Error()
	lower := strings.ToLower(message)
	if strings.Contains(lower, "sql") || strings.Contains(lower, "database") ||
		strings.Contains(lower, "transaction") || strings.Contains(lower, "s3") ||
		strings.Contains(lower, "storage") || strings.Contains(lower, "aws") {
		log.Printf("[ERROR] applicationError caught generic error: %v", err)
		response.InternalServerError(c, "We could not complete that organizer application action. Please try again.")
		return
	}
	response.BadRequest(c, message)
}

func readMultipartFile(c *gin.Context, field string, limit int64) (string, string, []byte, error) {
	file, header, err := c.Request.FormFile(field)
	if err != nil {
		return "", "", nil, errors.New("select a file to upload")
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, limit+1))
	if err != nil {
		return "", "", nil, errors.New("could not read uploaded file")
	}
	if int64(len(data)) > limit {
		return "", "", nil, fmt.Errorf("file is too large; maximum is %d MB", limit/(1024*1024))
	}
	if len(data) == 0 {
		return "", "", nil, errors.New("uploaded file is empty")
	}
	return header.Filename, http.DetectContentType(data[:minInt(len(data), 512)]), data, nil
}
func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// validateImageDimensions decodes actual bytes instead of trusting the upload
// extension or multipart headers. WebP has no standard-library decoder, so its
// RIFF dimensions are read directly for VP8/VP8L/VP8X images.
func validateImageDimensions(data []byte, mime string) error {
	var width, height int
	var err error
	if mime == "image/webp" {
		width, height, err = webpDimensions(data)
	} else {
		var config image.Config
		config, _, err = image.DecodeConfig(bytes.NewReader(data))
		width, height = config.Width, config.Height
	}
	if err != nil {
		return errors.New("the uploaded image is invalid or could not be decoded")
	}
	if width < 160 || height < 160 || width > 8000 || height > 8000 {
		return errors.New("images must be between 160 and 8000 pixels on each side")
	}
	return nil
}

func webpDimensions(data []byte) (int, int, error) {
	if len(data) < 20 || string(data[:4]) != "RIFF" || string(data[8:12]) != "WEBP" {
		return 0, 0, errors.New("invalid WebP image")
	}
	for offset := 12; offset+8 <= len(data); {
		chunk := string(data[offset : offset+4])
		size := int(binary.LittleEndian.Uint32(data[offset+4 : offset+8]))
		payload := offset + 8
		if size < 0 || payload+size > len(data) {
			return 0, 0, errors.New("invalid WebP image")
		}
		part := data[payload : payload+size]
		switch chunk {
		case "VP8X":
			if len(part) >= 10 {
				width := 1 + int(part[4]) + int(part[5])<<8 + int(part[6])<<16
				height := 1 + int(part[7]) + int(part[8])<<8 + int(part[9])<<16
				return width, height, nil
			}
		case "VP8 ":
			if len(part) >= 10 && part[3] == 0x9d && part[4] == 0x01 && part[5] == 0x2a {
				width := int(binary.LittleEndian.Uint16(part[6:8]) & 0x3fff)
				height := int(binary.LittleEndian.Uint16(part[8:10]) & 0x3fff)
				return width, height, nil
			}
		case "VP8L":
			if len(part) >= 5 && part[0] == 0x2f {
				bits := binary.LittleEndian.Uint32(part[1:5])
				width := int(bits&0x3fff) + 1
				height := int((bits>>14)&0x3fff) + 1
				return width, height, nil
			}
		}
		offset = payload + size
		if size%2 == 1 {
			offset++
		}
	}
	return 0, 0, errors.New("unsupported WebP image")
}
