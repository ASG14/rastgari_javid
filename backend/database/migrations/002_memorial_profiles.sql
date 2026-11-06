
BEGIN;

-- 1. Relationship between a user and a deceased person.
CREATE TYPE public.memorial_relationship AS ENUM (
    'mother',
    'father',
    'sister',
    'brother',
    'child',
    'spouse',
    'friend',
    'other'
);

-- 2. Membership permissions.
CREATE TYPE public.memorial_member_role AS ENUM (
    'owner',
    'editor',
    'follower'
);

-- 3. Membership lifecycle.
CREATE TYPE public.memorial_member_status AS ENUM (
    'active',
    'pending',
    'revoked'
);

-- 4. Memorial profiles.
CREATE TABLE public.memorial_profiles (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    created_by_user_id BIGINT NOT NULL,

    full_name VARCHAR(150) NOT NULL,

    photo_media_asset_id BIGINT,

    birth_date DATE,
    death_date DATE,

    memorial_text TEXT,
    grave_address VARCHAR(500),

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT memorial_profiles_name_check
        CHECK (length(trim(full_name)) > 0),

    CONSTRAINT memorial_profiles_dates_check
        CHECK (
            birth_date IS NULL
            OR death_date IS NULL
            OR death_date >= birth_date
        ),

    CONSTRAINT memorial_profiles_creator_fk
        FOREIGN KEY (created_by_user_id)
        REFERENCES public.users(id)
        ON DELETE RESTRICT,

    CONSTRAINT memorial_profiles_photo_fk
        FOREIGN KEY (photo_media_asset_id)
        REFERENCES public.media_assets(id)
        ON DELETE RESTRICT
);

-- 5. Users connected to memorial profiles.
CREATE TABLE public.memorial_members (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    memorial_profile_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,

    relationship public.memorial_relationship NOT NULL,

    role public.memorial_member_role NOT NULL DEFAULT 'follower',

    status public.memorial_member_status NOT NULL DEFAULT 'active',

    notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT memorial_members_profile_user_unique
        UNIQUE (memorial_profile_id, user_id),

    CONSTRAINT memorial_members_profile_fk
        FOREIGN KEY (memorial_profile_id)
        REFERENCES public.memorial_profiles(id)
        ON DELETE RESTRICT,

    CONSTRAINT memorial_members_user_fk
        FOREIGN KEY (user_id)
        REFERENCES public.users(id)
        ON DELETE RESTRICT
);

-- A profile can have only one active owner.
CREATE UNIQUE INDEX memorial_members_one_active_owner_idx
    ON public.memorial_members (memorial_profile_id)
    WHERE role = 'owner' AND status = 'active';

-- 6. Search and lookup indexes.
CREATE INDEX memorial_profiles_name_search_idx
    ON public.memorial_profiles (lower(full_name))
    WHERE deleted_at IS NULL;

CREATE INDEX memorial_profiles_creator_idx
    ON public.memorial_profiles (created_by_user_id, created_at DESC);

CREATE INDEX memorial_profiles_death_date_idx
    ON public.memorial_profiles (death_date)
    WHERE deleted_at IS NULL AND death_date IS NOT NULL;

CREATE INDEX memorial_members_user_idx
    ON public.memorial_members (user_id, created_at DESC);

CREATE INDEX memorial_members_profile_idx
    ON public.memorial_members (memorial_profile_id, status);

CREATE INDEX memorial_members_notifications_idx
    ON public.memorial_members (user_id, memorial_profile_id)
    WHERE status = 'active' AND notifications_enabled = TRUE;

COMMIT;
