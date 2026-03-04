-- Migration 018: Badge System & Anti-Fraud
-- Adds organizer badge tracking and event validation rules

-- Badge system for organizers
CREATE TABLE IF NOT EXISTS organizer_badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id UUID NOT NULL REFERENCES organizers(id) ON DELETE CASCADE,
    badge_type VARCHAR(50) NOT NULL,  -- 'verified', 'trusted', 'premium', 'scholar'
    awarded_at TIMESTAMP NOT NULL DEFAULT NOW(),
    awarded_by UUID REFERENCES users(id),
    expires_at TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT true,
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_badges_organizer ON organizer_badges(organizer_id);
CREATE INDEX idx_badges_type ON organizer_badges(badge_type);

-- Add badge display field to organizers
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS verification_badge VARCHAR(50) DEFAULT 'none';
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP;
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS total_events_hosted INT DEFAULT 0;
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS total_attendees INT DEFAULT 0;
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS avg_rating NUMERIC(3,2) DEFAULT 0;

-- Anti-fraud: event validation audit
CREATE TABLE IF NOT EXISTS event_validation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    check_type VARCHAR(50) NOT NULL,  -- 'duplicate_title', 'suspicious_date', 'missing_details', 'spam_content'
    check_result VARCHAR(20) NOT NULL, -- 'pass', 'warn', 'fail'
    details TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_validation_event ON event_validation_logs(event_id);

-- Payment system tables (preparation for Weeks 5-6)
CREATE TABLE IF NOT EXISTS payment_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id UUID NOT NULL UNIQUE REFERENCES organizers(id) ON DELETE CASCADE,
    stripe_account_id VARCHAR(255),
    stripe_onboarded BOOLEAN DEFAULT false,
    payout_enabled BOOLEAN DEFAULT false,
    commission_rate NUMERIC(5,4) DEFAULT 0.1000, -- 10% platform commission
    currency VARCHAR(3) DEFAULT 'USD',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'USD',
    quantity INT NOT NULL DEFAULT 0,
    sold_count INT NOT NULL DEFAULT 0,
    is_free BOOLEAN NOT NULL DEFAULT true,
    sale_start TIMESTAMP,
    sale_end TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tickets_event ON tickets(event_id);

CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    event_id UUID NOT NULL REFERENCES events(id),
    ticket_id UUID NOT NULL REFERENCES tickets(id),
    quantity INT NOT NULL DEFAULT 1,
    total_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    platform_fee NUMERIC(10,2) NOT NULL DEFAULT 0,
    organizer_payout NUMERIC(10,2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, completed, refunded, cancelled
    stripe_payment_intent_id VARCHAR(255),
    stripe_checkout_session_id VARCHAR(255),
    refund_id VARCHAR(255),
    refund_reason TEXT,
    refunded_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_orders_event ON orders(event_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_stripe ON orders(stripe_payment_intent_id);

CREATE TABLE IF NOT EXISTS payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id UUID NOT NULL REFERENCES organizers(id),
    amount NUMERIC(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, processing, completed, failed
    stripe_transfer_id VARCHAR(255),
    period_start TIMESTAMP NOT NULL,
    period_end TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP
);

CREATE INDEX idx_payouts_organizer ON payouts(organizer_id);
CREATE INDEX idx_payouts_status ON payouts(status);
