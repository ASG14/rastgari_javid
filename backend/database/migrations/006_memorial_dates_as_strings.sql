-- Convert memorial birth and death dates from PostgreSQL DATE
-- to VARCHAR(10), allowing canonical Jalali date strings.
--
-- Existing dates are preserved in ISO YYYY-MM-DD format.
-- New application values use Jalali YYYY/MM/DD.

BEGIN;

ALTER TABLE public.memorial_profiles
    DROP CONSTRAINT IF EXISTS memorial_profiles_dates_check;

ALTER TABLE public.memorial_profiles
    ALTER COLUMN birth_date TYPE VARCHAR(10)
    USING CASE
        WHEN birth_date IS NULL THEN NULL
        ELSE to_char(birth_date, 'YYYY-MM-DD')
    END;

ALTER TABLE public.memorial_profiles
    ALTER COLUMN death_date TYPE VARCHAR(10)
    USING CASE
        WHEN death_date IS NULL THEN NULL
        ELSE to_char(death_date, 'YYYY-MM-DD')
    END;

COMMENT ON COLUMN public.memorial_profiles.birth_date IS
    'Date string. New application values use Jalali YYYY/MM/DD. Existing ISO YYYY-MM-DD values are preserved.';

COMMENT ON COLUMN public.memorial_profiles.death_date IS
    'Date string. New application values use Jalali YYYY/MM/DD. Existing ISO YYYY-MM-DD values are preserved.';

COMMIT;