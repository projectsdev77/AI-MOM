// Decides WHAT a nudge is about, from facts about the person. The wording
// lives in copy.ts; the database reads live in facts.ts. Everything here
// is a pure function of its inputs, so it can be exercised without a
// database or Firebase.
//
// A nudge is always exactly one message about exactly one topic. Tasks
// are open to everyone. Health and finance are Full-plan only. For a Full
// user the topic rotates: whichever topic was used last time is skipped
// when anything else has something to say, so a run of nudges mixes tasks,
// health and finance instead of repeating one.

import type { Intent, Tag, Vars } from './copy.ts';

export type Topic = 'tasks' | 'health' | 'finance';

export interface PendingTask {
  title: string;
  category: string;
  // Optional so a response from a database that hasn't had the latest
  // migration yet still works; the nudge just has less to go on.
  recurrence?: string; // 'none' | 'daily' | 'weekly' | 'custom'
  streak_count?: number;
}

export interface Candidate {
  user_id: string;
  fcm_token: string;
  name: string | null;
  motivation_style: string | null;
  procrastination_areas: string[] | null;
  plan: string;
  timezone: string | null;
  last_nudge_topic: string | null;
  pending_count: number;
  pending_tasks: PendingTask[] | null;
  // Onboarding answers (0015_nudge_onboarding_answers.sql). Optional for the
  // same reason as PendingTask's extras.
  goals?: string[] | null;
  daily_routine?: string | null;
  living_situation?: string | null;
  // Only whether a stressor was given, never its text: see that migration.
  has_stressor?: boolean | null;
}

export interface HealthFacts {
  // null when they never set that goal (no health_goals row).
  waterTarget: number | null;
  sleepTargetHours: number | null;
  workoutTargetMinutes: number | null;
  waterCount: number;
  sleepHours: number | null;
  workoutMinutes: number;
  activities: { title: string; targetMinutes: number; minutes: number }[];
}

export interface FinanceFacts {
  overallBudgetCents: number | null;
  monthSpentCents: number;
  categoryBudgetsCents: Record<string, number>;
  categorySpentCents: Record<string, number>;
  // null when they have never logged one, or the last one is over 30 days
  // old (they've stopped tracking, so reminding them would just be noise).
  daysSinceLastExpense: number | null;
  daysLeftInMonth: number;
}

export interface Facts {
  health: HealthFacts | null;
  finance: FinanceFacts | null;
}

export interface LocalTime {
  date: string; // YYYY-MM-DD in the person's own timezone
  hour: number; // 0 to 23 in the person's own timezone
  known: boolean; // false when their timezone is missing/unrecognised and UTC was used instead
  monthStart: string; // YYYY-MM-01 in the person's own timezone
  daysLeftInMonth: number;
}

export interface Chosen {
  topic: Topic;
  intent: Intent;
  vars: Vars;
  tags: Set<Tag>;
}

// Mirrors lib/core/constants/onboarding_options.dart's procrastinationOptions
// against the task category text the app actually stores (a built-in
// TaskCategory's lowercase .name, see add_task_sheet.dart).
const PROCRASTINATION_CATEGORY: Record<string, string> = {
  'Exercise': 'health',
  'Chores': 'chores',
  'Work deadlines': 'work',
  'Sleeping on time': 'health',
  'Spending less': 'money',
};

// Category alone misses most real tasks: people file "Go to the gym" under
// Personal, "Do laundry" under Personal, "Send the report" under whatever
// was selected. So a task also counts as one of the things they said they
// put off when its TITLE clearly says so. Kept to unambiguous words on
// purpose: a wrong callout ("same thing you always put off" about a task
// that isn't) is worse than a missed one.
const PROCRASTINATION_KEYWORDS: Record<string, RegExp> = {
  'Exercise': /\b(gym|workout|work out|exercise|jog|jogging|running|yoga|stretch|stretching|swim|swimming|lift|lifting|cardio|pilates|hike|hiking|walk|walking|pushups?|push-ups?|squats?)\b/i,
  'Chores': /\b(chores?|dish|dishes|laundry|clean|cleaning|vacuum|vacuuming|trash|garbage|tidy|sweep|mop|mopping|iron|ironing|declutter)\b/i,
  'Work deadlines': /\b(deadline|report|presentation|proposal|invoice|submit|assignment|slides|client|timesheet)\b/i,
  'Sleeping on time': /\b(sleep|bedtime|bed|alarm|wind down|lights out)\b/i,
  'Spending less': /\b(budget|savings|bills?|rent|subscriptions?|expenses?)\b/i,
};

/** Share of the time a matching task gets the callout instead of a plain line. */
const CALLOUT_SHARE = 0.6;

