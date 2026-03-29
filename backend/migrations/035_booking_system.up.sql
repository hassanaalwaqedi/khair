-- 035: Lesson Booking Calendar System
-- Sheikh availability rules (weekly recurring)
CREATE TABLE IF NOT EXISTS availability_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sheikh_id UUID NOT NULL REFERENCES sheikhs(id),
  day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Sunday
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  slot_duration_minutes INT NOT NULL DEFAULT 30,
  break_minutes INT NOT NULL DEFAULT 5,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(sheikh_id, day_of_week)
);

-- Sheikh booking preferences
CREATE TABLE IF NOT EXISTS booking_settings (
  sheikh_id UUID PRIMARY KEY REFERENCES sheikhs(id),
  timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
  auto_approve BOOLEAN NOT NULL DEFAULT false,
  prayer_blocking BOOLEAN NOT NULL DEFAULT true,
  default_meeting_link TEXT,
  default_platform VARCHAR(50) DEFAULT 'Zoom',
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Actual bookings
CREATE TABLE IF NOT EXISTS bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES users(id),
  sheikh_id UUID NOT NULL REFERENCES sheikhs(id),
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'confirmed', 'rejected', 'cancelled', 'completed')),
  meeting_link TEXT,
  meeting_platform VARCHAR(50),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Manual blocked times (vacations, personal time, etc.)
CREATE TABLE IF NOT EXISTS blocked_times (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sheikh_id UUID NOT NULL REFERENCES sheikhs(id),
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  reason VARCHAR(50) NOT NULL DEFAULT 'manual'
    CHECK (reason IN ('manual', 'prayer', 'vacation', 'other')),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_availability_sheikh ON availability_rules(sheikh_id, day_of_week);
CREATE INDEX IF NOT EXISTS idx_bookings_sheikh_time ON bookings(sheikh_id, start_time);
CREATE INDEX IF NOT EXISTS idx_bookings_student ON bookings(student_id, start_time);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(sheikh_id, status);
CREATE INDEX IF NOT EXISTS idx_blocked_times_range ON blocked_times(sheikh_id, start_time, end_time);

-- Prevent double-booking at DB level (unique on sheikh + start_time for non-cancelled bookings)
CREATE UNIQUE INDEX IF NOT EXISTS idx_no_double_booking
  ON bookings(sheikh_id, start_time) WHERE status NOT IN ('cancelled', 'rejected');
