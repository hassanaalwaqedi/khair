// Package brand exposes the approved Khair assets from the deployed API.
package brand

import (
	_ "embed"
	"net/http"

	"github.com/gin-gonic/gin"
)

// EmailLogo is the approved full-field rose K asset. It is embedded so email
// clients can request it over the same stable HTTPS origin as the API.
//
//go:embed assets/khair_logo_email.png
var EmailLogo []byte

// ServeEmailLogo serves the stable email brand asset with cache-safe headers.
func ServeEmailLogo(c *gin.Context) {
	c.Header("Cache-Control", "public, max-age=31536000, immutable")
	c.Data(http.StatusOK, "image/png", EmailLogo)
}
