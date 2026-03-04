package rbac

import (
	"time"

	"github.com/google/uuid"
)

type Role struct {
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	Description *string   `json:"description,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

type Permission struct {
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	Description *string   `json:"description,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

type UserRole struct {
	UserID     uuid.UUID  `json:"user_id"`
	RoleID     uuid.UUID  `json:"role_id"`
	RoleName   string     `json:"role_name"`
	AssignedAt time.Time  `json:"assigned_at"`
	AssignedBy *uuid.UUID `json:"assigned_by,omitempty"`
}

type RoleWithPermissions struct {
	Role
	Permissions []Permission `json:"permissions"`
}

type UserWithRoles struct {
	ID         uuid.UUID  `json:"id"`
	Email      string     `json:"email"`
	Role       string     `json:"role"`
	Status     string     `json:"status"`
	IsVerified bool       `json:"is_verified"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
	Roles      []UserRole `json:"roles"`
}

type AuditLogEntry struct {
	ID             uuid.UUID  `json:"id"`
	ActorID        uuid.UUID  `json:"actor_id"`
	Action         string     `json:"action"`
	TargetUserID   *uuid.UUID `json:"target_user_id,omitempty"`
	RoleName       *string    `json:"role_name,omitempty"`
	PermissionName *string    `json:"permission_name,omitempty"`
	Details        *string    `json:"details,omitempty"`
	IPAddress      *string    `json:"-"`
	CreatedAt      time.Time  `json:"created_at"`
}

// Request types

type UpdateUserRolesRequest struct {
	Add    []string `json:"add" binding:"omitempty"`
	Remove []string `json:"remove" binding:"omitempty"`
}

type CreateRoleRequest struct {
	Name        string `json:"name" binding:"required,min=2,max=50"`
	Description string `json:"description"`
}

type AssignPermissionRequest struct {
	Permissions []string `json:"permissions" binding:"required,min=1"`
}

// Role hierarchy levels
var roleLevels = map[string]int{
	"user":        1,
	"organizer":   2,
	"admin":       3,
	"super_admin": 4,
}

func RoleLevel(name string) int {
	if lvl, ok := roleLevels[name]; ok {
		return lvl
	}
	return 0
}
