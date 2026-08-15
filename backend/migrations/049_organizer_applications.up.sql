-- 049: Production organizer application and review workflow.
-- This is additive: the legacy organizers row remains the authorization bridge
-- for existing event APIs, while this dossier is the source of review truth.

CREATE TABLE IF NOT EXISTS organizer_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(24) NOT NULL DEFAULT 'draft',
    organizer_type VARCHAR(40),
    public_name VARCHAR(160),
    representative_name VARCHAR(160),
    account_email VARCHAR(255),
    contact_email VARCHAR(255),
    contact_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    phone VARCHAR(32),
    country_code CHAR(2),
    city VARCHAR(120),
    description TEXT,
    public_logo_key TEXT,
    representative_photo_key TEXT,
    event_plan TEXT,
    typical_audience JSONB NOT NULL DEFAULT '[]'::jsonb,
    guidelines_version VARCHAR(32),
    guidelines_accepted_at TIMESTAMPTZ,
    submitted_snapshot JSONB,
    submitted_at TIMESTAMPTZ,
    resubmitted_at TIMESTAMPTZ,
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    admin_reason_code VARCHAR(64),
    admin_user_message TEXT,
    internal_admin_note TEXT,
    revision_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT organizer_application_status_check
        CHECK (status IN ('draft', 'pending', 'needs_revision', 'approved', 'rejected', 'suspended')),
    CONSTRAINT organizer_application_type_check
        CHECK (organizer_type IS NULL OR organizer_type IN (
          'individual', 'community', 'mosque', 'charity', 'company', 'school', 'other'
        )),
    CONSTRAINT organizer_application_country_check
        CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2}$')
);

CREATE TABLE IF NOT EXISTS organizer_application_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES organizer_applications(id) ON DELETE CASCADE,
    platform VARCHAR(40) NOT NULL,
    url TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT organizer_application_link_platform_check
        CHECK (platform IN ('website', 'instagram', 'facebook', 'linkedin', 'other')),
    CONSTRAINT organizer_application_link_url_check
        CHECK (url ~* '^https?://')
);

CREATE TABLE IF NOT EXISTS organizer_application_categories (
    application_id UUID NOT NULL REFERENCES organizer_applications(id) ON DELETE CASCADE,
    category_slug VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (application_id, category_slug)
);

CREATE TABLE IF NOT EXISTS organizer_application_evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES organizer_applications(id) ON DELETE CASCADE,
    evidence_type VARCHAR(48) NOT NULL,
    url TEXT,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT organizer_application_evidence_type_check
        CHECK (evidence_type IN ('official_website', 'verified_social', 'registration', 'charity_registration', 'community_document', 'school_company_document', 'other')),
    CONSTRAINT organizer_application_evidence_url_check
        CHECK (url IS NULL OR url ~* '^https?://')
);

CREATE TABLE IF NOT EXISTS organizer_verification_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES organizer_applications(id) ON DELETE CASCADE,
    file_type VARCHAR(48) NOT NULL,
    storage_key TEXT NOT NULL UNIQUE,
    original_filename VARCHAR(255) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    size_bytes BIGINT NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 10485760),
    applicant_note TEXT,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT organizer_verification_files_type_check
        CHECK (file_type IN ('registration', 'charity_registration', 'community_document', 'school_company_document', 'other')),
    CONSTRAINT organizer_verification_files_mime_check
        CHECK (mime_type IN ('application/pdf', 'image/jpeg', 'image/png'))
);

CREATE TABLE IF NOT EXISTS organizer_application_revisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES organizer_applications(id) ON DELETE CASCADE,
    actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(32) NOT NULL,
    snapshot JSONB,
    user_message TEXT,
    internal_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT organizer_application_revision_action_check
        CHECK (action IN ('draft_saved', 'submitted', 'resubmitted', 'approved', 'needs_revision', 'rejected', 'suspended', 'document_accessed'))
);

CREATE TABLE IF NOT EXISTS organizer_application_decisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES organizer_applications(id) ON DELETE CASCADE,
    admin_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    decision VARCHAR(24) NOT NULL,
    reason_code VARCHAR(64),
    user_message TEXT,
    internal_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT organizer_application_decision_check
        CHECK (decision IN ('approved', 'needs_revision', 'rejected', 'suspended'))
);

CREATE INDEX IF NOT EXISTS idx_organizer_applications_user ON organizer_applications(user_id);
CREATE INDEX IF NOT EXISTS idx_organizer_applications_status_submitted
    ON organizer_applications(status, submitted_at ASC);
CREATE INDEX IF NOT EXISTS idx_organizer_applications_reviewed_by
    ON organizer_applications(reviewed_by) WHERE reviewed_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_organizer_application_links_application
    ON organizer_application_links(application_id);
CREATE INDEX IF NOT EXISTS idx_organizer_application_files_application
    ON organizer_verification_files(application_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_organizer_application_revisions_application
    ON organizer_application_revisions(application_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_organizer_application_decisions_application
    ON organizer_application_decisions(application_id, created_at DESC);
