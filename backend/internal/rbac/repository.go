package rbac

import (
	"database/sql"
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

type Repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// GetUserRoles returns role names for a user
func (r *Repository) GetUserRoles(userID uuid.UUID) ([]string, error) {
	query := `
		SELECT ro.name
		FROM user_roles ur
		JOIN roles ro ON ro.id = ur.role_id
		WHERE ur.user_id = $1
		ORDER BY ro.name
	`
	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var roles []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, err
		}
		roles = append(roles, name)
	}
	return roles, rows.Err()
}

// GetUserPermissions returns all permission names for a user (via their roles)
func (r *Repository) GetUserPermissions(userID uuid.UUID) ([]string, error) {
	query := `
		SELECT DISTINCT p.name
		FROM user_roles ur
		JOIN role_permissions rp ON rp.role_id = ur.role_id
		JOIN permissions p ON p.id = rp.permission_id
		WHERE ur.user_id = $1
		ORDER BY p.name
	`
	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var perms []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, err
		}
		perms = append(perms, name)
	}
	return perms, rows.Err()
}

// HasPermission checks if a user has a specific permission
func (r *Repository) HasPermission(userID uuid.UUID, permissionName string) (bool, error) {
	query := `
		SELECT EXISTS(
			SELECT 1
			FROM user_roles ur
			JOIN role_permissions rp ON rp.role_id = ur.role_id
			JOIN permissions p ON p.id = rp.permission_id
			WHERE ur.user_id = $1 AND p.name = $2
		)
	`
	var exists bool
	err := r.db.QueryRow(query, userID, permissionName).Scan(&exists)
	return exists, err
}

// HasRole checks if a user has a specific role
func (r *Repository) HasRole(userID uuid.UUID, roleName string) (bool, error) {
	query := `
		SELECT EXISTS(
			SELECT 1
			FROM user_roles ur
			JOIN roles ro ON ro.id = ur.role_id
			WHERE ur.user_id = $1 AND ro.name = $2
		)
	`
	var exists bool
	err := r.db.QueryRow(query, userID, roleName).Scan(&exists)
	return exists, err
}

// AssignRole assigns a role to a user
func (r *Repository) AssignRole(userID uuid.UUID, roleName string, assignedBy uuid.UUID) error {
	query := `
		INSERT INTO user_roles (user_id, role_id, assigned_at, assigned_by)
		SELECT $1, ro.id, NOW(), $3
		FROM roles ro WHERE ro.name = $2
		ON CONFLICT (user_id, role_id) DO NOTHING
	`
	_, err := r.db.Exec(query, userID, roleName, assignedBy)
	return err
}

// RemoveRole removes a role from a user
func (r *Repository) RemoveRole(userID uuid.UUID, roleName string) error {
	query := `
		DELETE FROM user_roles
		WHERE user_id = $1 AND role_id = (SELECT id FROM roles WHERE name = $2)
	`
	_, err := r.db.Exec(query, userID, roleName)
	return err
}

