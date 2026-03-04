-- Migration 014: Spiritual quotes for Quran/Hadith surfaces

CREATE TABLE IF NOT EXISTS spiritual_quotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(16) NOT NULL CHECK (type IN ('quran', 'hadith')),
    text_ar TEXT NOT NULL,
    source VARCHAR(255) NOT NULL,
    reference VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    show_on_dashboard BOOLEAN NOT NULL DEFAULT FALSE,
    show_on_home BOOLEAN NOT NULL DEFAULT FALSE,
    show_on_login BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_spiritual_quotes_active
    ON spiritual_quotes(is_active)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_spiritual_quotes_dashboard
    ON spiritual_quotes(show_on_dashboard)
    WHERE show_on_dashboard = TRUE;

CREATE INDEX IF NOT EXISTS idx_spiritual_quotes_home
    ON spiritual_quotes(show_on_home)
    WHERE show_on_home = TRUE;

CREATE INDEX IF NOT EXISTS idx_spiritual_quotes_login
    ON spiritual_quotes(show_on_login)
    WHERE show_on_login = TRUE;

INSERT INTO spiritual_quotes (
    type,
    text_ar,
    source,
    reference,
    is_active,
    show_on_dashboard,
    show_on_home,
    show_on_login
)
SELECT
    seed.type,
    seed.text_ar,
    seed.source,
    seed.reference,
    seed.is_active,
    seed.show_on_dashboard,
    seed.show_on_home,
    seed.show_on_login
FROM (
    VALUES
        ('quran', 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا', 'سورة الشرح', '94:6', TRUE, TRUE, TRUE, TRUE),
        ('quran', 'يَا أَيُّهَا النَّاسُ إِنَّا خَلَقْنَاكُم مِّن ذَكَرٍ وَأُنثَىٰ وَجَعَلْنَاكُمْ شُعُوبًا وَقَبَائِلَ لِتَعَارَفُوا', 'سورة الحجرات', '49:13', TRUE, TRUE, TRUE, FALSE),
        ('hadith', 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ', 'صحيح البخاري', '1', TRUE, TRUE, FALSE, TRUE),
        ('hadith', 'مَنْ لَا يَرْحَمْ لَا يُرْحَمْ', 'صحيح البخاري', '7376', TRUE, FALSE, TRUE, FALSE)
) AS seed(type, text_ar, source, reference, is_active, show_on_dashboard, show_on_home, show_on_login)
WHERE NOT EXISTS (
    SELECT 1 FROM spiritual_quotes
);
