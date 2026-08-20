package support

import (
	"mime/multipart"
	"net/textproto"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestValidateImageAttachmentChecksMagicBytes(t *testing.T) {
	tempDir := t.TempDir()
	pngPath := filepath.Join(tempDir, "screenshot.png")
	// The PNG signature is enough for net/http content sniffing and keeps the
	// test fixture deliberately small.
	if err := os.WriteFile(pngPath, []byte{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'}, 0600); err != nil {
		t.Fatalf("write fixture: %v", err)
	}

	file, err := os.Open(pngPath)
	if err != nil {
		t.Fatalf("open fixture: %v", err)
	}
	defer file.Close()

	header := &multipart.FileHeader{
		Filename: "screenshot.png",
		Size:     8,
		Header:   textproto.MIMEHeader{"Content-Type": []string{"image/png"}},
	}
	if err := validateImageAttachment(file, header); err != nil {
		t.Fatalf("valid PNG rejected: %v", err)
	}

	if _, err := file.Seek(0, 0); err != nil {
		t.Fatalf("rewind fixture: %v", err)
	}
	spoofed := &multipart.FileHeader{
		Filename: "screenshot.jpg",
		Size:     8,
		Header:   textproto.MIMEHeader{"Content-Type": []string{"image/jpeg"}},
	}
	if err := validateImageAttachment(file, spoofed); err == nil || !strings.Contains(err.Error(), "content does not match") {
		t.Fatalf("spoofed JPEG result = %v, want content mismatch", err)
	}
}
