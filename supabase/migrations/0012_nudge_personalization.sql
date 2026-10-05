-- users_to_nudge previously returned just enough to send a generic
-- push (id, token, name) — the send-nudges edge function then picked
-- one of three fixed, generic lines at random regardless of who the
-- nudge was actually for. This adds what the edge function needs to
-- make the copy feel like it's actually from someone who knows this
-- user: their motivation_style (to pick a tone — tough love vs
-- gentle vs a mix, same split mom-chat already uses), their
-- procrastination_areas (to call out when a pending task is exactly
-- the kind of thing they said they put off), and up to 3 of today's
-- actual pending task titles + categories (so the nudge can name a
-- real task instead of vaguely gesturing at "today's list").
--
-- Dropped first because Postgres won't change a function's return
-- columns through `create or replace` (same reason 0010 drops it).
drop function if exists public.users_to_nudge();

create function public.users_to_nudge()
returns table (
  user_id uuid,
  fcm_token text,
  name text,
  motivation_style text,
  procrastination_areas text[],
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
    (
      select coalesce(jsonb_agg(jsonb_build_object('title', pt.title, 'category', pt.category)), '[]'::jsonb)
      from (
        select t.title, t.category
        from public.tasks t
        where t.user_id = p.id
          and t.archived_at is null
          and not exists (
            select 1 from public.task_completions c
            where c.task_id = t.id and c.completed_date = current_date
          )
        order by t.created_at
        limit 3
      ) pt
    ) as pending_tasks
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
