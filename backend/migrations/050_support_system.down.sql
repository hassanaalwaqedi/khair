DROP TABLE IF EXISTS support_attachments CASCADE;
DROP TABLE IF EXISTS support_messages CASCADE;
DROP TABLE IF EXISTS support_tickets CASCADE;
DROP TABLE IF EXISTS support_articles CASCADE;

DELETE FROM role_permissions WHERE permission_id IN (
    SELECT id FROM permissions WHERE name IN ('view_support_tickets', 'respond_support_tickets', 'resolve_support_tickets')
);
DELETE FROM permissions WHERE name IN ('view_support_tickets', 'respond_support_tickets', 'resolve_support_tickets');
DELETE FROM roles WHERE name = 'support_agent';
