-- Adds a 'Every 2 minutes (testing)' check-in frequency (see
-- lib/core/constants/check_in_frequency.dart) purely so the nudge
-- pipeline can be verified end-to-end from the onboarding screen
-- itself — pick it in onboarding, and once the cron schedule is
-- temporarily tightened (see supabase/scratch, or just run
-- `select cron.unschedule('send-nudges'); select cron.schedule(
-- 'send-nudges', '* * * * *', 'select public.trigger_send_nudges();');`
-- in the SQL editor while testing) nudges arrive roughly every 2
-- minutes instead of waiting an hour. Revert the cron schedule to
-- hourly afterward — this migration only teaches the gap function
-- about the new option, it does not change the schedule itself.
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
        when 'Every 2 minutes (testing)' then interval '2 minutes'
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
