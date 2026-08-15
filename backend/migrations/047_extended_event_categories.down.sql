DELETE FROM event_categories
WHERE slug IN (
    'technology', 'education', 'business', 'entrepreneurship', 'career',
    'health', 'wellness', 'arts', 'culture', 'environment', 'volunteering',
    'food', 'travel', 'entertainment', 'parenting'
);
