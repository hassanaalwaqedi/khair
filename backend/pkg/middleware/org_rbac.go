package middleware

import (
	"database/sql"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/internal/models"
	"github.com/khair/backend/pkg/response"
)

// OrgRBAC middleware validates that the authenticated user has the required
// organization role. It extracts org_id from the URL path parameter and
// looks up the user's membership in organization_members.
//
// Usage:
//
//	group.Use(middleware.OrgRBAC(db, "event_manager"))  // requires event_manager+
//	group.Use(middleware.OrgRBAC(db, "owner"))           // requires owner only
func OrgRBAC(db *sql.DB, requiredRole string) gin.HandlerFunc {
	requiredLevel := models.OrgRoleLevel(requiredRole)

	return func(c *gin.Context) {
		// 1. Get authenticated user ID
		userIDVal, exists := c.Get("user_id")
		if !exists {
			response.Unauthorized(c, "Authentication required")
			c.Abort()
			return
		}

		userID, ok := userIDVal.(uuid.UUID)
		if !ok {
			// Try string fallback (some middleware sets string)
			if s, ok := userIDVal.(string); ok {
				var err error
				userID, err = uuid.Parse(s)
				if err != nil {
					response.Unauthorized(c, "Invalid user ID")
					c.Abort()
					return
				}
			} else {
				response.Unauthorized(c, "Invalid user ID type")
				c.Abort()
				return
			}
		}

		// 2. Allow system admins to bypass org RBAC
		if role, _ := c.Get("role"); role == "admin" {
			c.Set("org_role", models.OrgRoleOwner)
			// Still need to parse org_id
			orgIDStr := c.Param("org_id")
			if orgIDStr == "" {
				response.BadRequest(c, "Organization ID is required")
				c.Abort()
				return
			}
			orgID, err := uuid.Parse(orgIDStr)
			if err != nil {
				response.BadRequest(c, "Invalid organization ID")
				c.Abort()
				return
			}
			c.Set("org_id", orgID)
			c.Next()
			return
		}

		// 3. Parse org_id from URL
		orgIDStr := c.Param("org_id")
		if orgIDStr == "" {
			response.BadRequest(c, "Organization ID is required")
			c.Abort()
			return
		}

		orgID, err := uuid.Parse(orgIDStr)
		if err != nil {
			response.BadRequest(c, "Invalid organization ID")
			c.Abort()
			return
		}

		// 4. Look up membership
		var memberRole string
		err = db.QueryRow(
			`SELECT role FROM organization_members WHERE organization_id = $1 AND user_id = $2`,
			orgID, userID,
		).Scan(&memberRole)

		if err == sql.ErrNoRows {
			response.Forbidden(c, "You are not a member of this organization")
			c.Abort()
			return
		}
		if err != nil {
			response.InternalServerError(c, "Failed to check organization membership")
			c.Abort()
			return
		}

		// 5. Check permission level
		userLevel := models.OrgRoleLevel(memberRole)
		if userLevel < requiredLevel {
			response.Forbidden(c, "Insufficient organization permissions")
			c.Abort()
			return
		}

		// 6. Set context values for downstream handlers
		c.Set("org_id", orgID)
		c.Set("org_role", memberRole)
		c.Next()
	}
}
