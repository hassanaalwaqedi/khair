package middleware

import (
	"github.com/gin-gonic/gin"

	"github.com/khair/backend/pkg/i18n"
)

// LanguageMiddleware resolves request locale from Accept-Language.
// Currently supported locales: en, ar.
func LanguageMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		locale := i18n.DetectLocale(c.GetHeader("Accept-Language"))
		c.Set(i18n.ContextLocaleKey, locale)
		c.Header("Content-Language", locale)
		c.Next()
	}
}
