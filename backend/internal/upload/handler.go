package upload

import (
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"

	"github.com/khair/backend/pkg/response"
	"github.com/khair/backend/pkg/storage"
)

// Config holds upload configuration
type Config struct {
	UploadDir     string
	MaxFileSizeMB int
	BaseURL       string
}

// DefaultConfig returns default upload configuration
func DefaultConfig() Config {
	uploadDir := os.Getenv("UPLOAD_DIR")
	if uploadDir == "" {
		uploadDir = "./uploads"
	}

	return Config{
		UploadDir:     uploadDir,
		MaxFileSizeMB: 10,
		BaseURL:       "",
	}
}

// Handler handles file upload HTTP requests
type Handler struct {
	config   Config
	provider storage.Provider
}

// NewHandler creates a new upload handler
func NewHandler(config Config) *Handler {
	// Use storage.NewProvider which auto-selects Azure Blob or local
	provider := storage.NewProvider(config.UploadDir, config.BaseURL)

	return &Handler{
		config:   config,
		provider: provider,
	}
}

// Allowed MIME types for images
var allowedImageTypes = map[string]bool{
	"image/jpeg": true,
	"image/png":  true,
	"image/webp": true,
	"image/gif":  true,
}

// Allowed MIME types for documents
var allowedDocumentTypes = map[string]bool{
	"application/pdf": true,
	"image/jpeg":      true,
	"image/png":       true,
}

// RegisterRoutes registers upload routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	upload := r.Group("/upload")
	{
		// Public image upload (for registration — no auth required)
		upload.POST("/image", h.UploadImage)

		// Authenticated document upload (for verification)
		if authMiddleware != nil {
			upload.POST("/document", authMiddleware, h.UploadDocument)
		} else {
			upload.POST("/document", h.UploadDocument)
		}
	}

	// Serve uploaded files statically (fallback for local storage)
	r.Static("/files", h.config.UploadDir)
}

// UploadImage handles image upload
func (h *Handler) UploadImage(c *gin.Context) {
	file, header, err := c.Request.FormFile("image")
	if err != nil {
		response.BadRequest(c, "Image file is required")
		return
	}
	defer file.Close()

	if err := h.validateFile(header, allowedImageTypes); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	url, err := h.provider.Upload(file, header, "images")
	if err != nil {
		response.Error(c, http.StatusInternalServerError, "Failed to upload file")
		return
	}

	response.Success(c, gin.H{
		"url":      url,
		"filename": header.Filename,
	})
}

// UploadDocument handles document upload (for verification)
func (h *Handler) UploadDocument(c *gin.Context) {
	file, header, err := c.Request.FormFile("document")
	if err != nil {
		response.BadRequest(c, "Document file is required")
		return
	}
	defer file.Close()

	if err := h.validateFile(header, allowedDocumentTypes); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	url, err := h.provider.Upload(file, header, "documents")
	if err != nil {
		response.Error(c, http.StatusInternalServerError, "Failed to upload file")
		return
	}

	response.Success(c, gin.H{
		"url":      url,
		"filename": header.Filename,
	})
}

// validateFile validates file size and MIME type
func (h *Handler) validateFile(header *multipart.FileHeader, allowedTypes map[string]bool) error {
	maxBytes := int64(h.config.MaxFileSizeMB) * 1024 * 1024
	if header.Size > maxBytes {
		return fmt.Errorf("file too large, maximum size: %dMB", h.config.MaxFileSizeMB)
	}

	// Open the file to detect MIME type
	file, err := header.Open()
	if err != nil {
		return fmt.Errorf("cannot read file")
	}
	defer file.Close()

	buf := make([]byte, 512)
	n, err := file.Read(buf)
	if err != nil && err != io.EOF {
		return fmt.Errorf("cannot read file")
	}
	contentType := http.DetectContentType(buf[:n])

	if !allowedTypes[contentType] {
		return fmt.Errorf("invalid file type: %s", contentType)
	}

	return nil
}

