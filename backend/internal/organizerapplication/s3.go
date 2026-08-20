package organizerapplication

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path"
	"sort"
	"strings"
	"time"
)

// S3Store intentionally has no local fallback. Organizer evidence is sensitive
// and must never silently become a local or public file in production.
type S3Store struct {
	bucket        string
	region        string
	accessKey     string
	secretKey     string
	endpoint      string
	publicBaseURL string
	httpClient    *http.Client
}

func NewS3StoreFromEnv() *S3Store {
	region := firstConfiguredEnv("R2_REGION", "AWS_REGION")
	if region == "" {
		region = "auto"
	}
	endpoint := strings.TrimSuffix(firstConfiguredEnv("R2_ENDPOINT", "AWS_S3_ENDPOINT"), "/")
	if endpoint == "" {
		endpoint = fmt.Sprintf("https://s3.%s.amazonaws.com", region)
	}
	return &S3Store{
		bucket: firstConfiguredEnv("R2_PRIVATE_BUCKET", "AWS_S3_BUCKET"), region: region,
		accessKey: firstConfiguredEnv("R2_ACCESS_KEY_ID", "AWS_ACCESS_KEY_ID"), secretKey: firstConfiguredEnv("R2_SECRET_ACCESS_KEY", "AWS_SECRET_ACCESS_KEY"),
		endpoint: endpoint, publicBaseURL: strings.TrimSuffix(os.Getenv("PUBLIC_BASE_URL"), "/"),
		httpClient: &http.Client{Timeout: 60 * time.Second},
	}
}

func (s *S3Store) configured() bool { return s.bucket != "" && s.accessKey != "" && s.secretKey != "" }

func firstConfiguredEnv(keys ...string) string {
	for _, key := range keys {
		if value := strings.TrimSpace(os.Getenv(key)); value != "" {
			return value
		}
	}
	return ""
}

func (s *S3Store) Put(ctx context.Context, key string, data []byte, contentType string) error {
	if !s.configured() {
		return errors.New("private S3-compatible organizer storage is not configured")
	}
	if key == "" || strings.HasPrefix(key, "/") || strings.Contains(key, "..") {
		return errors.New("invalid storage key")
	}
	url := s.objectURL(key)
	req, err := http.NewRequestWithContext(ctx, http.MethodPut, url, bytes.NewReader(data))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", contentType)
	// Never set a public ACL. Modern S3 buckets commonly enforce Bucket owner
	// ownership and reject ACL headers altogether; access is controlled by the
	// bucket policy plus signed URLs after the application's approval check.
	req.Header.Set("Content-Length", fmt.Sprintf("%d", len(data)))
	if err := s.sign(req, sha256Hex(data), time.Now().UTC()); err != nil {
		return err
	}
	response, err := s.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("upload organizer media to S3: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(response.Body)
		return fmt.Errorf("S3 upload returned status %d: %s", response.StatusCode, string(bodyBytes))
	}
	return nil
}