// The exact strings onboarding saves (lib/core/constants/onboarding_options.dart)
// mapped to the tags that make personalised lines eligible.
const GOAL_TAG: Record<string, Tag> = {
  'Get healthier': 'goal_healthier',
  'Spend less': 'goal_spend_less',
  'Get more done': 'goal_more_done',
  'Build habits': 'goal_habits',
};
const ROUTINE_TAG: Record<string, Tag> = {
  'Early riser': 'routine_early',
  'Standard 9-to-5 kind of day': 'routine_9to5',
  'Night owl': 'routine_night',
  'Pretty irregular': 'routine_irregular',
};
const LIVING_TAG: Record<string, Tag> = {
  'On my own': 'living_alone',
  'With a partner or spouse': 'living_partner',
  'With family': 'living_family',
  'With roommates': 'living_roommates',
};

// Which topic a stated goal is about. Someone who said they want to get
// healthier hears about health more often (and likewise for the others).
const GOAL_TOPIC: Record<string, Topic> = {
  'Get healthier': 'health',
  'Spend less': 'finance',
  'Get more done': 'tasks',
  'Build habits': 'tasks',
};

// How late in the day "you haven't logged last night's sleep" still makes
// sense, by daily routine. A night owl's night ends later.
const SLEEP_REMINDER_HOUR: Record<string, number> = {
  'Early riser': 12,
  'Pretty irregular': 15,
  'Night owl': 17,
};

/** What's true about this person right now, as tags for personalised lines. */
function profileTags(c: Candidate, local: LocalTime): Set<Tag> {
  const tags = new Set<Tag>();
  for (const goal of c.goals ?? []) if (GOAL_TAG[goal]) tags.add(GOAL_TAG[goal]);
  const routine = c.daily_routine ? ROUTINE_TAG[c.daily_routine] : undefined;
  if (routine) tags.add(routine);
  const living = c.living_situation ? LIVING_TAG[c.living_situation] : undefined;
  if (living) tags.add(living);
  if (c.has_stressor) tags.add('stressor');
  // From 7am: an early riser's lines shouldn't fire at 5am. This only
  // gates which lines are eligible; the night-time silence itself is
  // isQuietHour (nothing is sent from 22:00 until 07:00).
  if (local.hour >= 7 && local.hour < 12) tags.add('morning');
  if (local.hour >= 17 && local.hour < 23) tags.add('evening');
  return tags;
}

/** Whether this open task is one of the things they said they put off. */
export function matchesProcrastination(task: PendingTask, areas: string[]): boolean {
  return areas.some((area) =>
    PROCRASTINATION_CATEGORY[area] === task.category || PROCRASTINATION_KEYWORDS[area]?.test(task.title) === true
  );
}

// Share of a budget used before "you're getting close" is worth saying.
const NEAR_OVERALL = 0.8;
const NEAR_CATEGORY = 0.85;
// Logging reminders only make sense between these many days of silence.
const LOG_REMINDER_MIN_DAYS = 3;
export const LOG_LOOKBACK_DAYS = 30;
// A "you haven't logged your sleep" nudge is pointless late in the day.
// This is the default cutoff; SLEEP_REMINDER_HOUR adjusts it per routine.
const SLEEP_REMINDER_BEFORE_HOUR = 14;

const pad = (n: number) => String(n).padStart(2, '0');

/** "Today" for a person, in their own timezone (UTC if it's unknown). */
export function localTime(now: Date, timeZone: string | null): LocalTime {
  for (const zone of [timeZone, 'UTC']) {
    if (!zone) continue;
    const known = zone === timeZone;
    try {
      const parts = new Intl.DateTimeFormat('en-US', {
        timeZone: zone,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        hourCycle: 'h23',
      }).formatToParts(now);
      const num = (type: string) => Number(parts.find((p) => p.type === type)?.value);
      const year = num('year');
      const month = num('month');
      const day = num('day');
      const hour = num('hour');
      if ([year, month, day, hour].some(Number.isNaN)) continue;
      const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
      return {
        date: `${year}-${pad(month)}-${pad(day)}`,
        hour,
        known,
        monthStart: `${year}-${pad(month)}-01`,
        daysLeftInMonth: daysInMonth - day,
      };
    } catch {
      // Unrecognised timezone name: fall through to UTC.
    }
  }
  throw new Error('localTime: UTC should always resolve');
}

/** Mom stays quiet from 22:00 until 07:00 in the person's own timezone. */
export const QUIET_FROM_HOUR = 22;
export const QUIET_UNTIL_HOUR = 7;

