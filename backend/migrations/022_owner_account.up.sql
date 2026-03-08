-- Verify and promote hassanalwaqedi2@gmail.com as the platform owner ("Khair")
UPDATE users
SET is_verified = TRUE,
    verified_at = NOW(),
    status = 'active',
    role = 'admin',
    updated_at = NOW()
WHERE email = 'hassanalwaqedi2@gmail.com';

-- Clean up any pending verification records for this email
DELETE FROM email_verifications WHERE email = 'hassanalwaqedi2@gmail.com';
