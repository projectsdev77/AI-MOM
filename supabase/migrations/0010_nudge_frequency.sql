-- users_to_nudge previously used one flat 4-hour gap for every user,
-- ignoring the check-in frequency they actually picked during
-- onboarding (profiles.check_in_frequency — 'Once a day', 'Twice a
-- day', 'Every 3 hours', or 'Every hour'). This makes the minimum gap
-- between nudges depend on that choice instead, and tightens the cron
-- schedule to hourly so "Every hour" is actually reachable (a job that
-- only runs every 2 hours can never honor an hourly preference).
drop function if exists public.users_to_nudge(integer);

create or replace function public.users_to_nudge()
returns table (user_id uuid, fcm_token text, name text)
language sql
stable
security definer set search_path = public
as $$
  select p.id, p.fcm_token, p.name
  from public.profiles p
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
    and exists (
      select 1 from public.tasks t
      where t.user_id = p.id
        and t.archived_at is null
        and not exists (
          select 1 from public.task_completions c
          where c.task_id = t.id and c.completed_date = current_date
        )
    );
$$;

grant execute on function public.users_to_nudge() to service_role;

select cron.unschedule('send-nudges');
select cron.schedule('send-nudges', '0 * * * *', 'select public.trigger_send_nudges();');
