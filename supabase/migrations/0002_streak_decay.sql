-- Nightly streak decay: for every recurring task with no completion
-- yesterday, either consume a streak freeze (freeze count -1, streak
-- kept) or break the streak to 0. Run once a day, after midnight UTC,
-- via pg_cron:
--
--   select cron.schedule('decay-streaks', '5 0 * * *', 'select public.decay_streaks();');
--
-- (pg_cron must be enabled for the project under Database > Extensions
-- first; scheduling itself can't be done from a plain migration file
-- since it depends on the project's pg_cron installation.)
create function public.decay_streaks()
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  -- Consume a freeze where available.
  update public.tasks t
  set streak_freezes_available = t.streak_freezes_available - 1
  where t.recurrence <> 'none'
    and t.archived_at is null
    and t.streak_freezes_available > 0
    and not exists (
      select 1 from public.task_completions c
      where c.task_id = t.id
        and c.completed_date = (current_date - interval '1 day')::date
    );

  -- Break the streak where no freeze was available.
  update public.tasks t
  set streak_count = 0
  where t.recurrence <> 'none'
    and t.archived_at is null
    and t.streak_freezes_available = 0
    and t.streak_count > 0
    and not exists (
      select 1 from public.task_completions c
      where c.task_id = t.id
        and c.completed_date = (current_date - interval '1 day')::date
    );

  -- Grant a freeze for every completed 7-day streak, capped at 3.
  update public.tasks t
  set streak_freezes_available = least(t.streak_freezes_available + 1, 3)
  where t.recurrence <> 'none'
    and t.archived_at is null
    and t.streak_count > 0
    and t.streak_count % 7 = 0
    and exists (
      select 1 from public.task_completions c
      where c.task_id = t.id
        and c.completed_date = (current_date - interval '1 day')::date
    );
end;
$$;