/**
 * True when it is the middle of the night for them. If their timezone is
 * unknown the hour would only be a UTC guess, which is as likely to silence
 * their morning as to protect their night, so no quiet hours are applied.
 * (The app re-saves the timezone on every launch and return to the app, so
 * that gap closes itself.)
 */
export function isQuietHour(local: LocalTime): boolean {
  if (!local.known) return false;
  return local.hour >= QUIET_FROM_HOUR || local.hour < QUIET_UNTIL_HOUR;
}

export function daysBetween(from: string, to: string): number {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);
}

export function addDays(date: string, days: number): string {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

function firstName(name: string | null): string | undefined {
  const first = name?.trim().split(/\s+/)[0];
  return first ? first : undefined;
}

function shorten(title: string, max = 40): string {
  const t = title.trim();
  return t.length > max ? `${t.slice(0, max - 1).trimEnd()}…` : t;
}

interface Option {
  intent: Intent;
  vars: Vars;
  // Extra tags that apply only because of what this particular option is
  // about (e.g. the task it names is a habit).
  tags?: Tag[];
  // Within one topic only the highest-priority options compete, so being
  // over budget always beats a gentle logging reminder.
  priority: number;
}

function pick<T>(items: T[], rand: () => number): T {
  return items[Math.floor(rand() * items.length)];
}

function isHabit(t: PendingTask): boolean {
  return t.recurrence !== undefined && t.recurrence !== 'none';
}

function taskOptions(c: Candidate, name: string | undefined, rand: () => number): Option[] {
  const tasks = c.pending_tasks ?? [];
  if (c.pending_count <= 0 || tasks.length === 0) return [];

  const named = pick(tasks, rand);
  const options: Option[] = [
    {
      intent: 'task_named',
      vars: { task: shorten(named.title), name },
      tags: isHabit(named) ? ['task_habit'] : [],
      priority: 1,
    },
  ];
  if (c.pending_count >= 2) {
    options.push({ intent: 'task_count', vars: { count: c.pending_count, name }, priority: 1 });
  }
  const areas = c.procrastination_areas ?? [];
  const hit = tasks.find((t) => matchesProcrastination(t, areas));
  if (hit) {
    // The most personal thing Mom can say, so it wins most of the time,
    // but not always: the same callout every hour about the same task
    // would stop landing.
    options.push({
      intent: 'task_procrastinated',
      vars: { task: shorten(hit.title), name },
      priority: rand() < CALLOUT_SHARE ? 2 : 1,
    });
  }

  // For people whose goal is to build habits: a recurring task that's still
  // open today and has a streak worth protecting.
  if ((c.goals ?? []).includes('Build habits')) {
    const atRisk = tasks
      .filter((t) => isHabit(t) && (t.streak_count ?? 0) >= 2)
      .sort((a, b) => (b.streak_count ?? 0) - (a.streak_count ?? 0))[0];
    if (atRisk) {
      options.push({
        intent: 'habit_streak',
        vars: { task: shorten(atRisk.title), streak: atRisk.streak_count },
        priority: rand() < CALLOUT_SHARE ? 2 : 1,
      });
    }
  }
  return options;
}

function healthOptions(h: HealthFacts, hour: number, sleepCutoffHour: number, rand: () => number): Option[] {
  const options: Option[] = [];

  // "You haven't logged any X today" (priority 2) is the more useful thing
  // to say, so it outranks "you're partway there" (priority 1) whenever
  // both are on the table.
  if (h.waterTarget != null) {
    if (h.waterCount === 0) {
      options.push({ intent: 'water_unlogged', vars: { goal: h.waterTarget }, priority: 2 });
    } else if (h.waterCount < h.waterTarget) {
      options.push({
        intent: 'water',
        vars: { have: h.waterCount, goal: h.waterTarget, left: h.waterTarget - h.waterCount },
        priority: 1,
      });
    }
  }
  if (h.sleepTargetHours != null && h.sleepHours == null && hour < sleepCutoffHour) {
    options.push({ intent: 'sleep', vars: {}, priority: 2 });
  }
  if (h.workoutTargetMinutes != null && h.workoutMinutes < h.workoutTargetMinutes) {
    options.push({
      intent: 'workout',
      vars: {
        have: h.workoutMinutes,
        goal: h.workoutTargetMinutes,
        left: h.workoutTargetMinutes - h.workoutMinutes,
      },
      priority: 1,
    });
  }

  // At most one entry per kind however many activities there are, so
  // having many doesn't make activity nudges crowd out water and workout.
  const untouched = h.activities.filter((a) => a.minutes === 0);
  if (untouched.length > 0) {
    const a = pick(untouched, rand);
    options.push({
      intent: 'activity_unlogged',
      vars: { activity: shorten(a.title), goal: a.targetMinutes },
      priority: 2,
    });
  }
  const partway = h.activities.filter((a) => a.minutes > 0 && a.minutes < a.targetMinutes);
  if (partway.length > 0) {
    const a = pick(partway, rand);
    options.push({
      intent: 'activity',
      vars: { activity: shorten(a.title), have: a.minutes, goal: a.targetMinutes, left: a.targetMinutes - a.minutes },
      priority: 1,
    });
  }
  return options;
}

function financeOptions(f: FinanceFacts): Option[] {
  const options: Option[] = [];
  // "N days left" reads oddly at 1 or 0, so those lines just don't apply.
  const daysLeft = f.daysLeftInMonth >= 2 ? f.daysLeftInMonth : undefined;

  if (f.overallBudgetCents != null && f.overallBudgetCents > 0) {
    const ratio = f.monthSpentCents / f.overallBudgetCents;
    if (ratio > 1) {
      options.push({ intent: 'budget_over', vars: { daysLeft }, priority: 3 });
    } else if (ratio >= NEAR_OVERALL) {
      options.push({ intent: 'budget_near', vars: { pct: Math.round(ratio * 100), daysLeft }, priority: 2 });
    }
  }

  // Only the single worst category in each state, so a long list of
  // category budgets can't drown out everything else.
  let worstOver: { category: string; ratio: number } | null = null;
  let worstNear: { category: string; ratio: number } | null = null;
  for (const [category, budget] of Object.entries(f.categoryBudgetsCents)) {
    if (budget <= 0) continue;
    const ratio = (f.categorySpentCents[category] ?? 0) / budget;
    if (ratio > 1) {
      if (!worstOver || ratio > worstOver.ratio) worstOver = { category, ratio };
    } else if (ratio >= NEAR_CATEGORY) {
      if (!worstNear || ratio > worstNear.ratio) worstNear = { category, ratio };
    }
  }
  if (worstOver) options.push({ intent: 'category_over', vars: { category: worstOver.category }, priority: 3 });
  if (worstNear) {
    options.push({
      intent: 'category_near',
      vars: { category: worstNear.category, pct: Math.round(worstNear.ratio * 100) },
      priority: 2,
    });
  }

  if (f.daysSinceLastExpense != null && f.daysSinceLastExpense >= LOG_REMINDER_MIN_DAYS) {
    options.push({ intent: 'expense_log', vars: { days: f.daysSinceLastExpense }, priority: 1 });
  }
  return options;
}

/**
 * Picks the one thing this nudge will be about, or null when there is
 * nothing worth saying (which, for a Full user with no open tasks and
 * nothing off-track, is the normal quiet case: no push, and they stay
 * eligible for the next run).
 */
export function chooseNudge(
  candidate: Candidate,
  facts: Facts | undefined,
  local: LocalTime,
  rand: () => number = Math.random,
): Chosen | null {
  const name = firstName(candidate.name);
  const byTopic: Record<Topic, Option[]> = {
    tasks: taskOptions(candidate, name, rand),
    health: [],
    finance: [],
  };
  // Health and finance are a paid feature: the plan is checked here, not
  // just by whoever decides to fetch the facts.
  if (candidate.plan === 'full' && facts) {
    if (facts.health) {
      const cutoff = SLEEP_REMINDER_HOUR[candidate.daily_routine ?? ''] ?? SLEEP_REMINDER_BEFORE_HOUR;
      byTopic.health = healthOptions(facts.health, local.hour, cutoff, rand);
    }
    if (facts.finance) byTopic.finance = financeOptions(facts.finance);
  }

  const available = (Object.keys(byTopic) as Topic[]).filter((t) => byTopic[t].length > 0);
  if (available.length === 0) return null;

  // Rotate: skip the topic used last time unless it's the only one left.
  const fresh = available.filter((t) => t !== candidate.last_nudge_topic);
  const candidates = fresh.length > 0 ? fresh : available;
  // A topic that matches a stated goal counts double, so someone who said
  // they want to get healthier hears about health more, without it ever
  // crowding the others out entirely.
  const favoured = new Set((candidate.goals ?? []).map((g) => GOAL_TOPIC[g]).filter(Boolean));
  const weighted = candidates.flatMap((t) => (favoured.has(t) ? [t, t] : [t]));
  const topic = pick(weighted, rand);

  const options = byTopic[topic];
  const top = Math.max(...options.map((o) => o.priority));
  const chosen = pick(options.filter((o) => o.priority === top), rand);
  const tags = profileTags(candidate, local);
  for (const t of chosen.tags ?? []) tags.add(t);
  return { topic, intent: chosen.intent, vars: chosen.vars, tags };
}
