-- 047: Extend the canonical catalog for technology and broader community events.

INSERT INTO event_categories (slug, display_name, display_name_ar, display_name_tr, sort_order)
VALUES
    ('technology',      'Technology',      'تقنية',             'Teknoloji',       180),
    ('education',       'Education',       'تعليم',             'Eğitim',          190),
    ('business',        'Business',        'أعمال',             'İş',              200),
    ('entrepreneurship','Entrepreneurship','ريادة الأعمال',     'Girişimcilik',    210),
    ('career',          'Career',          'مهنة',              'Kariyer',         220),
    ('health',          'Health',          'صحة',               'Sağlık',          230),
    ('wellness',        'Wellness',        'رفاهية',            'İyi Yaşam',       240),
    ('arts',            'Arts',            'فنون',              'Sanat',           250),
    ('culture',         'Culture',         'ثقافة',             'Kültür',          260),
    ('environment',     'Environment',     'بيئة',              'Çevre',           270),
    ('volunteering',    'Volunteering',    'تطوع',              'Gönüllülük',      280),
    ('food',            'Food & Cooking',  'طعام وطبخ',         'Yemek ve Mutfak', 290),
    ('travel',          'Travel',          'سفر',               'Seyahat',         300),
    ('entertainment',   'Entertainment',   'ترفيه',             'Eğlence',         310),
    ('parenting',       'Parenting',       'تربية الأسرة',      'Ebeveynlik',      320)
ON CONFLICT (slug) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    display_name_ar = EXCLUDED.display_name_ar,
    display_name_tr = EXCLUDED.display_name_tr,
    sort_order = EXCLUDED.sort_order,
    is_active = TRUE,
    updated_at = NOW();

