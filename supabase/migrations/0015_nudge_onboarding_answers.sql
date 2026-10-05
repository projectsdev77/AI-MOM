-- Lets send-nudges speak to more of what someone said at onboarding, not
-- just their motivation style and what they put off: their goals, daily
-- routine and living situation, and whether they named a current stressor.
--
-- The stressor's TEXT is deliberately not returned, only whether there is
-- one. A push notification shows on the lock screen, so the wording of
-- something sensitive must never be quotable by the nudge code; the most it
-- can do is acknowledge that "a lot is going on".
--
-- Open tasks also now carry their recurrence and streak so a habit that is
-- still open today (and has a streak worth protecting) can be called out
-- for people whose goal is to build habits.
--
-- The return columns change, which create-or-replace can't do.
drop function if exists public.users_to_nudge();

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
  pending_tasks jsonb,
  goals text[],
  daily_routine text,
  living_situation text,
  has_stressor boolean
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
    pending.pending_tasks,
    p.goals,
    p.daily_routine,
    p.living_situation,
    coalesce(btrim(p.current_stressor), '') <> ''
  from public.profiles p
  cross join lateral (
    select
      count(*)::integer as pending_count,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'title', q.title,
            'category', q.category,
            'recurrence', q.recurrence,
            'streak_count', q.streak_count
          )
          order by q.created_at
        ) filter (where q.rn <= 10),
        '[]'::jsonb
      ) as pending_tasks
    from (
      select
        t.title,
        t.category,
        t.recurrence::text as recurrence,
        t.streak_count,
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
