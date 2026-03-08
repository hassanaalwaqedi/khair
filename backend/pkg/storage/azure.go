package storage

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// Provider abstracts file storage (local disk or cloud).
type Provider interface {
	Upload(file multipart.File, header *multipart.FileHeader, subDir string) (url string, err error)
}

// ── Local provider (default) ──

// LocalProvider stores files on the local filesystem.
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
	// Detect MIME type
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

	// Random filename
	randomBytes := make([]byte, 16)
	rand.Read(randomBytes)
	filename := hex.EncodeToString(randomBytes) + ext

	destDir := filepath.Join(p.UploadDir, subDir)
	destPath := filepath.Join(destDir, filename)

	// Path traversal check
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

// ── Azure Blob Storage provider ──

// AzureBlobProvider uploads files to Azure Blob Storage.
// When AZURE_STORAGE_CONNECTION is not set, it falls back to local storage.
type AzureBlobProvider struct {
	connectionString string
	containerName    string
	cdnBaseURL       string
	fallback         *LocalProvider
}

// NewAzureBlobProvider creates an Azure Blob Storage provider.
// If connectionString is empty, it falls back to local storage.
func NewAzureBlobProvider(connectionString, containerName, cdnBaseURL string, fallback *LocalProvider) *AzureBlobProvider {
	if connectionString == "" {
		log.Println("[STORAGE] Azure Blob not configured — using local storage")
	} else {
		log.Printf("[STORAGE] Azure Blob configured: container=%s", containerName)
	}
	return &AzureBlobProvider{
		connectionString: connectionString,
		containerName:    containerName,
		cdnBaseURL:       cdnBaseURL,
		fallback:         fallback,
	}
}

func (p *AzureBlobProvider) Upload(file multipart.File, header *multipart.FileHeader, subDir string) (string, error) {
	if p.connectionString == "" {
		return p.fallback.Upload(file, header, subDir)
	}

	// TODO: Implement actual Azure Blob SDK upload when azure-sdk-for-go is added.
	// For now, uses local fallback with CDN URL rewriting.
	url, err := p.fallback.Upload(file, header, subDir)
	if err != nil {
		return "", err
	}

	// Rewrite URL to CDN if configured
	if p.cdnBaseURL != "" {
		url = p.cdnBaseURL + url
	}
	return url, nil
}

// NewProvider creates the appropriate storage provider based on environment.
func NewProvider(uploadDir, baseURL string) Provider {
	local := NewLocalProvider(uploadDir, baseURL)

	azureConn := os.Getenv("AZURE_STORAGE_CONNECTION")
	azureContainer := os.Getenv("AZURE_STORAGE_CONTAINER")
	cdnURL := os.Getenv("CDN_BASE_URL")

	if azureConn != "" {
		if azureContainer == "" {
			azureContainer = "uploads"
		}
		return NewAzureBlobProvider(azureConn, azureContainer, cdnURL, local)
	}

	return local
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
