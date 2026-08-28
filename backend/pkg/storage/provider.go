package storage

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
)

// Provider abstracts file storage (local disk or Cloudflare R2).
type Provider interface {
	Upload(file multipart.File, header *multipart.FileHeader, subDir string) (url string, err error)
}

// LocalProvider stores files on the local filesystem for development.
type LocalProvider struct {
	UploadDir string
	BaseURL   string
}

// NewLocalProvider creates a local storage provider.
func NewLocalProvider(uploadDir, baseURL string) *LocalProvider {
	os.MkdirAll(filepath.Join(uploadDir, "images"), 0755)
	os.MkdirAll(filepath.Join(uploadDir, "documents"), 0755)
	return &LocalProvider{UploadDir: uploadDir, BaseURL: baseURL}
}

func (p *LocalProvider) Upload(file multipart.File, header *multipart.FileHeader, subDir string) (string, error) {
	// Detect MIME type.
	buf := make([]byte, 512)
	n, _ := file.Read(buf)
	contentType := http.DetectContentType(buf[:n])
	if seeker, ok := file.(io.Seeker); ok {
		seeker.Seek(0, io.SeekStart)
	}

	ext := extensionForMIME(contentType)
	if ext == "" {
		return "", fmt.Errorf("unsupported file type: %s", contentType)
	}

	randomBytes := make([]byte, 16)
	rand.Read(randomBytes)
	filename := hex.EncodeToString(randomBytes) + ext

	destDir := filepath.Join(p.UploadDir, subDir)
	destPath := filepath.Join(destDir, filename)
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return "", fmt.Errorf("create upload directory: %w", err)
	}

	absDir, _ := filepath.Abs(destDir)
	absPath, _ := filepath.Abs(destPath)
	if !strings.HasPrefix(absPath, absDir) {
		return "", fmt.Errorf("invalid file path")
	}

	out, err := os.Create(destPath)
	if err != nil {
		return "", fmt.Errorf("create file: %w", err)
	}
	defer out.Close()

	if _, err := io.Copy(out, file); err != nil {
		os.Remove(destPath)
		return "", fmt.Errorf("write file: %w", err)
	}

	url := fmt.Sprintf("/api/v1/files/%s/%s", subDir, filename)
	if p.BaseURL != "" {
		url = p.BaseURL + url
	}
	return url, nil
}

// NewProvider selects Cloudflare R2 in production and local storage in development.
// Render disks are ephemeral and are intentionally never used as a production fallback.
func NewProvider(uploadDir, baseURL string) Provider {
	provider := strings.ToLower(strings.TrimSpace(os.Getenv("STORAGE_PROVIDER")))
	production := strings.EqualFold(os.Getenv("ENV"), "production") || strings.EqualFold(os.Getenv("GIN_MODE"), "release")
	if provider == "local" || (!production && provider == "") {
		return NewLocalProvider(uploadDir, baseURL)
	}

	r2, err := newR2ProviderFromEnv()
	if err != nil {
		return unavailableProvider{err: fmt.Errorf("Cloudflare R2 storage is unavailable: %w", err)}
	}
	return r2
}

func extensionForMIME(mimeType string) string {
	switch mimeType {
	case "image/jpeg":
		return ".jpg"
	case "image/png":
		return ".png"
	case "image/webp":
		return ".webp"
	case "image/gif":
		return ".gif"
	case "application/pdf":
		return ".pdf"
	default:
		return ""
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
