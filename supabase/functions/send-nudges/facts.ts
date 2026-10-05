// Reads the health and finance data a Full-plan nudge can talk about.
// Only ever called for paying users (index.ts filters on plan first), and
// batched: a fixed handful of queries per group of users, never a query
// per user.

import {
  addDays,
  daysBetween,
  type Facts,
  type FinanceFacts,
  type HealthFacts,
  type LocalTime,
  LOG_LOOKBACK_DAYS,
} from './topics.ts';

const PAGE = 1000; // PostgREST's default row cap per request
const BATCH = 40; // users per round of queries

// deno-lint-ignore no-explicit-any
type Client = any;

interface PagedResult<T> {
  data: T[] | null;
  error: { message: string } | null;
}

/** Walks every page of a query, since a bare select stops at 1000 rows. */
async function fetchAll<T>(build: (from: number, to: number) => PromiseLike<PagedResult<T>>): Promise<T[]> {
  const rows: T[] = [];
  for (let from = 0;; from += PAGE) {
    const { data, error } = await build(from, from + PAGE - 1);
    if (error) throw new Error(error.message);
    rows.push(...(data ?? []));
    if (!data || data.length < PAGE) return rows;
  }
}

interface GoalRow {
  user_id: string;
  water_target: number;
  sleep_target_hours: number;
  workout_target_minutes: number;
}
interface HealthLogRow {
  user_id: string;
  log_date: string;
  water_count: number;
  sleep_hours: number | string | null;
  workout_minutes: number;
}
interface ActivityRow {
  id: string;
  user_id: string;
  title: string;
  target_minutes: number;
}
interface ActivityLogRow {
  activity_id: string;
  log_date: string;
  minutes: number;
}
interface BudgetRow {
  user_id: string;
  category: string;
  amount_cents: number;
}
interface ExpenseRow {
  user_id: string;
  category: string;
  amount_cents: number;
  spent_at: string;
}

const OVERALL_BUDGET = 'overall'; // see FinanceRepository.overallBudgetCategory

export async function loadFacts(
  client: Client,
  users: { id: string; local: LocalTime }[],
): Promise<Map<string, Facts>> {
  const result = new Map<string, Facts>();
  for (let i = 0; i < users.length; i += BATCH) {
    for (const [id, facts] of await loadBatch(client, users.slice(i, i + BATCH))) result.set(id, facts);
  }
  return result;
}