// ListRoles returns all roles with their permissions
func (r *Repository) ListRoles() ([]RoleWithPermissions, error) {
	rolesQuery := `SELECT id, name, description, created_at FROM roles ORDER BY name`
	rows, err := r.db.Query(rolesQuery)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var roles []RoleWithPermissions
	for rows.Next() {
		var role RoleWithPermissions
		if err := rows.Scan(&role.ID, &role.Name, &role.Description, &role.CreatedAt); err != nil {
			return nil, err
		}
		roles = append(roles, role)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	for i, role := range roles {
		permsQuery := `
			SELECT p.id, p.name, p.description, p.created_at
			FROM role_permissions rp
			JOIN permissions p ON p.id = rp.permission_id
			WHERE rp.role_id = $1
			ORDER BY p.name
		`
		pRows, err := r.db.Query(permsQuery, role.ID)
		if err != nil {
			return nil, err
		}

		var perms []Permission
		for pRows.Next() {
			var p Permission
			if err := pRows.Scan(&p.ID, &p.Name, &p.Description, &p.CreatedAt); err != nil {
				pRows.Close()
				return nil, err
			}
			perms = append(perms, p)
		}
		pRows.Close()
		if perms == nil {
			perms = []Permission{}
		}
		roles[i].Permissions = perms
	}

	return roles, nil
}

// CreateRole creates a new role
func (r *Repository) CreateRole(name, description string) (*Role, error) {
	role := &Role{
		ID:        uuid.New(),
		Name:      name,
		CreatedAt: time.Now(),
	}
	if description != "" {
		role.Description = &description
	}

	query := `INSERT INTO roles (id, name, description, created_at) VALUES ($1, $2, $3, $4)`
	_, err := r.db.Exec(query, role.ID, role.Name, role.Description, role.CreatedAt)
	if err != nil {
		return nil, err
	}
	return role, nil
}

// AssignPermissionToRole assigns permissions to a role
func (r *Repository) AssignPermissionToRole(roleID uuid.UUID, permissionNames []string) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	for _, pName := range permissionNames {
		_, err := tx.Exec(`
			INSERT INTO role_permissions (role_id, permission_id)
			SELECT $1, id FROM permissions WHERE name = $2
			ON CONFLICT DO NOTHING
		`, roleID, pName)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

// GetRoleByID returns a role by its ID
func (r *Repository) GetRoleByID(id uuid.UUID) (*Role, error) {
	query := `SELECT id, name, description, created_at FROM roles WHERE id = $1`
	role := &Role{}
	err := r.db.QueryRow(query, id).Scan(&role.ID, &role.Name, &role.Description, &role.CreatedAt)
	if err != nil {
		return nil, err
	}
	return role, nil
}

// ListUsers returns paginated users with their roles
func (r *Repository) ListUsers(page, pageSize int) ([]UserWithRoles, int64, error) {
	offset := (page - 1) * pageSize

	var total int64
	if err := r.db.QueryRow(`SELECT COUNT(*) FROM users`).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := `
		SELECT id, email, role, status, is_verified, created_at, updated_at
		FROM users
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.db.Query(query, pageSize, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var users []UserWithRoles
	for rows.Next() {
		var u UserWithRoles
		if err := rows.Scan(&u.ID, &u.Email, &u.Role, &u.Status, &u.IsVerified, &u.CreatedAt, &u.UpdatedAt); err != nil {
			return nil, 0, err
		}
		users = append(users, u)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}

	for i, u := range users {
		rolesQuery := `
			SELECT ur.user_id, ur.role_id, ro.name, ur.assigned_at, ur.assigned_by
			FROM user_roles ur
			JOIN roles ro ON ro.id = ur.role_id
			WHERE ur.user_id = $1
		`
		rRows, err := r.db.Query(rolesQuery, u.ID)
		if err != nil {
			return nil, 0, err
		}

		var roles []UserRole
		for rRows.Next() {
			var ur UserRole
			if err := rRows.Scan(&ur.UserID, &ur.RoleID, &ur.RoleName, &ur.AssignedAt, &ur.AssignedBy); err != nil {
				rRows.Close()
				return nil, 0, err
			}
			roles = append(roles, ur)
		}
		rRows.Close()
		if roles == nil {
			roles = []UserRole{}
		}
		users[i].Roles = roles
	}

	return users, total, nil
}

// LogRoleChange records an audit log entry for RBAC changes
func (r *Repository) LogRoleChange(actorID uuid.UUID, action string, targetUserID *uuid.UUID, roleName, permissionName, ipAddress *string, details interface{}) error {
	var detailsJSON []byte
	if details != nil {
		var err error
		detailsJSON, err = json.Marshal(details)
		if err != nil {
			return err
		}
	}

	query := `
		INSERT INTO rbac_audit_log (id, actor_id, action, target_user_id, role_name, permission_name, details, ip_address, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8::inet, NOW())
	`
	_, err := r.db.Exec(query,
		uuid.New(), actorID, action, targetUserID, roleName, permissionName,
		detailsJSON, ipAddress,
	)
	return err
}
