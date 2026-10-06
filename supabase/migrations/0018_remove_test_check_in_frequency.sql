-- Removes the "Every 2 minutes (testing)" check-in option, which only existed
-- to test the nudge pipeline. Anyone still saved on it is moved to the
-- shortest real option ("Every hour"), and the function no longer knows
-- about it (an unrecognized value falls back to once a day).
update public.profiles
set check_in_frequency = 'Every hour'
where check_in_frequency = 'Every 2 minutes (testing)';

-- Same function as 0015, minus the testing case. Return columns are unchanged,
-- but it is dropped and recreated to keep this migration re-runnable.
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
        when 'Every hour' then interval '1 hour'
        when 'Every 3 hours' then interval '3 hours'
        when 'Twice a day' then interval '12 hours'
        else interval '24 hours' -- 'Once a day', and anything unrecognized
      end
    )
    and (pending.pending_count > 0 or p.plan = 'full');
$$;

grant execute on function public.users_to_nudge() to service_role;
