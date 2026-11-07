
-- Simplify memorial memberships.
-- Profile ownership is managed exclusively by
-- memorial_profiles.created_by_user_id.
-- Every memorial member is a follower with a declared relationship.

-- Pending memberships no longer require approval.
UPDATE public.memorial_members
SET status = 'active',
    updated_at = CURRENT_TIMESTAMP
WHERE status = 'pending';

-- Revoked memberships represent users who have unfollowed.
DELETE FROM public.memorial_members
WHERE status = 'revoked';

-- Remove indexes that depend on role or status.
DROP INDEX IF EXISTS public.memorial_members_one_active_owner_idx;
DROP INDEX IF EXISTS public.memorial_members_profile_idx;
DROP INDEX IF EXISTS public.memorial_members_notifications_idx;

-- Remove obsolete permission and lifecycle columns.
ALTER TABLE public.memorial_members
    DROP COLUMN role,
    DROP COLUMN status;

-- Remove obsolete enum types.
DROP TYPE public.memorial_member_role;
DROP TYPE public.memorial_member_status;

-- Recreate indexes for the simplified membership model.
CREATE INDEX memorial_members_profile_idx
    ON public.memorial_members (memorial_profile_id, created_at DESC);

CREATE INDEX memorial_members_notifications_idx
    ON public.memorial_members (user_id, memorial_profile_id)
    WHERE notifications_enabled = TRUE;
