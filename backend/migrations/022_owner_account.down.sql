-- Revert owner account to pending status
UPDATE users
SET is_verified = FALSE,
    verified_at = NULL,
    status = 'pending',
    role = 'member',
    updated_at = NOW()
WHERE email = 'hassanalwaqedi2@gmail.com';
