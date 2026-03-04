package upload

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/khair/backend/pkg/response"
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
	config Config
}

// NewHandler creates a new upload handler
func NewHandler(config Config) *Handler {
	// Ensure upload directories exist
	dirs := []string{
		filepath.Join(config.UploadDir, "images"),
		filepath.Join(config.UploadDir, "documents"),
	}
	for _, dir := range dirs {
		os.MkdirAll(dir, 0755)
	}

	return &Handler{config: config}
}

// Allowed MIME types for images
var allowedImageTypes = map[string]string{
	"image/jpeg": ".jpg",
	"image/png":  ".png",
	"image/webp": ".webp",
	"image/gif":  ".gif",
}

// Allowed MIME types for documents
var allowedDocumentTypes = map[string]string{
	"application/pdf": ".pdf",
	"image/jpeg":      ".jpg",
	"image/png":       ".png",
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

	// Serve uploaded files statically
	r.Static("/files", h.config.UploadDir)
}

// UploadImage handles image upload
// @Summary Upload an image
// @Tags upload
// @Accept multipart/form-data
// @Produce json
// @Param image formData file true "Image file (JPEG, PNG, WebP, GIF, max 10MB)"
// @Success 200 {object} map[string]interface{}
// @Router /upload/image [post]
func (h *Handler) UploadImage(c *gin.Context) {
	file, header, err := c.Request.FormFile("image")
	if err != nil {
		response.BadRequest(c, "Image file is required")
		return
	}
	defer file.Close()

	url, err := h.saveFile(file, header, "images", allowedImageTypes)
	if err != nil {
		if err == errInvalidType {
			response.BadRequest(c, "Invalid file type. Allowed: JPEG, PNG, WebP, GIF")
			return
		}
		if err == errFileTooLarge {
			response.BadRequest(c, fmt.Sprintf("File too large. Maximum size: %dMB", h.config.MaxFileSizeMB))
			return
		}
		response.Error(c, http.StatusInternalServerError, "Failed to save file")
		return
	}

	response.Success(c, gin.H{
		"url":      url,
		"filename": header.Filename,
	})
}

// UploadDocument handles document upload (for verification)
// @Summary Upload a verification document
// @Tags upload
// @Accept multipart/form-data
// @Produce json
// @Param document formData file true "Document file (PDF, JPEG, PNG, max 10MB)"
// @Success 200 {object} map[string]interface{}
// @Router /upload/document [post]
func (h *Handler) UploadDocument(c *gin.Context) {
	file, header, err := c.Request.FormFile("document")
	if err != nil {
		response.BadRequest(c, "Document file is required")
		return
	}
	defer file.Close()

	url, err := h.saveFile(file, header, "documents", allowedDocumentTypes)
	if err != nil {
		if err == errInvalidType {
			response.BadRequest(c, "Invalid file type. Allowed: PDF, JPEG, PNG")
			return
		}
		if err == errFileTooLarge {
			response.BadRequest(c, fmt.Sprintf("File too large. Maximum size: %dMB", h.config.MaxFileSizeMB))
			return
		}
		response.Error(c, http.StatusInternalServerError, "Failed to save file")
		return
	}

	response.Success(c, gin.H{
		"url":      url,
		"filename": header.Filename,
	})
}

// ── Internal helpers ──

var (
	errInvalidType  = fmt.Errorf("invalid file type")
	errFileTooLarge = fmt.Errorf("file too large")
)

func (h *Handler) saveFile(
	file multipart.File,
	header *multipart.FileHeader,
	subDir string,
	allowedTypes map[string]string,
) (string, error) {
	// Check file size
	maxBytes := int64(h.config.MaxFileSizeMB) * 1024 * 1024
	if header.Size > maxBytes {
		return "", errFileTooLarge
	}

	// Detect actual MIME type by reading first 512 bytes
	buf := make([]byte, 512)
	n, err := file.Read(buf)
	if err != nil && err != io.EOF {
		return "", fmt.Errorf("failed to read file: %w", err)
	}
	contentType := http.DetectContentType(buf[:n])

	// Reset file reader position
	if seeker, ok := file.(io.Seeker); ok {
		seeker.Seek(0, io.SeekStart)
	}

	// Validate MIME type
	ext, ok := allowedTypes[contentType]
	if !ok {
		return "", errInvalidType
	}

	// Generate secure random filename
	randomBytes := make([]byte, 16)
	if _, err := rand.Read(randomBytes); err != nil {
		return "", fmt.Errorf("failed to generate filename: %w", err)
	}
	randomName := hex.EncodeToString(randomBytes)
	filename := randomName + ext

	// Build file path
	destDir := filepath.Join(h.config.UploadDir, subDir)
	destPath := filepath.Join(destDir, filename)

	// Prevent path traversal
	absDestDir, _ := filepath.Abs(destDir)
	absDestPath, _ := filepath.Abs(destPath)
	if !strings.HasPrefix(absDestPath, absDestDir) {
		return "", fmt.Errorf("invalid file path")
	}

	// Save file
	out, err := os.Create(destPath)
	if err != nil {
		return "", fmt.Errorf("failed to create file: %w", err)
	}
	defer out.Close()

	if _, err := io.Copy(out, file); err != nil {
		os.Remove(destPath)
		return "", fmt.Errorf("failed to write file: %w", err)
	}

	// Build URL
	url := fmt.Sprintf("/api/v1/files/%s/%s", subDir, filename)
	if h.config.BaseURL != "" {
		url = h.config.BaseURL + url
	}

	return url, nil
}
