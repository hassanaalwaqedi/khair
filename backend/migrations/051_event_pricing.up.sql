ALTER TABLE events ADD COLUMN IF NOT EXISTS pricing_type VARCHAR(20) DEFAULT 'free';
ALTER TABLE events ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50);

-- Ensure all existing events that have price_cents > 0 or ticket_price > 0 are marked as paid
UPDATE events 
SET 
    price_cents = CASE 
        WHEN COALESCE(ticket_price, 0) > 0 THEN (ticket_price * 100)::INTEGER 
        ELSE price_cents 
    END,
    pricing_type = CASE 
        WHEN COALESCE(price_cents, 0) > 0 OR COALESCE((ticket_price * 100)::INTEGER, 0) > 0 THEN 'paid' 
        ELSE 'free' 
    END,
    payment_method = CASE 
        WHEN COALESCE(price_cents, 0) > 0 OR COALESCE((ticket_price * 100)::INTEGER, 0) > 0 THEN 'pay_at_venue' 
        ELSE NULL 
    END;

-- Drop the old floating point column
ALTER TABLE events DROP COLUMN IF EXISTS ticket_price;
