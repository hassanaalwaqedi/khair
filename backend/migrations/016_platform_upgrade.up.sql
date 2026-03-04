-- Migration 016: Platform Infrastructure Upgrade
-- Countries database, user goals, verification requests, geo-architecture

-- ============================================
-- 1. Countries Reference Table
-- ============================================
CREATE TABLE IF NOT EXISTS countries (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    iso_code CHAR(2) NOT NULL UNIQUE,
    iso3_code CHAR(3),
    phone_code VARCHAR(10) NOT NULL,
    flag_emoji VARCHAR(10) NOT NULL DEFAULT '',
    region VARCHAR(50) NOT NULL DEFAULT 'Other',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_countries_iso ON countries(iso_code);
CREATE INDEX IF NOT EXISTS idx_countries_region ON countries(region);
CREATE INDEX IF NOT EXISTS idx_countries_active ON countries(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_countries_name ON countries(name);

-- ============================================
-- 2. Add country_id + timezone to profiles
-- ============================================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS country_id INTEGER REFERENCES countries(id);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS timezone VARCHAR(50);

-- Add verification_status to users (distinct from email verified_at)
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_status VARCHAR(50) DEFAULT 'none'
    CHECK (verification_status IN ('none', 'pending_review', 'verified', 'rejected'));

-- ============================================
-- 3. User Goals Table
-- ============================================
CREATE TABLE IF NOT EXISTS user_goals (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    goal_key VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, goal_key)
);

CREATE INDEX IF NOT EXISTS idx_user_goals_user ON user_goals(user_id);

-- ============================================
-- 4. Verification Requests Table
-- ============================================
CREATE TABLE IF NOT EXISTS verification_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    profile_image_path VARCHAR(500),
    document_path VARCHAR(500),
    document_type VARCHAR(50) DEFAULT 'general',
    notes TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'pending_review'
        CHECK (status IN ('pending_review', 'approved', 'rejected', 'more_info_needed')),
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    review_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_verification_user ON verification_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_verification_status ON verification_requests(status);

CREATE TRIGGER trigger_verification_requests_updated_at
    BEFORE UPDATE ON verification_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 5. Add organizer-specific fields
-- ============================================
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS established_year INTEGER;
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS attendance_estimate INTEGER;
ALTER TABLE organizers ADD COLUMN IF NOT EXISTS official_email VARCHAR(255);

-- ============================================
-- 6. Seed Countries (195 countries)
-- ============================================
INSERT INTO countries (name, iso_code, iso3_code, phone_code, flag_emoji, region) VALUES
-- Middle East & North Africa
('Saudi Arabia', 'SA', 'SAU', '+966', '🇸🇦', 'Middle East'),
('United Arab Emirates', 'AE', 'ARE', '+971', '🇦🇪', 'Middle East'),
('Qatar', 'QA', 'QAT', '+974', '🇶🇦', 'Middle East'),
('Kuwait', 'KW', 'KWT', '+965', '🇰🇼', 'Middle East'),
('Bahrain', 'BH', 'BHR', '+973', '🇧🇭', 'Middle East'),
('Oman', 'OM', 'OMN', '+968', '🇴🇲', 'Middle East'),
('Yemen', 'YE', 'YEM', '+967', '🇾🇪', 'Middle East'),
('Iraq', 'IQ', 'IRQ', '+964', '🇮🇶', 'Middle East'),
('Jordan', 'JO', 'JOR', '+962', '🇯🇴', 'Middle East'),
('Lebanon', 'LB', 'LBN', '+961', '🇱🇧', 'Middle East'),
('Palestine', 'PS', 'PSE', '+970', '🇵🇸', 'Middle East'),
('Syria', 'SY', 'SYR', '+963', '🇸🇾', 'Middle East'),
('Iran', 'IR', 'IRN', '+98', '🇮🇷', 'Middle East'),
('Turkey', 'TR', 'TUR', '+90', '🇹🇷', 'Middle East'),
('Egypt', 'EG', 'EGY', '+20', '🇪🇬', 'North Africa'),
('Libya', 'LY', 'LBY', '+218', '🇱🇾', 'North Africa'),
('Tunisia', 'TN', 'TUN', '+216', '🇹🇳', 'North Africa'),
('Algeria', 'DZ', 'DZA', '+213', '🇩🇿', 'North Africa'),
('Morocco', 'MA', 'MAR', '+212', '🇲🇦', 'North Africa'),
('Sudan', 'SD', 'SDN', '+249', '🇸🇩', 'North Africa'),
('Mauritania', 'MR', 'MRT', '+222', '🇲🇷', 'North Africa'),
-- South & Central Asia
('Pakistan', 'PK', 'PAK', '+92', '🇵🇰', 'South Asia'),
('India', 'IN', 'IND', '+91', '🇮🇳', 'South Asia'),
('Bangladesh', 'BD', 'BGD', '+880', '🇧🇩', 'South Asia'),
('Afghanistan', 'AF', 'AFG', '+93', '🇦🇫', 'South Asia'),
('Sri Lanka', 'LK', 'LKA', '+94', '🇱🇰', 'South Asia'),
('Nepal', 'NP', 'NPL', '+977', '🇳🇵', 'South Asia'),
('Maldives', 'MV', 'MDV', '+960', '🇲🇻', 'South Asia'),
-- Southeast Asia
('Indonesia', 'ID', 'IDN', '+62', '🇮🇩', 'Southeast Asia'),
('Malaysia', 'MY', 'MYS', '+60', '🇲🇾', 'Southeast Asia'),
('Brunei', 'BN', 'BRN', '+673', '🇧🇳', 'Southeast Asia'),
('Philippines', 'PH', 'PHL', '+63', '🇵🇭', 'Southeast Asia'),
('Thailand', 'TH', 'THA', '+66', '🇹🇭', 'Southeast Asia'),
('Singapore', 'SG', 'SGP', '+65', '🇸🇬', 'Southeast Asia'),
('Myanmar', 'MM', 'MMR', '+95', '🇲🇲', 'Southeast Asia'),
('Vietnam', 'VN', 'VNM', '+84', '🇻🇳', 'Southeast Asia'),
('Cambodia', 'KH', 'KHM', '+855', '🇰🇭', 'Southeast Asia'),
-- Central Asia
('Uzbekistan', 'UZ', 'UZB', '+998', '🇺🇿', 'Central Asia'),
('Kazakhstan', 'KZ', 'KAZ', '+7', '🇰🇿', 'Central Asia'),
('Tajikistan', 'TJ', 'TJK', '+992', '🇹🇯', 'Central Asia'),
('Kyrgyzstan', 'KG', 'KGZ', '+996', '🇰🇬', 'Central Asia'),
('Turkmenistan', 'TM', 'TKM', '+993', '🇹🇲', 'Central Asia'),
('Azerbaijan', 'AZ', 'AZE', '+994', '🇦🇿', 'Central Asia'),
-- Sub-Saharan Africa
('Nigeria', 'NG', 'NGA', '+234', '🇳🇬', 'West Africa'),
('Senegal', 'SN', 'SEN', '+221', '🇸🇳', 'West Africa'),
('Mali', 'ML', 'MLI', '+223', '🇲🇱', 'West Africa'),
('Guinea', 'GN', 'GIN', '+224', '🇬🇳', 'West Africa'),
('Gambia', 'GM', 'GMB', '+220', '🇬🇲', 'West Africa'),
('Sierra Leone', 'SL', 'SLE', '+232', '🇸🇱', 'West Africa'),
('Niger', 'NE', 'NER', '+227', '🇳🇪', 'West Africa'),
('Burkina Faso', 'BF', 'BFA', '+226', '🇧🇫', 'West Africa'),
('Ghana', 'GH', 'GHA', '+233', '🇬🇭', 'West Africa'),
('Ivory Coast', 'CI', 'CIV', '+225', '🇨🇮', 'West Africa'),
('Somalia', 'SO', 'SOM', '+252', '🇸🇴', 'East Africa'),
('Ethiopia', 'ET', 'ETH', '+251', '🇪🇹', 'East Africa'),
('Kenya', 'KE', 'KEN', '+254', '🇰🇪', 'East Africa'),
('Tanzania', 'TZ', 'TZA', '+255', '🇹🇿', 'East Africa'),
('Uganda', 'UG', 'UGA', '+256', '🇺🇬', 'East Africa'),
('Mozambique', 'MZ', 'MOZ', '+258', '🇲🇿', 'East Africa'),
('Djibouti', 'DJ', 'DJI', '+253', '🇩🇯', 'East Africa'),
('Comoros', 'KM', 'COM', '+269', '🇰🇲', 'East Africa'),
('Eritrea', 'ER', 'ERI', '+291', '🇪🇷', 'East Africa'),
('Chad', 'TD', 'TCD', '+235', '🇹🇩', 'Central Africa'),
('Cameroon', 'CM', 'CMR', '+237', '🇨🇲', 'Central Africa'),
('South Africa', 'ZA', 'ZAF', '+27', '🇿🇦', 'Southern Africa'),
-- Europe
('United Kingdom', 'GB', 'GBR', '+44', '🇬🇧', 'Europe'),
('France', 'FR', 'FRA', '+33', '🇫🇷', 'Europe'),
('Germany', 'DE', 'DEU', '+49', '🇩🇪', 'Europe'),
('Netherlands', 'NL', 'NLD', '+31', '🇳🇱', 'Europe'),
('Belgium', 'BE', 'BEL', '+32', '🇧🇪', 'Europe'),
('Sweden', 'SE', 'SWE', '+46', '🇸🇪', 'Europe'),
('Norway', 'NO', 'NOR', '+47', '🇳🇴', 'Europe'),
('Denmark', 'DK', 'DNK', '+45', '🇩🇰', 'Europe'),
('Finland', 'FI', 'FIN', '+358', '🇫🇮', 'Europe'),
('Austria', 'AT', 'AUT', '+43', '🇦🇹', 'Europe'),
('Switzerland', 'CH', 'CHE', '+41', '🇨🇭', 'Europe'),
('Italy', 'IT', 'ITA', '+39', '🇮🇹', 'Europe'),
('Spain', 'ES', 'ESP', '+34', '🇪🇸', 'Europe'),
('Portugal', 'PT', 'PRT', '+351', '🇵🇹', 'Europe'),
('Greece', 'GR', 'GRC', '+30', '🇬🇷', 'Europe'),
('Poland', 'PL', 'POL', '+48', '🇵🇱', 'Europe'),
('Romania', 'RO', 'ROU', '+40', '🇷🇴', 'Europe'),
('Bulgaria', 'BG', 'BGR', '+359', '🇧🇬', 'Europe'),
('Ireland', 'IE', 'IRL', '+353', '🇮🇪', 'Europe'),
('Bosnia and Herzegovina', 'BA', 'BIH', '+387', '🇧🇦', 'Europe'),
('Albania', 'AL', 'ALB', '+355', '🇦🇱', 'Europe'),
('Kosovo', 'XK', 'XKX', '+383', '🇽🇰', 'Europe'),
('Russia', 'RU', 'RUS', '+7', '🇷🇺', 'Europe'),
('Ukraine', 'UA', 'UKR', '+380', '🇺🇦', 'Europe'),
('Czech Republic', 'CZ', 'CZE', '+420', '🇨🇿', 'Europe'),
('Hungary', 'HU', 'HUN', '+36', '🇭🇺', 'Europe'),
-- Americas
('United States', 'US', 'USA', '+1', '🇺🇸', 'North America'),
('Canada', 'CA', 'CAN', '+1', '🇨🇦', 'North America'),
('Mexico', 'MX', 'MEX', '+52', '🇲🇽', 'North America'),
('Brazil', 'BR', 'BRA', '+55', '🇧🇷', 'South America'),
('Argentina', 'AR', 'ARG', '+54', '🇦🇷', 'South America'),
('Colombia', 'CO', 'COL', '+57', '🇨🇴', 'South America'),
('Chile', 'CL', 'CHL', '+56', '🇨🇱', 'South America'),
('Peru', 'PE', 'PER', '+51', '🇵🇪', 'South America'),
('Venezuela', 'VE', 'VEN', '+58', '🇻🇪', 'South America'),
('Trinidad and Tobago', 'TT', 'TTO', '+1', '🇹🇹', 'Caribbean'),
('Guyana', 'GY', 'GUY', '+592', '🇬🇾', 'South America'),
('Suriname', 'SR', 'SUR', '+597', '🇸🇷', 'South America'),
-- Oceania
('Australia', 'AU', 'AUS', '+61', '🇦🇺', 'Oceania'),
('New Zealand', 'NZ', 'NZL', '+64', '🇳🇿', 'Oceania'),
('Fiji', 'FJ', 'FJI', '+679', '🇫🇯', 'Oceania'),
-- East Asia
('China', 'CN', 'CHN', '+86', '🇨🇳', 'East Asia'),
('Japan', 'JP', 'JPN', '+81', '🇯🇵', 'East Asia'),
('South Korea', 'KR', 'KOR', '+82', '🇰🇷', 'East Asia'),
('Taiwan', 'TW', 'TWN', '+886', '🇹🇼', 'East Asia'),
('Hong Kong', 'HK', 'HKG', '+852', '🇭🇰', 'East Asia')
ON CONFLICT (iso_code) DO NOTHING;
