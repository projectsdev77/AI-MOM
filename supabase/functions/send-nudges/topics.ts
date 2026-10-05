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

import type { Intent, Vars } from './copy.ts';

export type Topic = 'tasks' | 'health' | 'finance';

export interface PendingTask {
  title: string;
  category: string;
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
  monthStart: string; // YYYY-MM-01 in the person's own timezone
  daysLeftInMonth: number;
}

export interface Chosen {
  topic: Topic;
  intent: Intent;
  vars: Vars;
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

// Share of a budget used before "you're getting close" is worth saying.
const NEAR_OVERALL = 0.8;
const NEAR_CATEGORY = 0.85;
// Logging reminders only make sense between these many days of silence.
const LOG_REMINDER_MIN_DAYS = 3;
export const LOG_LOOKBACK_DAYS = 30;
// A "you haven't logged your sleep" nudge is pointless late in the day.
const SLEEP_REMINDER_BEFORE_HOUR = 14;

const pad = (n: number) => String(n).padStart(2, '0');

/** "Today" for a person, in their own timezone (UTC if it's unknown). */
export function localTime(now: Date, timeZone: string | null): LocalTime {
  for (const zone of [timeZone, 'UTC']) {
    if (!zone) continue;
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
        monthStart: `${year}-${pad(month)}-01`,
        daysLeftInMonth: daysInMonth - day,
      };
    } catch {
      // Unrecognised timezone name: fall through to UTC.
    }
  }
  throw new Error('localTime: UTC should always resolve');
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
  // Within one topic only the highest-priority options compete, so being
  // over budget always beats a gentle logging reminder.
  priority: number;
}

function pick<T>(items: T[], rand: () => number): T {
  return items[Math.floor(rand() * items.length)];
}

function taskOptions(c: Candidate, name: string | undefined, rand: () => number): Option[] {
  const tasks = c.pending_tasks ?? [];
  if (c.pending_count <= 0 || tasks.length === 0) return [];

  const options: Option[] = [
    { intent: 'task_named', vars: { task: shorten(pick(tasks, rand).title), name }, priority: 1 },
  ];
  if (c.pending_count >= 2) {
    options.push({ intent: 'task_count', vars: { count: c.pending_count, name }, priority: 1 });
  }
  const areas = c.procrastination_areas ?? [];
  const hit = tasks.find((t) => areas.some((a) => PROCRASTINATION_CATEGORY[a] === t.category));
  if (hit) {
    options.push({ intent: 'task_procrastinated', vars: { task: shorten(hit.title), name }, priority: 1 });
  }
  return options;
}

function healthOptions(h: HealthFacts, hour: number, rand: () => number): Option[] {
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
  if (h.sleepTargetHours != null && h.sleepHours == null && hour < SLEEP_REMINDER_BEFORE_HOUR) {
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
    if (facts.health) byTopic.health = healthOptions(facts.health, local.hour, rand);
    if (facts.finance) byTopic.finance = financeOptions(facts.finance);
  }

  const available = (Object.keys(byTopic) as Topic[]).filter((t) => byTopic[t].length > 0);
  if (available.length === 0) return null;

  // Rotate: skip the topic used last time unless it's the only one left.
  const fresh = available.filter((t) => t !== candidate.last_nudge_topic);
  const topic = pick(fresh.length > 0 ? fresh : available, rand);

  const options = byTopic[topic];
  const top = Math.max(...options.map((o) => o.priority));
  const chosen = pick(options.filter((o) => o.priority === top), rand);
  return { topic, intent: chosen.intent, vars: chosen.vars };
}
