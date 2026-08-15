-- 046: Add the canonical event category catalog used by discovery and event creation.
-- Categories are data, not a frontend-only list. Event counts are calculated from
-- approved, published future events by the discovery query.

CREATE TABLE IF NOT EXISTS event_categories (
    slug VARCHAR(100) PRIMARY KEY,
    display_name VARCHAR(120) NOT NULL,
    display_name_ar VARCHAR(120),
    display_name_tr VARCHAR(120),
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

INSERT INTO event_categories (slug, display_name, display_name_ar, display_name_tr, sort_order)
VALUES
    ('community',  'Community',  'مجتمع',             'Topluluk',       10),
    ('charity',    'Charity',    'خيري',              'Hayırseverlik',  20),
    ('workshop',   'Workshop',   'ورشة عمل',          'Atölye',         30),
    ('conference', 'Conference', 'مؤتمر',             'Konferans',      40),
    ('seminar',    'Seminar',    'ندوة',              'Seminer',        50),
    ('lectures',   'Lecture',    'محاضرة',            'Ders',           60),
    ('meetup',     'Meetup',     'لقاء',              'Buluşma',        70),
    ('festival',   'Festival',   'مهرجان',            'Festival',        80),
    ('webinar',    'Webinar',    'ندوة عبر الإنترنت', 'Webinar',        90),
    ('retreat',    'Retreat',    'خلوة',              'Kamp',           100),
    ('family',     'Family',     'عائلة',             'Aile',           110),
    ('youth',      'Youth',      'شباب',              'Gençlik',        120),
    ('knowledge',  'Knowledge',  'معرفة',             'Bilgi',          130),
    ('quran',      'Quran',      'القرآن',            'Kur’an',         140),
    ('networking', 'Networking', 'تواصل مهني',        'Networking',     150),
    ('hackathon',  'Hackathon',  'هاكاثون',           'Hackathon',       160),
    ('sports',     'Sports',     'رياضة',             'Spor',           170),
    ('other',      'Other',      'أخرى',              'Diğer',          999)
ON CONFLICT (slug) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    display_name_ar = EXCLUDED.display_name_ar,
    display_name_tr = EXCLUDED.display_name_tr,
    sort_order = EXCLUDED.sort_order,
    is_active = TRUE,
    updated_at = NOW();

CREATE INDEX IF NOT EXISTS idx_event_categories_active_order
    ON event_categories (is_active, sort_order);

