-- users_to_nudge only ever handed send-nudges the 3 oldest open tasks.
-- That's enough to name one in a nudge, but the "this is exactly what you
-- said you put off" callout has to look for a matching task among ALL of
-- someone's open ones: with the old cap, a matching task that was the 4th
-- oldest was invisible, so the callout could never fire for it.
--
-- Same columns and rules as 0013; only the cap changes, so no drop is
-- needed. Ten covers everyone on the Basic plan (capped at 5 active tasks)
-- and any realistic open list on Full. pending_count still reports the
-- true total.
create or replace function public.users_to_nudge()
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
          filter (where q.rn <= 10),
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
