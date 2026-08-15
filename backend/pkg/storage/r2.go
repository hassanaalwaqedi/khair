package storage

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/url"
	"os"
	"path"
	"sort"
	"strings"
	"time"
)

// R2Provider writes public product assets (event covers, avatars, and
// verification photos) to a Cloudflare R2 bucket. Organizer evidence uses a
// different private bucket and signed URLs in organizerapplication.
//
// R2 implements the S3 API. Keeping this implementation S3-compatible also
// keeps the application portable between object-storage providers.
type R2Provider struct {
	bucket        string
	endpoint      string
	region        string
	accessKey     string
	secretKey     string
	publicBaseURL string
	httpClient    *http.Client
}

// PrivateR2Store keeps verification documents out of the public media bucket.
// It returns opaque r2:// references for database storage and issues signed
// links only from an authorized backend handler.
type PrivateR2Store struct{ provider *R2Provider }

func NewPrivateR2StoreFromEnv() (*PrivateR2Store, error) {
	bucket := strings.TrimSpace(os.Getenv("R2_PRIVATE_BUCKET"))
	endpoint := strings.TrimRight(strings.TrimSpace(os.Getenv("R2_ENDPOINT")), "/")
	accessKey := strings.TrimSpace(os.Getenv("R2_ACCESS_KEY_ID"))
	secretKey := strings.TrimSpace(os.Getenv("R2_SECRET_ACCESS_KEY"))
	region := strings.TrimSpace(os.Getenv("R2_REGION"))
	if region == "" {
		region = "auto"
	}
	if bucket == "" || endpoint == "" || accessKey == "" || secretKey == "" {
		return nil, errors.New("R2_PRIVATE_BUCKET, R2_ENDPOINT, R2_ACCESS_KEY_ID, and R2_SECRET_ACCESS_KEY are required")
	}
	endpointURL, err := url.Parse(endpoint)
	if err != nil || endpointURL.Scheme != "https" || endpointURL.Host == "" {
		return nil, errors.New("R2_ENDPOINT must be an HTTPS S3-compatible endpoint")
	}
	return &PrivateR2Store{provider: &R2Provider{
		bucket: bucket, endpoint: endpoint, region: region, accessKey: accessKey, secretKey: secretKey,
		httpClient: &http.Client{Timeout: 60 * time.Second},
	}}, nil
}

func (s *PrivateR2Store) Upload(ctx context.Context, file multipart.File, prefix string) (string, error) {
	if s == nil || s.provider == nil {
		return "", errors.New("private Cloudflare R2 storage is not configured")
	}
	data, err := io.ReadAll(file)
	if err != nil {
		return "", fmt.Errorf("read document: %w", err)
	}
	if len(data) == 0 {
		return "", errors.New("uploaded document is empty")
	}
	contentType := http.DetectContentType(data[:min(512, len(data))])
	ext := extensionForMIME(contentType)
	if ext == "" {
		return "", fmt.Errorf("unsupported document type: %s", contentType)
	}
	cleanPrefix := strings.Trim(path.Clean("/"+prefix), "/")
	if cleanPrefix == "" || cleanPrefix == "." || strings.Contains(cleanPrefix, "..") {
		return "", errors.New("invalid private upload folder")
	}
	random := make([]byte, 16)
	if _, err := rand.Read(random); err != nil {
		return "", fmt.Errorf("create document key: %w", err)
	}
	key := cleanPrefix + "/" + hex.EncodeToString(random) + ext
	if err := s.put(ctx, key, data, contentType); err != nil {
		return "", err
	}
	return "r2://" + key, nil
}

func (s *PrivateR2Store) put(ctx context.Context, key string, data []byte, contentType string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPut, s.provider.objectURL(key), bytes.NewReader(data))
	if err != nil {
		return fmt.Errorf("create private R2 upload request: %w", err)
	}
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("Content-Length", fmt.Sprintf("%d", len(data)))
	if err := s.provider.sign(req, sha256HexR2(data), time.Now().UTC()); err != nil {
		return err
	}
	resp, err := s.provider.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("upload document to Cloudflare R2: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return fmt.Errorf("private R2 upload returned status %d", resp.StatusCode)
	}
	return nil
}

