-- Lets a single nudge be about health or finances as well as tasks, for
-- paying (Full plan) users. Still one push per check-in window: this only
-- changes WHO qualifies and what the send-nudges function gets to work
-- with, not how often anyone is nudged.
--
-- profiles.timezone: "today" for a health log or an expense is the
-- person's own date, but the database only knows UTC. Without this, a
-- nudge sent in the evening in the Americas would look at tomorrow's
-- (empty) UTC day and tell someone who already drank their water that
-- they hadn't. The app writes this on every launch and sign-in (see
-- AuthService._afterSignIn).
--
-- profiles.last_nudge_topic: 'tasks', 'health' or 'finance'. The next
-- nudge avoids repeating it when something else has something to say, so
-- a series of nudges mixes topics instead of repeating one.
alter table public.profiles
  add column if not exists timezone text,
  add column if not exists last_nudge_topic text;

-- The return columns change, which create-or-replace can't do.
drop function if exists public.users_to_nudge();

-- Same rules as before for who is due (push on, has a device, past their
-- own check_in_frequency gap), with one change: a Full-plan user no
-- longer needs an open task to qualify, since health or finance may be
-- what's worth saying. Everyone else still needs at least one. Whether
-- there is actually anything to say is decided by send-nudges, which
-- skips (and doesn't stamp last_nudged_at) when there isn't.
create function public.users_to_nudge()
returns table (
  user_id uuid,
  fcm_token text,
  name text,
  motivation_style text,
  procrastination_areas text[],
  plan text,
  timezone text,
  last_nudge_topic text,
  pending_count integer,
  pending_tasks jsonb
)
language sql
stable
security definer set search_path = public
as $$
  select
    p.id,
    p.fcm_token,
    p.name,
    p.motivation_style,
    p.procrastination_areas,
    p.plan::text,
    p.timezone,
    p.last_nudge_topic,
    pending.pending_count,
    pending.pending_tasks
  from public.profiles p
  cross join lateral (
    select
      count(*)::integer as pending_count,
      coalesce(
        jsonb_agg(jsonb_build_object('title', q.title, 'category', q.category) order by q.created_at)
          filter (where q.rn <= 3),
        '[]'::jsonb
      ) as pending_tasks
    from (
      select
        t.title,
        t.category,
        t.created_at,
        row_number() over (order by t.created_at) as rn
      from public.tasks t
      where t.user_id = p.id
        and t.archived_at is null
        and not exists (
          select 1 from public.task_completions c
          where c.task_id = t.id and c.completed_date = current_date
        )
    ) q
  ) pending
  where p.fcm_token is not null
    and p.push_nudges_enabled
    and (
      p.last_nudged_at is null
      or p.last_nudged_at < now() - case p.check_in_frequency
        when 'Every 2 minutes (testing)' then interval '2 minutes'
        when 'Every hour' then interval '1 hour'
        when 'Every 3 hours' then interval '3 hours'
        when 'Twice a day' then interval '12 hours'
        else interval '24 hours' -- 'Once a day', and anything unrecognized
      end
    )
    and (pending.pending_count > 0 or p.plan = 'full');
$$;

grant execute on function public.users_to_nudge() to service_role;
