package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// AdminMiddleware ensures the user has admin role
func AdminMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		role, exists := c.Get("userRole")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{
				"success": false,
				"error":   "Unauthorized",
			})
			c.Abort()
			return
		}

		if strings.ToLower(role.(string)) != "admin" {
			c.JSON(http.StatusForbidden, gin.H{
				"success": false,
				"error":   "Admin access required",
			})
			c.Abort()
			return
		}

		c.Next()
	}
}