func (s *PrivateR2Store) SignedURL(reference string, ttl time.Duration) (string, error) {
	if s == nil || s.provider == nil {
		return "", errors.New("private Cloudflare R2 storage is not configured")
	}
	key := strings.TrimPrefix(strings.TrimSpace(reference), "r2://")
	if key == "" || strings.Contains(key, "..") || key == reference {
		return "", errors.New("invalid private document reference")
	}
	if ttl <= 0 || ttl > 15*time.Minute {
		ttl = 10 * time.Minute
	}
	now := time.Now().UTC()
	scope := now.Format("20060102") + "/" + s.provider.region + "/s3/aws4_request"
	query := url.Values{}
	query.Set("X-Amz-Algorithm", "AWS4-HMAC-SHA256")
	query.Set("X-Amz-Credential", s.provider.accessKey+"/"+scope)
	query.Set("X-Amz-Date", now.Format("20060102T150405Z"))
	query.Set("X-Amz-Expires", fmt.Sprintf("%d", int(ttl.Seconds())))
	query.Set("X-Amz-SignedHeaders", "host")

	u, err := url.Parse(s.provider.objectURL(key))
	if err != nil {
		return "", err
	}
	u.RawQuery = query.Encode()
	canonicalRequest := strings.Join([]string{"GET", canonicalURIR2(u.EscapedPath()), canonicalQueryR2(query), "host:" + u.Host + "\n", "host", "UNSIGNED-PAYLOAD"}, "\n")
	stringToSign := strings.Join([]string{"AWS4-HMAC-SHA256", now.Format("20060102T150405Z"), scope, sha256HexR2([]byte(canonicalRequest))}, "\n")
	query.Set("X-Amz-Signature", hex.EncodeToString(hmacSHA256R2(s.provider.signingKey(now), []byte(stringToSign))))
	u.RawQuery = query.Encode()
	return u.String(), nil
}

func newR2ProviderFromEnv() (*R2Provider, error) {
	bucket := strings.TrimSpace(os.Getenv("R2_PUBLIC_BUCKET"))
	endpoint := strings.TrimRight(strings.TrimSpace(os.Getenv("R2_ENDPOINT")), "/")
	accessKey := strings.TrimSpace(os.Getenv("R2_ACCESS_KEY_ID"))
	secretKey := strings.TrimSpace(os.Getenv("R2_SECRET_ACCESS_KEY"))
	publicBaseURL := strings.TrimRight(strings.TrimSpace(os.Getenv("R2_PUBLIC_BASE_URL")), "/")
	region := strings.TrimSpace(os.Getenv("R2_REGION"))
	if region == "" {
		region = "auto"
	}

	if bucket == "" || endpoint == "" || accessKey == "" || secretKey == "" || publicBaseURL == "" {
		return nil, errors.New("R2_PUBLIC_BUCKET, R2_ENDPOINT, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, and R2_PUBLIC_BASE_URL are required")
	}
	endpointURL, err := url.Parse(endpoint)
	if err != nil || endpointURL.Scheme != "https" || endpointURL.Host == "" {
		return nil, errors.New("R2_ENDPOINT must be an HTTPS S3-compatible endpoint")
	}
	publicURL, err := url.Parse(publicBaseURL)
	if err != nil || publicURL.Scheme != "https" || publicURL.Host == "" {
		return nil, errors.New("R2_PUBLIC_BASE_URL must be an HTTPS public custom domain")
	}

	return &R2Provider{
		bucket: bucket, endpoint: endpoint, region: region, accessKey: accessKey, secretKey: secretKey,
		publicBaseURL: publicBaseURL, httpClient: &http.Client{Timeout: 60 * time.Second},
	}, nil
}

