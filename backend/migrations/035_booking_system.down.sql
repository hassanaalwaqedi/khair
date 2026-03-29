-- 035: Revert booking calendar system
DROP INDEX IF EXISTS idx_no_double_booking;
DROP INDEX IF EXISTS idx_blocked_times_range;
DROP INDEX IF EXISTS idx_bookings_status;
DROP INDEX IF EXISTS idx_bookings_student;
DROP INDEX IF EXISTS idx_bookings_sheikh_time;
DROP INDEX IF EXISTS idx_availability_sheikh;
DROP TABLE IF EXISTS blocked_times;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS booking_settings;
DROP TABLE IF EXISTS availability_rules;