async function loadBatch(client: Client, users: { id: string; local: LocalTime }[]): Promise<Map<string, Facts>> {
  const ids = users.map((u) => u.id);
  const dates = [...new Set(users.map((u) => u.local.date))];
  // Far enough back to cover both the whole current month and the
  // "30 days since your last expense" lookback, for everyone in the batch.
  const since = users.map((u) => addDays(u.local.date, -(LOG_LOOKBACK_DAYS + 2))).sort()[0];

  const [goals, logs, activities, budgets, expenses] = await Promise.all([
    fetchAll<GoalRow>((a, b) =>
      client
        .from('health_goals')
        .select('user_id, water_target, sleep_target_hours, workout_target_minutes')
        .in('user_id', ids)
        .order('user_id')
        .range(a, b)
    ),
    fetchAll<HealthLogRow>((a, b) =>
      client
        .from('health_logs')
        .select('user_id, log_date, water_count, sleep_hours, workout_minutes')
        .in('user_id', ids)
        .in('log_date', dates)
        .order('id')
        .range(a, b)
    ),
    fetchAll<ActivityRow>((a, b) =>
      client
        .from('health_activities')
        .select('id, user_id, title, target_minutes')
        .in('user_id', ids)
        .is('archived_at', null)
        .order('id')
        .range(a, b)
    ),
    fetchAll<BudgetRow>((a, b) =>
      client.from('budgets').select('user_id, category, amount_cents').in('user_id', ids).order('id').range(a, b)
    ),
    fetchAll<ExpenseRow>((a, b) =>
      client
        .from('expenses')
        .select('user_id, category, amount_cents, spent_at')
        .in('user_id', ids)
        .gte('spent_at', since)
        .order('id')
        .range(a, b)
    ),
  ]);

  const activityIds = activities.map((a) => a.id);
  const activityLogs = activityIds.length === 0 ? [] : await fetchAll<ActivityLogRow>((a, b) =>
    client
      .from('health_activity_logs')
      .select('activity_id, log_date, minutes')
      .in('activity_id', activityIds)
      .in('log_date', dates)
      .order('id')
      .range(a, b)
  );

  const goalsByUser = new Map(goals.map((g) => [g.user_id, g]));
  const logByUserDate = new Map(logs.map((l) => [`${l.user_id}|${l.log_date}`, l]));
  const minutesByActivityDate = new Map(activityLogs.map((l) => [`${l.activity_id}|${l.log_date}`, l.minutes]));
  const activitiesByUser = group(activities, (a) => a.user_id);
  const budgetsByUser = group(budgets, (b) => b.user_id);
  const expensesByUser = group(expenses, (e) => e.user_id);

  const out = new Map<string, Facts>();
  for (const { id, local } of users) {
    const goal = goalsByUser.get(id);
    const log = logByUserDate.get(`${id}|${local.date}`);
    const userActivities = (activitiesByUser.get(id) ?? []).map((a) => ({
      title: a.title,
      targetMinutes: a.target_minutes,
      minutes: minutesByActivityDate.get(`${a.id}|${local.date}`) ?? 0,
    }));

    const health: HealthFacts | null = goal || userActivities.length > 0
      ? {
        waterTarget: goal?.water_target ?? null,
        sleepTargetHours: goal ? Number(goal.sleep_target_hours) : null,
        workoutTargetMinutes: goal?.workout_target_minutes ?? null,
        waterCount: log?.water_count ?? 0,
        sleepHours: log?.sleep_hours != null ? Number(log.sleep_hours) : null,
        workoutMinutes: log?.workout_minutes ?? 0,
        activities: userActivities,
      }
      : null;

    const userBudgets = budgetsByUser.get(id) ?? [];
    const userExpenses = expensesByUser.get(id) ?? [];
    const finance: FinanceFacts | null = userBudgets.length > 0 || userExpenses.length > 0
      ? buildFinance(userBudgets, userExpenses, local)
      : null;

    out.set(id, { health, finance });
  }
  return out;
}

function buildFinance(budgets: BudgetRow[], expenses: ExpenseRow[], local: LocalTime): FinanceFacts {
  const categoryBudgetsCents: Record<string, number> = {};
  let overallBudgetCents: number | null = null;
  for (const b of budgets) {
    if (b.category === OVERALL_BUDGET) overallBudgetCents = b.amount_cents;
    else categoryBudgetsCents[b.category] = b.amount_cents;
  }

  let monthSpentCents = 0;
  const categorySpentCents: Record<string, number> = {};
  let lastExpense: string | null = null;
  for (const e of expenses) {
    if (lastExpense === null || e.spent_at > lastExpense) lastExpense = e.spent_at;
    if (e.spent_at >= local.monthStart) {
      monthSpentCents += e.amount_cents;
      categorySpentCents[e.category] = (categorySpentCents[e.category] ?? 0) + e.amount_cents;
    }
  }

  // spent_at defaults to the UTC date, which can be a day ahead of the
  // person's own, so a small negative is possible: treat it as "today".
  const sinceLast = lastExpense === null ? null : Math.max(0, daysBetween(lastExpense, local.date));
  return {
    overallBudgetCents,
    monthSpentCents,
    categoryBudgetsCents,
    categorySpentCents,
    daysSinceLastExpense: sinceLast !== null && sinceLast <= LOG_LOOKBACK_DAYS ? sinceLast : null,
    daysLeftInMonth: local.daysLeftInMonth,
  };
}

function group<T>(items: T[], key: (item: T) => string): Map<string, T[]> {
  const map = new Map<string, T[]>();
  for (const item of items) {
    const k = key(item);
    const list = map.get(k);
    if (list) list.push(item);
    else map.set(k, [item]);
  }
  return map;
}
