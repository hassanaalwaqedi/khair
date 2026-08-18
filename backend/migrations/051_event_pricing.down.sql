ALTER TABLE events ADD COLUMN IF NOT EXISTS ticket_price DECIMAL(10,2) DEFAULT 0;

UPDATE events SET ticket_price = (price_cents / 100.0) WHERE price_cents > 0;

ALTER TABLE events DROP COLUMN IF EXISTS pricing_type;
ALTER TABLE events DROP COLUMN IF EXISTS payment_method;
