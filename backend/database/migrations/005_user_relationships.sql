
-- User relationship foundation:
-- follows, follow requests, blocks, and account privacy.

-- -----------------------------------------------------
-- 1. Account privacy
-- -----------------------------------------------------

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT FALSE;


-- -----------------------------------------------------
-- 2. User follows
-- Directional relationship:
-- follower_user_id follows following_user_id.
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_follows (
    follower_user_id BIGINT NOT NULL,
    following_user_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT user_follows_pkey
        PRIMARY KEY (follower_user_id, following_user_id),

    CONSTRAINT user_follows_no_self_follow
        CHECK (follower_user_id <> following_user_id),

    CONSTRAINT user_follows_follower_fk
        FOREIGN KEY (follower_user_id)
        REFERENCES public.users(id)
        ON DELETE CASCADE,

    CONSTRAINT user_follows_following_fk
        FOREIGN KEY (following_user_id)
        REFERENCES public.users(id)
        ON DELETE CASCADE
);

-- List of accounts followed by a user.
CREATE INDEX IF NOT EXISTS idx_user_follows_follower_created
    ON public.user_follows (
        follower_user_id,
        created_at DESC,
        following_user_id DESC
    );

-- List of followers of an account.
CREATE INDEX IF NOT EXISTS idx_user_follows_following_created
    ON public.user_follows (
        following_user_id,
        created_at DESC,
        follower_user_id DESC
    );


-- -----------------------------------------------------
-- 3. Follow requests
-- Request history is preserved.
-- Only one pending request per unordered user pair.
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.follow_requests (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    requester_user_id BIGINT NOT NULL,
    target_user_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    responded_at TIMESTAMPTZ,

    CONSTRAINT follow_requests_no_self_request
        CHECK (requester_user_id <> target_user_id),

    CONSTRAINT follow_requests_status_check
        CHECK (
            status IN (
                'pending',
                'accepted',
                'rejected',
                'cancelled'
            )
        ),

    CONSTRAINT follow_requests_requester_fk
        FOREIGN KEY (requester_user_id)
        REFERENCES public.users(id)
        ON DELETE CASCADE,

    CONSTRAINT follow_requests_target_fk
        FOREIGN KEY (target_user_id)
        REFERENCES public.users(id)
        ON DELETE CASCADE
);

-- Prevent simultaneous pending requests in opposite directions.
-- Historical requests with other statuses remain available.
CREATE UNIQUE INDEX IF NOT EXISTS idx_follow_requests_pending_pair_unique
    ON public.follow_requests (
        LEAST(requester_user_id, target_user_id),
        GREATEST(requester_user_id, target_user_id)
    )
    WHERE status = 'pending';

-- Incoming requests.
CREATE INDEX IF NOT EXISTS idx_follow_requests_target_status
    ON public.follow_requests (
        target_user_id,
        status,
        created_at DESC,
        id DESC
    );

-- Outgoing requests.
CREATE INDEX IF NOT EXISTS idx_follow_requests_requester_status
    ON public.follow_requests (
        requester_user_id,
        status,
        created_at DESC,
        id DESC
    );


-- -----------------------------------------------------
-- 4. User blocks
-- Directional relationship:
-- blocker_user_id blocks blocked_user_id.
-- -----------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_blocks (
    blocker_user_id BIGINT NOT NULL,
    blocked_user_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT user_blocks_pkey
        PRIMARY KEY (blocker_user_id, blocked_user_id),

    CONSTRAINT user_blocks_no_self_block
        CHECK (blocker_user_id <> blocked_user_id),

    CONSTRAINT user_blocks_blocker_fk
        FOREIGN KEY (blocker_user_id)
        REFERENCES public.users(id)
        ON DELETE CASCADE,

    CONSTRAINT user_blocks_blocked_fk
        FOREIGN KEY (blocked_user_id)
        REFERENCES public.users(id)
        ON DELETE CASCADE
);

-- Find accounts that have blocked a particular user.
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked
    ON public.user_blocks (blocked_user_id);