// Delete removes an object after a successful replacement. Missing objects
// are treated as success so cleanup remains safe and idempotent.
func (s *S3Store) Delete(ctx context.Context, key string) error {
	if !s.configured() {
		return errors.New("private S3-compatible organizer storage is not configured")
	}
	if key == "" || strings.HasPrefix(key, "/") || strings.Contains(key, "..") {
		return errors.New("invalid storage key")
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, s.objectURL(key), nil)
	if err != nil {
		return err
	}
	if err := s.sign(req, sha256Hex(nil), time.Now().UTC()); err != nil {
		return err
	}
	response, err := s.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("delete organizer media from S3: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode == http.StatusNotFound ||
		(response.StatusCode >= 200 && response.StatusCode < 300) {
		return nil
	}
	bodyBytes, _ := io.ReadAll(response.Body)
	return fmt.Errorf("S3 delete returned status %d: %s", response.StatusCode, string(bodyBytes))
}

// SignedGetURL is used only after authorization in admin/document handlers.
func (s *S3Store) SignedGetURL(key string, ttl time.Duration) (string, error) {
	if !s.configured() {
		return "", errors.New("private S3-compatible organizer storage is not configured")
	}
	if key == "" || strings.Contains(key, "..") {
		return "", errors.New("invalid storage key")
	}
	if ttl <= 0 || ttl > 15*time.Minute {
		ttl = 10 * time.Minute
	}
	now := time.Now().UTC()
	credentialScope := fmt.Sprintf("%s/%s/s3/aws4_request", now.Format("20060102"), s.region)
	query := url.Values{}
	query.Set("X-Amz-Algorithm", "AWS4-HMAC-SHA256")
	query.Set("X-Amz-Credential", s.accessKey+"/"+credentialScope)
	query.Set("X-Amz-Date", now.Format("20060102T150405Z"))
	query.Set("X-Amz-Expires", fmt.Sprintf("%d", int(ttl.Seconds())))
	query.Set("X-Amz-SignedHeaders", "host")

	u, err := url.Parse(s.objectURL(key))
	if err != nil {
		return "", err
	}
	u.RawQuery = query.Encode()
	canonicalRequest := strings.Join([]string{
		"GET", canonicalURI(u.EscapedPath()), canonicalQuery(query), "host:" + u.Host + "\n", "host", "UNSIGNED-PAYLOAD",
	}, "\n")
	stringToSign := strings.Join([]string{
		"AWS4-HMAC-SHA256", now.Format("20060102T150405Z"), credentialScope, sha256Hex([]byte(canonicalRequest)),
	}, "\n")
	signature := hex.EncodeToString(hmacSHA256(s.signingKey(now), []byte(stringToSign)))
	query.Set("X-Amz-Signature", signature)
	u.RawQuery = query.Encode()
	return u.String(), nil
}

func (s *S3Store) objectURL(key string) string {
	// Path-style URLs work for AWS S3 and S3-compatible storage endpoints.
	return strings.TrimSuffix(s.endpoint, "/") + "/" + s.bucket + "/" + strings.TrimPrefix(path.Clean(key), "/")
}

func (s *S3Store) sign(req *http.Request, payloadHash string, now time.Time) error {
	req.Header.Set("x-amz-content-sha256", payloadHash)
	req.Header.Set("x-amz-date", now.Format("20060102T150405Z"))
	canonicalHeaders := "content-length:" + req.Header.Get("Content-Length") + "\n" +
		"content-type:" + req.Header.Get("Content-Type") + "\n" +
		"host:" + req.URL.Host + "\n" +
		"x-amz-content-sha256:" + payloadHash + "\n" +
		"x-amz-date:" + req.Header.Get("x-amz-date") + "\n"
	signedHeaders := "content-length;content-type;host;x-amz-content-sha256;x-amz-date"
	canonicalRequest := strings.Join([]string{req.Method, canonicalURI(req.URL.EscapedPath()), canonicalQuery(req.URL.Query()), canonicalHeaders, signedHeaders, payloadHash}, "\n")
	date := now.Format("20060102")
	scope := date + "/" + s.region + "/s3/aws4_request"
	stringToSign := strings.Join([]string{"AWS4-HMAC-SHA256", now.Format("20060102T150405Z"), scope, sha256Hex([]byte(canonicalRequest))}, "\n")
	signature := hex.EncodeToString(hmacSHA256(s.signingKey(now), []byte(stringToSign)))
	req.Header.Set("Authorization", "AWS4-HMAC-SHA256 Credential="+s.accessKey+"/"+scope+", SignedHeaders="+signedHeaders+", Signature="+signature)
	return nil
}

func (s *S3Store) signingKey(now time.Time) []byte {
	dateKey := hmacSHA256([]byte("AWS4"+s.secretKey), []byte(now.Format("20060102")))
	regionKey := hmacSHA256(dateKey, []byte(s.region))
	serviceKey := hmacSHA256(regionKey, []byte("s3"))
	return hmacSHA256(serviceKey, []byte("aws4_request"))
}

func canonicalURI(value string) string {
	if value == "" {
		return "/"
	}
	return value
}
func canonicalQuery(values url.Values) string {
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	parts := make([]string, 0, len(keys))
	for _, key := range keys {
		valuesForKey := append([]string(nil), values[key]...)
		sort.Strings(valuesForKey)
		for _, value := range valuesForKey {
			parts = append(parts, url.QueryEscape(key)+"="+url.QueryEscape(value))
		}
	}
	return strings.ReplaceAll(strings.Join(parts, "&"), "+", "%20")
}
func hmacSHA256(key, value []byte) []byte {
	mac := hmac.New(sha256.New, key)
	_, _ = mac.Write(value)
	return mac.Sum(nil)
}
func sha256Hex(value []byte) string { sum := sha256.Sum256(value); return hex.EncodeToString(sum[:]) }
