package middleware

import (
	"database/sql"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/config"
	"github.com/khair/backend/pkg/response"
)

// Claims represents JWT claims
type Claims struct {
	UserID string   `json:"user_id"`
	Email  string   `json:"email"`
	Role   string   `json:"role"`
	Roles  []string `json:"roles,omitempty"`
	jwt.RegisteredClaims
}

// AuthMiddleware validates JWT tokens
func AuthMiddleware(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			response.Unauthorized(c, "Authorization header is required")
			c.Abort()
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			response.Unauthorized(c, "Invalid authorization header format")
			c.Abort()
			return
		}

		tokenString := parts[1]

		token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
			return []byte(cfg.JWT.Secret), nil
		})

		if err != nil {
			response.Unauthorized(c, "Invalid token")
			c.Abort()
			return
		}

		if claims, ok := token.Claims.(*Claims); ok && token.Valid {
			uid, err := uuid.Parse(claims.UserID)
			if err != nil {
				response.Unauthorized(c, "Invalid user ID in token")
				c.Abort()
				return
			}
			c.Set("user_id", uid)
			c.Set("email", claims.Email)
			c.Set("role", claims.Role)
			c.Set("roles", claims.Roles)
			c.Next()
		} else {
			response.Unauthorized(c, "Invalid token claims")
			c.Abort()
			return
		}
	}
}

// RequireAuth is an alias for AuthMiddleware for semantic clarity
func RequireAuth(cfg *config.Config) gin.HandlerFunc {
	return AuthMiddleware(cfg)
}

// RequireRole checks that the authenticated user has a specific role
func RequireRole(roleName string) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Check new roles array first
		if rolesVal, exists := c.Get("roles"); exists {
			if roles, ok := rolesVal.([]string); ok {
				for _, r := range roles {
					if r == roleName {
						c.Next()
						return
					}
				}
			}
		}

		// Fallback to legacy single role field
		if role, exists := c.Get("role"); exists {
			if role == roleName {
				c.Next()
				return
			}
			// admin and super_admin can access anything requiring a lower role
			if role == "admin" || role == "super_admin" {
				c.Next()
				return
			}
		}

		response.Forbidden(c, "Insufficient role: "+roleName+" required")
		c.Abort()
	}
}

// RequirePermission checks that the authenticated user has a specific permission
// by querying the RBAC tables in the database
func RequirePermission(db *sql.DB, permissionName string) gin.HandlerFunc {
	return func(c *gin.Context) {
		userIDVal, exists := c.Get("user_id")
		if !exists {
			response.Unauthorized(c, "Authentication required")
			c.Abort()
			return
		}

		// Admin and super_admin bypass permission checks
		if role, exists := c.Get("role"); exists {
			if role == "admin" || role == "super_admin" {
				c.Next()
				return
			}
		}

		userID, ok := userIDVal.(uuid.UUID)
		if !ok {
			response.Unauthorized(c, "Invalid user ID")
			c.Abort()
			return
		}

		// Check cached permissions first
		if permsVal, exists := c.Get("_cached_permissions"); exists {
			if perms, ok := permsVal.(map[string]bool); ok {
				if perms[permissionName] {
					c.Next()
					return
				}
				response.Forbidden(c, "Permission denied: "+permissionName+" required")
				c.Abort()
				return
			}
		}

		// Load permissions from database
		query := `
			SELECT DISTINCT p.name
			FROM user_roles ur
			JOIN role_permissions rp ON rp.role_id = ur.role_id
			JOIN permissions p ON p.id = rp.permission_id
			WHERE ur.user_id = $1
		`
		rows, err := db.Query(query, userID)
		if err != nil {
			response.InternalServerError(c, "Failed to check permissions")
			c.Abort()
			return
		}
		defer rows.Close()

		perms := make(map[string]bool)
		for rows.Next() {
			var name string
			if err := rows.Scan(&name); err != nil {
				response.InternalServerError(c, "Failed to read permissions")
				c.Abort()
				return
			}
			perms[name] = true
		}

		// Cache permissions for this request
		c.Set("_cached_permissions", perms)

		if !perms[permissionName] {
			response.Forbidden(c, "Permission denied: "+permissionName+" required")
			c.Abort()
			return
		}

		c.Next()
	}
}

// AdminOnly middleware ensures the user has admin role (backward compatible)
func AdminOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Check roles array first
		if rolesVal, exists := c.Get("roles"); exists {
			if roles, ok := rolesVal.([]string); ok {
				for _, r := range roles {
					if r == "admin" || r == "super_admin" {
						c.Next()
						return
					}
				}
			}
		}

		// Fallback to legacy role field
		role, exists := c.Get("role")
		if !exists || (role != "admin" && role != "super_admin") {
			response.Forbidden(c, "Admin access required")
			c.Abort()
			return
		}
		c.Next()
	}
}

// OrganizerOnly middleware ensures the user has organizer role
func OrganizerOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		if rolesVal, exists := c.Get("roles"); exists {
			if roles, ok := rolesVal.([]string); ok {
				for _, r := range roles {
					if r == "organizer" || r == "admin" || r == "super_admin" {
						c.Next()
						return
					}
				}
			}
		}

		role, exists := c.Get("role")
		if !exists || (role != "organizer" && role != "admin" && role != "super_admin") {
			response.Forbidden(c, "Organizer access required")
			c.Abort()
			return
		}
		c.Next()
	}
}

// CORSMiddleware handles Cross-Origin Resource Sharing
func CORSMiddleware() gin.HandlerFunc {
	allowedOrigins := map[string]bool{}
	if frontendURL := os.Getenv("FRONTEND_URL"); frontendURL != "" {
		for _, origin := range strings.Split(frontendURL, ",") {
			normalized := normalizeOrigin(origin)
			if normalized != "" {
				allowedOrigins[normalized] = true
			}
		}
	}
	if extraOrigins := os.Getenv("CORS_ALLOWED_ORIGINS"); extraOrigins != "" {
		for _, origin := range strings.Split(extraOrigins, ",") {
			normalized := normalizeOrigin(origin)
			if normalized != "" {
				allowedOrigins[normalized] = true
			}
		}
	}

	isReleaseMode := os.Getenv("GIN_MODE") == "release"

	if !isReleaseMode {
		allowedOrigins["http://localhost:3000"] = true
		allowedOrigins["http://localhost:8080"] = true
		allowedOrigins["http://localhost:5000"] = true
	}

	return func(c *gin.Context) {
		origin := normalizeOrigin(c.GetHeader("Origin"))
		if allowedOrigins[origin] || (!isReleaseMode && isLocalDevOrigin(origin)) {
			c.Header("Access-Control-Allow-Origin", origin)
		}
		c.Header("Access-Control-Allow-Credentials", "true")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With")
		c.Header("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE, PATCH")
		c.Header("Vary", "Origin")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}

func normalizeOrigin(origin string) string {
	trimmed := strings.TrimSpace(origin)
	return strings.TrimSuffix(trimmed, "/")
}

func isLocalDevOrigin(origin string) bool {
	if origin == "" {
		return false
	}

	parsed, err := url.Parse(origin)
	if err != nil || (parsed.Scheme != "http" && parsed.Scheme != "https") {
		return false
	}

	host := parsed.Hostname()
	if host == "localhost" || host == "127.0.0.1" || host == "::1" {
		return true
	}

	ip := net.ParseIP(host)
	if ip == nil {
		return false
	}
	return ip.IsLoopback()
}
