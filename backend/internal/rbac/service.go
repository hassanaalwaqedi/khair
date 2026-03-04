package rbac

import (
	"errors"
	"strings"

	"github.com/google/uuid"
)

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// GetUserRoles returns role names for a user
func (s *Service) GetUserRoles(userID uuid.UUID) ([]string, error) {
	return s.repo.GetUserRoles(userID)
}

// GetUserPermissions returns all permission names for a user
func (s *Service) GetUserPermissions(userID uuid.UUID) ([]string, error) {
	return s.repo.GetUserPermissions(userID)
}

// HasPermission checks if a user has a specific permission
func (s *Service) HasPermission(userID uuid.UUID, permissionName string) (bool, error) {
	return s.repo.HasPermission(userID, permissionName)
}

// HasRole checks if a user has a specific role
func (s *Service) HasRole(userID uuid.UUID, roleName string) (bool, error) {
	return s.repo.HasRole(userID, roleName)
}

// ListRoles returns all roles with their permissions
func (s *Service) ListRoles() ([]RoleWithPermissions, error) {
	return s.repo.ListRoles()
}

// CreateRole creates a new role with validation
func (s *Service) CreateRole(name, description string) (*Role, error) {
	name = strings.TrimSpace(strings.ToLower(name))
	if name == "" {
		return nil, errors.New("role name is required")
	}
	if len(name) < 2 || len(name) > 50 {
		return nil, errors.New("role name must be between 2 and 50 characters")
	}
	return s.repo.CreateRole(name, description)
}

// GetRoleByID returns a role by ID
func (s *Service) GetRoleByID(id uuid.UUID) (*Role, error) {
	return s.repo.GetRoleByID(id)
}

// AssignPermissionsToRole assigns permissions to a role
func (s *Service) AssignPermissionsToRole(roleID uuid.UUID, permissions []string, actorID uuid.UUID, ipAddress *string) error {
	for _, p := range permissions {
		if strings.TrimSpace(p) == "" {
			return errors.New("permission name cannot be empty")
		}
	}

	if err := s.repo.AssignPermissionToRole(roleID, permissions); err != nil {
		return err
	}

	role, _ := s.repo.GetRoleByID(roleID)
	roleName := ""
	if role != nil {
		roleName = role.Name
	}

	for _, p := range permissions {
		pName := p
		rName := roleName
		_ = s.repo.LogRoleChange(actorID, "assign_permission", nil, &rName, &pName, ipAddress, map[string]string{
			"role_id":    roleID.String(),
			"permission": p,
		})
	}

	return nil
}

// UpdateUserRoles adds/removes roles for a user with security validation
func (s *Service) UpdateUserRoles(targetUserID uuid.UUID, req *UpdateUserRolesRequest, actorID uuid.UUID, actorRoles []string, ipAddress *string) error {
	if len(req.Add) == 0 && len(req.Remove) == 0 {
		return errors.New("must specify at least one role to add or remove")
	}

	actorMaxLevel := 0
	for _, r := range actorRoles {
		if lvl := RoleLevel(r); lvl > actorMaxLevel {
			actorMaxLevel = lvl
		}
	}

	// Prevent role escalation: actor cannot assign roles at or above their own level
	for _, roleName := range req.Add {
		roleLevel := RoleLevel(roleName)
		if roleLevel >= actorMaxLevel {
			return errors.New("cannot assign role at or above your own level: " + roleName)
		}
	}

	// Prevent removing super_admin from yourself
	if targetUserID == actorID {
		for _, roleName := range req.Remove {
			if roleName == "super_admin" {
				return errors.New("cannot remove super_admin role from yourself")
			}
		}
	}

	// Prevent removing roles above actor's level
	for _, roleName := range req.Remove {
		roleLevel := RoleLevel(roleName)
		if roleLevel >= actorMaxLevel {
			return errors.New("cannot remove role at or above your own level: " + roleName)
		}
	}

	for _, roleName := range req.Add {
		if err := s.repo.AssignRole(targetUserID, roleName, actorID); err != nil {
			return err
		}
		rn := roleName
		_ = s.repo.LogRoleChange(actorID, "assign_role", &targetUserID, &rn, nil, ipAddress, nil)
	}

	for _, roleName := range req.Remove {
		if err := s.repo.RemoveRole(targetUserID, roleName); err != nil {
			return err
		}
		rn := roleName
		_ = s.repo.LogRoleChange(actorID, "remove_role", &targetUserID, &rn, nil, ipAddress, nil)
	}

	return nil
}

// ListUsers returns paginated users with roles
func (s *Service) ListUsers(page, pageSize int) ([]UserWithRoles, int64, error) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}
	return s.repo.ListUsers(page, pageSize)
}
