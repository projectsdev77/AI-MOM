-- Quiet hours the user can choose: no nudges between "from" and "until" (whole
-- hours, in their own timezone). The defaults are the fixed window nudges used
-- until now, 22:00 to 07:00, so nobody's behaviour changes until they edit it.
-- "From" later than "until" means the window crosses midnight (22 -> 7); a
-- same-day window (13 -> 15) also works; equal values mean no quiet hours.
alter table public.profiles
  add column if not exists quiet_hours_enabled boolean not null default true,
  add column if not exists quiet_from_hour smallint not null default 22,
  add column if not exists quiet_until_hour smallint not null default 7;

alter table public.profiles drop constraint if exists quiet_hours_in_range;
alter table public.profiles
  add constraint quiet_hours_in_range
  check (quiet_from_hour between 0 and 23 and quiet_until_hour between 0 and 23);

-- users_to_nudge() now also returns the three settings, so send-nudges can
-- hold a nudge back for the person's own quiet hours. The return columns
-- change, which create-or-replace can't do.
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
  has_stressor boolean,
  quiet_hours_enabled boolean,
  quiet_from_hour integer,
  quiet_until_hour integer
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
    coalesce(btrim(p.current_stressor), '') <> '',
    p.quiet_hours_enabled,
    p.quiet_from_hour::integer,
    p.quiet_until_hour::integer
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
