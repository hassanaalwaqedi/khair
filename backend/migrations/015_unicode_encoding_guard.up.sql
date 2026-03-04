DO $$
BEGIN
    IF current_setting('server_encoding') <> 'UTF8' THEN
        RAISE EXCEPTION 'Database encoding must be UTF8, got %', current_setting('server_encoding');
    END IF;
END
$$;
