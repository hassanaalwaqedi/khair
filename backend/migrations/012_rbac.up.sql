-- ============================================================================
-- Migration 012: Role-Based Access Control (RBAC) System
-- ============================================================================

-- ── RBAC Core Tables ──

CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE user_roles (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    PRIMARY KEY (user_id, role_id)
);

-- ── Indexes ──

CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_roles_role_id ON user_roles(role_id);
CREATE INDEX idx_role_permissions_role_id ON role_permissions(role_id);
CREATE INDEX idx_role_permissions_permission_id ON role_permissions(permission_id);

-- ── Seed Roles ──

INSERT INTO roles (name, description) VALUES
    ('user', 'Standard platform user'),
    ('organizer', 'Event organizer with creation privileges'),
    ('admin', 'Platform administrator'),
    ('super_admin', 'Super administrator with full system access');

-- ── Seed Permissions ──

INSERT INTO permissions (name, description) VALUES
    ('create_event', 'Create new events'),
    ('edit_event', 'Edit existing events'),
    ('delete_event', 'Delete events'),
    ('approve_event', 'Approve pending events'),
    ('reject_event', 'Reject pending events'),
    ('manage_users', 'Manage user accounts and roles'),
    ('view_admin_dashboard', 'Access the admin dashboard');

-- ── Map Permissions to Roles ──

-- organizer: create, edit, delete own events
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.name = 'organizer' AND p.name IN ('create_event', 'edit_event', 'delete_event');

-- admin: all event moderation + dashboard
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.name = 'admin' AND p.name IN (
    'create_event', 'edit_event', 'delete_event',
    'approve_event', 'reject_event',
    'view_admin_dashboard'
);

-- super_admin: everything
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.name = 'super_admin';

-- ── Migrate Existing Users to user_roles ──

INSERT INTO user_roles (user_id, role_id, assigned_at)
SELECT u.id, r.id, u.created_at
FROM users u
JOIN roles r ON r.name = u.role
ON CONFLICT DO NOTHING;

-- ── Event Moderation Columns ──

ALTER TABLE events
    ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP WITH TIME ZONE;

-- Expand event status CHECK to include needs_revision
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;
ALTER TABLE events ADD CONSTRAINT events_status_check
    CHECK (status IN ('draft', 'pending', 'approved', 'rejected', 'needs_revision', 'published'));

CREATE INDEX idx_events_reviewed_by ON events(reviewed_by);

-- ── RBAC Audit Log ──

CREATE TABLE rbac_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL,
    target_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    role_name VARCHAR(50),
    permission_name VARCHAR(100),
    details JSONB,
    ip_address INET,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_rbac_audit_actor ON rbac_audit_log(actor_id);
CREATE INDEX idx_rbac_audit_target ON rbac_audit_log(target_user_id);
CREATE INDEX idx_rbac_audit_created ON rbac_audit_log(created_at);
