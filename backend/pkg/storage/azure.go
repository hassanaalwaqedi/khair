package storage

import (
	"bytes"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
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

// AzureBlobProvider uploads files to Azure Blob Storage using the REST API.
// When AZURE_STORAGE_CONNECTION is not set, it falls back to local storage.
type AzureBlobProvider struct {
	accountName   string
	accountKey    string
	containerName string
	cdnBaseURL    string
	fallback      *LocalProvider
	httpClient    *http.Client
}

// parseAzureConnectionString extracts account name and key from an Azure
// Storage connection string.
func parseAzureConnectionString(connStr string) (accountName, accountKey string) {
	for _, part := range strings.Split(connStr, ";") {
		part = strings.TrimSpace(part)
		if strings.HasPrefix(part, "AccountName=") {
			accountName = strings.TrimPrefix(part, "AccountName=")
		} else if strings.HasPrefix(part, "AccountKey=") {
			accountKey = strings.TrimPrefix(part, "AccountKey=")
		}
	}
	return
}

// NewAzureBlobProvider creates an Azure Blob Storage provider.
// If connectionString is empty, it falls back to local storage.
func NewAzureBlobProvider(connectionString, containerName, cdnBaseURL string, fallback *LocalProvider) *AzureBlobProvider {
	accountName, accountKey := parseAzureConnectionString(connectionString)

	if connectionString == "" || accountName == "" || accountKey == "" {
		log.Println("[STORAGE] Azure Blob not configured — using local storage")
	} else {
		log.Printf("[STORAGE] Azure Blob configured: account=%s, container=%s", accountName, containerName)
	}

	return &AzureBlobProvider{
		accountName:   accountName,
		accountKey:    accountKey,
		containerName: containerName,
		cdnBaseURL:    cdnBaseURL,
		fallback:      fallback,
		httpClient: &http.Client{
			Timeout: 60 * time.Second,
		},
	}
}

func (p *AzureBlobProvider) Upload(file multipart.File, header *multipart.FileHeader, subDir string) (string, error) {
	if p.accountName == "" || p.accountKey == "" {
		return p.fallback.Upload(file, header, subDir)
	}

	// Read file content
	data, err := io.ReadAll(file)
	if err != nil {
		return "", fmt.Errorf("read file: %w", err)
	}

	// Detect MIME type
	contentType := http.DetectContentType(data[:min(512, len(data))])
	ext := extensionForMIME(contentType)
	if ext == "" {
		return "", fmt.Errorf("unsupported file type: %s", contentType)
	}

	// Generate random filename
	randomBytes := make([]byte, 16)
	rand.Read(randomBytes)
	blobName := fmt.Sprintf("%s/%s%s", subDir, hex.EncodeToString(randomBytes), ext)

	// Upload to Azure Blob Storage using PUT Blob REST API
	blobURL := fmt.Sprintf("https://%s.blob.core.windows.net/%s/%s",
		p.accountName, p.containerName, blobName)

	req, err := http.NewRequest(http.MethodPut, blobURL, bytes.NewReader(data))
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}

	now := time.Now().UTC().Format(http.TimeFormat)
	req.Header.Set("x-ms-date", now)
	req.Header.Set("x-ms-version", "2023-11-03")
	req.Header.Set("x-ms-blob-type", "BlockBlob")
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("Content-Length", fmt.Sprintf("%d", len(data)))

	// Sign the request with Shared Key authentication
	authHeader, err := p.signRequest(req, len(data))
	if err != nil {
		return "", fmt.Errorf("sign request: %w", err)
	}
	req.Header.Set("Authorization", authHeader)

	resp, err := p.httpClient.Do(req)
	if err != nil {
		log.Printf("[STORAGE] Azure upload failed, falling back to local: %v", err)
		if seeker, ok := file.(io.Seeker); ok {
			seeker.Seek(0, io.SeekStart)
		}
		return p.fallback.Upload(file, header, subDir)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		log.Printf("[STORAGE] Azure upload returned %d: %s, falling back to local", resp.StatusCode, string(body))
		// Fall back to local on Azure errors
		if seeker, ok := file.(io.Seeker); ok {
			seeker.Seek(0, io.SeekStart)
		}
		return p.fallback.Upload(file, header, subDir)
	}

	// Return the public blob URL
	publicURL := blobURL
	if p.cdnBaseURL != "" {
		publicURL = fmt.Sprintf("%s/%s/%s", strings.TrimSuffix(p.cdnBaseURL, "/"), p.containerName, blobName)
	}

	log.Printf("[STORAGE] Uploaded to Azure Blob: %s", publicURL)
	return publicURL, nil
}

// signRequest creates a Shared Key authorization header for Azure Blob Storage.
func (p *AzureBlobProvider) signRequest(req *http.Request, contentLength int) (string, error) {
	// Build the string to sign per Azure Storage REST API spec
	// https://learn.microsoft.com/en-us/rest/api/storageservices/authorize-with-shared-key
	canonicalizedHeaders := fmt.Sprintf("x-ms-blob-type:%s\nx-ms-date:%s\nx-ms-version:%s",
		req.Header.Get("x-ms-blob-type"),
		req.Header.Get("x-ms-date"),
		req.Header.Get("x-ms-version"))

	canonicalizedResource := fmt.Sprintf("/%s/%s", p.accountName, strings.TrimPrefix(req.URL.Path, "/"))

	stringToSign := fmt.Sprintf("%s\n\n\n%d\n\n%s\n\n\n\n\n\n\n%s\n%s",
		req.Method,
		contentLength,
		req.Header.Get("Content-Type"),
		canonicalizedHeaders,
		canonicalizedResource)

	// HMAC-SHA256 sign
	keyBytes, err := base64.StdEncoding.DecodeString(p.accountKey)
	if err != nil {
		return "", fmt.Errorf("decode account key: %w", err)
	}

	mac := hmac.New(sha256.New, keyBytes)
	mac.Write([]byte(stringToSign))
	signature := base64.StdEncoding.EncodeToString(mac.Sum(nil))

	return fmt.Sprintf("SharedKey %s:%s", p.accountName, signature), nil
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

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