func (p *R2Provider) Upload(file multipart.File, _ *multipart.FileHeader, subDir string) (string, error) {
	data, err := io.ReadAll(file)
	if err != nil {
		return "", fmt.Errorf("read upload: %w", err)
	}
	if len(data) == 0 {
		return "", errors.New("uploaded file is empty")
	}

	contentType := http.DetectContentType(data[:min(512, len(data))])
	ext := extensionForMIME(contentType)
	if ext == "" {
		return "", fmt.Errorf("unsupported file type: %s", contentType)
	}
	cleanDir := strings.Trim(path.Clean("/"+subDir), "/")
	if cleanDir == "" || cleanDir == "." || strings.Contains(cleanDir, "..") {
		return "", errors.New("invalid upload folder")
	}
	random := make([]byte, 16)
	if _, err := rand.Read(random); err != nil {
		return "", fmt.Errorf("create upload key: %w", err)
	}
	key := cleanDir + "/" + hex.EncodeToString(random) + ext

	req, err := http.NewRequest(http.MethodPut, p.objectURL(key), bytes.NewReader(data))
	if err != nil {
		return "", fmt.Errorf("create R2 upload request: %w", err)
	}
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("Content-Length", fmt.Sprintf("%d", len(data)))
	if err := p.sign(req, sha256HexR2(data), time.Now().UTC()); err != nil {
		return "", err
	}
	resp, err := p.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("upload to Cloudflare R2: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return "", fmt.Errorf("R2 upload returned status %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}
	return p.publicBaseURL + "/" + key, nil
}

func (p *R2Provider) objectURL(key string) string {
	return p.endpoint + "/" + p.bucket + "/" + strings.TrimPrefix(path.Clean(key), "/")
}

func (p *R2Provider) sign(req *http.Request, payloadHash string, now time.Time) error {
	req.Header.Set("x-amz-content-sha256", payloadHash)
	req.Header.Set("x-amz-date", now.Format("20060102T150405Z"))
	canonicalHeaders := "content-length:" + req.Header.Get("Content-Length") + "\n" +
		"content-type:" + req.Header.Get("Content-Type") + "\n" +
		"host:" + req.URL.Host + "\n" +
		"x-amz-content-sha256:" + payloadHash + "\n" +
		"x-amz-date:" + req.Header.Get("x-amz-date") + "\n"
	signedHeaders := "content-length;content-type;host;x-amz-content-sha256;x-amz-date"
	canonicalRequest := strings.Join([]string{req.Method, canonicalURIR2(req.URL.EscapedPath()), canonicalQueryR2(req.URL.Query()), canonicalHeaders, signedHeaders, payloadHash}, "\n")
	scope := now.Format("20060102") + "/" + p.region + "/s3/aws4_request"
	stringToSign := strings.Join([]string{"AWS4-HMAC-SHA256", now.Format("20060102T150405Z"), scope, sha256HexR2([]byte(canonicalRequest))}, "\n")
	signature := hex.EncodeToString(hmacSHA256R2(p.signingKey(now), []byte(stringToSign)))
	req.Header.Set("Authorization", "AWS4-HMAC-SHA256 Credential="+p.accessKey+"/"+scope+", SignedHeaders="+signedHeaders+", Signature="+signature)
	return nil
}

func (p *R2Provider) signingKey(now time.Time) []byte {
	dateKey := hmacSHA256R2([]byte("AWS4"+p.secretKey), []byte(now.Format("20060102")))
	regionKey := hmacSHA256R2(dateKey, []byte(p.region))
	serviceKey := hmacSHA256R2(regionKey, []byte("s3"))
	return hmacSHA256R2(serviceKey, []byte("aws4_request"))
}

type unavailableProvider struct{ err error }

func (p unavailableProvider) Upload(multipart.File, *multipart.FileHeader, string) (string, error) {
	return "", p.err
}

func canonicalURIR2(value string) string {
	if value == "" {
		return "/"
	}
	return value
}

func canonicalQueryR2(values url.Values) string {
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	parts := make([]string, 0, len(values))
	for _, key := range keys {
		for _, value := range values[key] {
			parts = append(parts, url.QueryEscape(key)+"="+url.QueryEscape(value))
		}
	}
	return strings.ReplaceAll(strings.Join(parts, "&"), "+", "%20")
}

func hmacSHA256R2(key, value []byte) []byte {
	mac := hmac.New(sha256.New, key)
	_, _ = mac.Write(value)
	return mac.Sum(nil)
}

func sha256HexR2(value []byte) string {
	sum := sha256.Sum256(value)
	return hex.EncodeToString(sum[:])
}
