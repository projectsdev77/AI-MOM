-- Server-side plumbing for Mom's proactive nudges: a function that picks
-- who's due for one, and a pg_cron job that calls the send-nudges edge
-- function periodically. The edge function itself decides what to say
-- and does the actual FCM send — this file only decides *who* and *when
-- to ask*.

-- Anyone with a registered device, nudges turned on, not nudged within
-- min_gap_hours, and at least one active task not yet completed today.
create or replace function public.users_to_nudge(min_gap_hours integer default 4)
returns table (user_id uuid, fcm_token text, name text)
language sql
stable
security definer set search_path = public
as $$
  select p.id, p.fcm_token, p.name
  from public.profiles p
  where p.fcm_token is not null
    and p.push_nudges_enabled
    and (p.last_nudged_at is null or p.last_nudged_at < now() - (min_gap_hours || ' hours')::interval)
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

grant execute on function public.users_to_nudge(integer) to service_role;

-- pg_net lets Postgres make an HTTP call from a cron job; pg_cron runs
-- that call on a schedule. Both must be enabled for the project first
-- (Database > Extensions in the Supabase dashboard) — same requirement
-- as the decay-streaks job in 0002_streak_decay.sql.
create extension if not exists pg_net with schema extensions;

-- The project URL and service role key are read from Supabase Vault
-- rather than hardcoded here, so this migration file never contains a
-- real secret. Before this job can actually fire, run once in the
-- Supabase SQL editor (see README's push-notifications setup section):
--   select vault.create_secret('https://YOUR-PROJECT.supabase.co', 'project_url');
--   select vault.create_secret('YOUR-SERVICE-ROLE-KEY', 'service_role_key');
create or replace function public.trigger_send_nudges()
returns void
language plpgsql
security definer set search_path = public, extensions, vault
as $$
declare
  project_url text;
  service_role_key text;
begin
  select decrypted_secret into project_url from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into service_role_key from vault.decrypted_secrets where name = 'service_role_key';

  if project_url is null or service_role_key is null then
    raise notice 'send-nudges: project_url/service_role_key not set in Vault yet, skipping';
    return;
  end if;

  perform net.http_post(
    url := project_url || '/functions/v1/send-nudges',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || service_role_key,
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
end;
$$;

select cron.schedule('send-nudges', '0 */2 * * *', 'select public.trigger_send_nudges();');
