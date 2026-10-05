// What Mom actually says in a nudge. Kept separate from the sending and
// data-gathering code so the wording can be edited, or read top to bottom,
// without touching anything that talks to Firebase or the database.
//
// Voice rules for anything added here (these are what keep it from
// reading like generic AI copy):
//   - Name the real thing (the task, the number, the category), never
//     "your list" in the abstract when there's a specific item to quote.
//   - Short and plain, the way a mom texts, with contractions. No
//     cheerleading filler like "you've got this" or "no pressure", no em
//     dashes, no "N other things" tacked onto a task name.
//   - Never quote money amounts: the app's display currency lives only on
//     the device, so the server doesn't know whether $ or something else
//     is right. Percentages and counts are always safe.
//
// A {token} in a line is only usable when that value exists; a line with
// a missing token is skipped rather than rendered with a hole in it. That
// is how {name} lines quietly drop out for someone with no name set.
// Lines are template literals so they can hold both kinds of quote.

export type Tone = 'tough' | 'gentle' | 'mix';

export type Intent =
  | 'task_named'
  | 'task_count'
  | 'task_procrastinated'
  | 'habit_streak'
  | 'water'
  | 'water_unlogged'
  | 'sleep'
  | 'workout'
  | 'activity'
  | 'activity_unlogged'
  | 'budget_near'
  | 'budget_over'
  | 'category_near'
  | 'category_over'
  | 'expense_log';

export type Vars = Record<string, string | number | undefined>;

/**
 * Facts about the person (from onboarding) or the moment that make an extra
 * line eligible. topics.ts decides which apply; PERSONAL below says which
 * lines need which. Typed so a line can't ask for a tag nothing produces.
 */
export type Tag =
  | 'goal_healthier'
  | 'goal_spend_less'
  | 'goal_more_done'
  | 'goal_habits'
  | 'routine_early'
  | 'routine_9to5'
  | 'routine_night'
  | 'routine_irregular'
  | 'living_alone'
  | 'living_partner'
  | 'living_family'
  | 'living_roommates'
  | 'stressor'
  | 'morning'
  | 'evening'
  | 'task_habit';

/** Of the time a usable personalised line is picked over a generic one. */
const PERSONAL_SHARE = 0.6;

interface PersonalLine {
  needs: Tag[];
  text: string;
}
const p = (needs: Tag[], text: string): PersonalLine => ({ needs, text });

const COPY: Record<Intent, Record<Tone, string[]>> = {
  // {task} is one real open task. {name} is the person's first name.
  task_named: {
    tough: [
      `"{task}" is still sitting there. Handle it.`,
      `{name}, "{task}". Today. I'm not asking twice.`,
      `You said you'd do "{task}". I'm just holding you to it.`,
      `Still no "{task}". Whenever you're done avoiding it.`,
      `"{task}" takes less time than you've spent dodging it.`,
      `Go do "{task}" and then you can ignore me again.`,
      `I can see "{task}" is still open. So can you.`,
    ],
    gentle: [
      `"{task}" is still on your list whenever you feel ready for it.`,
      `Hey {name}, "{task}" is waiting. Maybe start with five minutes?`,
      `Maybe "{task}" is a good one to tick off before the day ends.`,
      `"{task}" is still open. Take a breath, then a small first step.`,
      `Thinking of you. "{task}" is still on the list, no judgment.`,
      `When you have a free moment, "{task}" would feel good to cross off.`,
    ],
    mix: [
      `"{task}" is still open. Ten minutes and it's gone.`,
      `Still got "{task}" on the list, {name}. Knock it out and I'll leave you alone.`,
      `"{task}" is waiting on you. Today's a good day for it.`,
      `Did "{task}" get done? It's still showing as open.`,
      `Cross off "{task}" and you can relax.`,
      `You've got time for "{task}" right now. Go on.`,
    ],
  },

  // {count} is how many open tasks there are today (always 2 or more).
  task_count: {
    tough: [
      `{count} things still open today. Pick one and move.`,
      `{count} tasks left. They're not getting shorter.`,
      `Your list still has {count} things on it. Start with the smallest.`,
      `{count} open. Zero excuses. Go.`,
    ],
    gentle: [
      `You have {count} things left today. Pick the easiest and start there.`,
      `{count} things still open. One at a time is fine.`,
      `Today has {count} left on it. Start with whichever feels lightest.`,
      `{count} to go, {name}. You're closer than it feels.`,
    ],
    mix: [
      `{count} things left on today's list. Grab one.`,
      `Still {count} open today. Start with the quick one.`,
      `{count} tasks to go. Pick one and I'll stop texting.`,
      `Your list has {count} open items. Open it and pick one.`,
    ],
  },

  // {task} is a recurring task that is still open today and has a streak of
  // {streak} days (2 or more), for people whose goal is to build habits.
  habit_streak: {
    tough: [
      `Your {streak} day streak on "{task}" dies today if you skip it.`,
      `{streak} days in a row on "{task}". Don't throw it away.`,
      `Do "{task}" or lose your {streak} day streak. Your call.`,
    ],
    gentle: [
      `You've kept "{task}" going for {streak} days. Today is the next one.`,
      `{streak} days of "{task}" so far. You've built something, so keep it going.`,
      `Your {streak} day streak on "{task}" is worth protecting.`,
    ],
    mix: [
      `{streak} days in a row on "{task}". Keep it going today.`,
      `"{task}" is at {streak} days. Don't break it now.`,
      `Your streak on "{task}" is {streak} days. One more today.`,
    ],
  },

  // {task} is an open task whose category matches something they said at
  // onboarding that they put off.
  task_procrastinated: {
    tough: [
      `"{task}" again? That's exactly what you told me you put off. Today, not tomorrow.`,
      `I know "{task}" is your thing to avoid. Do it anyway.`,
      `"{task}" is the one you always dodge. Not today.`,
      `"{task}" is exactly what you said you put off. Do it now.`,
      `I know what you do with "{task}". You avoid it. Not today.`,
    ],
    gentle: [
      `"{task}" is the kind of thing you find hard to start. Just do the first minute.`,
      `I know "{task}" isn't easy to get going on. A small start counts.`,
      `You told me this kind of thing is hard to begin. "{task}" can be tiny today.`,
      `"{task}" is the kind of thing you tend to put off. Just open it and see.`,
      `Starting "{task}" is the hardest part for you. Make it tiny and begin.`,
    ],
    mix: [
      `"{task}" is on the list, and I remember it's your weak spot. Start small.`,
      `This is the kind of task you said you put off. "{task}" is waiting.`,
      `"{task}" again. You know the drill, and I know you. Go.`,
      `"{task}" is one of the things you put off. Do five minutes and see.`,
      `Putting off "{task}" again? Five minutes, then decide.`,
    ],
  },

  // {have}/{goal} are glasses of water today, {left} is what is missing.
  water: {
    tough: [
      `{have} of {goal} glasses of water. Go drink something.`,
      `Water: {have} out of {goal}. {left} more to go. Move.`,
      `You're at {have} glasses. The goal is {goal}. Do the math and drink.`,
      `{left} glasses to go today. Fill a cup.`,
    ],
    gentle: [
      `You're at {have} of {goal} glasses of water. A glass now would help.`,
      `{left} more glasses of water today and you hit your goal. Maybe one now?`,
      `Have you had some water lately? You're at {have} of {goal}.`,
      `Your body would like a glass of water. {have} of {goal} so far.`,
    ],
    mix: [
      `{have} of {goal} glasses so far. Grab one.`,
      `Water check: {have} down, {left} to go.`,
      `You're {left} glasses short of your water goal. Go refill.`,
      `Drink a glass of water. You're at {have} of {goal}.`,
    ],
  },

  // Nothing at all logged for water today ({goal} is their daily glasses
  // goal). Separate from `water`, which is for partial progress.
  water_unlogged: {
    tough: [
      `Not one glass of water logged today. Go drink one and log it.`,
      `You haven't logged any water today. The goal is {goal}. Start with one.`,
      `Zero water logged. Fix that.`,
      `Either you haven't been drinking or you haven't been logging. Both need fixing.`,
    ],
    gentle: [
      `You haven't logged any water today. A glass now would be a good start.`,
      `No water logged yet today. Maybe grab a glass and tap it in?`,
      `Have you had any water today? Nothing's logged yet.`,
    ],
    mix: [
      `No water logged today. The goal is {goal} glasses, so start with one.`,
      `Nothing logged for water yet. Grab a glass, then log it.`,
      `Water's still at zero for today. Go fix that.`,
      `Quick one: have you had water today? Nothing's logged yet.`,
    ],
  },

  // No sleep logged yet today.
  sleep: {
    tough: [
      `You haven't logged last night's sleep. It takes ten seconds.`,
      `How did you sleep? Log it.`,
      `No sleep logged yet today. Log it before you forget.`,
    ],
    gentle: [
      `How did you sleep last night? You can log it whenever.`,
      `Whenever you're ready, log how you slept. It helps me look out for you.`,
      `Tell me how you slept and I'll note it down.`,
    ],
    mix: [
      `How did you sleep? Log your hours in Health.`,
      `No sleep logged for today yet. Quick tap in Health.`,
      `Sleep hours aren't logged yet. Takes a few seconds.`,
    ],
  },

  // {have}/{goal}/{left} are workout minutes today.
  workout: {
    tough: [
      `{have} of {goal} workout minutes. {left} to go. Get moving.`,
      `Your workout goal is {goal} minutes. You're at {have}. Don't skip it.`,
      `{left} minutes of exercise still owed today.`,
    ],
    gentle: [
      `You're at {have} of {goal} minutes of movement. Even a short walk helps.`,
      `A little movement today? You still have {left} minutes to your goal.`,
      `{left} minutes to go on your movement goal. A stretch counts too.`,
    ],
    mix: [
      `{have} of {goal} workout minutes in. {left} to go.`,
      `Time to move a bit. You're {left} minutes from today's goal.`,
      `Workout check: {left} minutes left to hit your goal.`,
    ],
  },

  // {activity} is one of their own "stay active" activities.
  activity: {
    tough: [
      `{activity}: {have} of {goal} minutes. Finish it.`,
      `You set a goal for {activity}. {left} minutes left. Go.`,
      `{left} minutes of {activity} left today. Go get them.`,
    ],
    gentle: [
      `Some {activity} today? You're at {have} of {goal} minutes.`,
      `Still {left} minutes of {activity} to go whenever you're ready.`,
      `A bit of {activity} would get you to your goal. {left} minutes left.`,
    ],
    mix: [
      `{activity}: {have} of {goal} minutes so far.`,
      `{left} minutes of {activity} to reach today's goal.`,
      `Fit in some {activity} today? You're {left} minutes short.`,
    ],
  },

  // Nothing logged for one of their own activities today. {goal} is that
  // activity's daily minutes goal. Separate from `activity` (partial).
  activity_unlogged: {
    tough: [
      `Nothing logged for {activity} today. {goal} minutes is the goal. Get to it.`,
      `You haven't done any {activity} today. Or you didn't log it. Fix one of those.`,
      `{activity}: zero minutes today. Go.`,
    ],
    gentle: [
      `You haven't logged any {activity} today. Even ten minutes would be a start.`,
      `Nothing logged for {activity} yet. Whenever you're ready.`,
      `How's {activity} going today? Nothing's logged yet.`,
    ],
    mix: [
      `No {activity} logged today. The goal is {goal} minutes.`,
      `{activity} is still at zero today. Go log some.`,
      `Did you get any {activity} in? Nothing's logged yet.`,
    ],
  },

  // {pct} is how much of this month's overall budget is used (80 to 100).
  // {daysLeft} is only present when there are at least 2 days left.
  budget_near: {
    tough: [
      `You've burned through {pct}% of this month's budget with {daysLeft} days left. Watch it.`,
      `{pct}% of your budget is gone and the month isn't over. Think before you spend.`,
      `Budget is at {pct}%. Put the card down for a bit.`,
    ],
    gentle: [
      `You've used {pct}% of this month's budget. Might be worth slowing down a little.`,
      `{daysLeft} days left in the month and {pct}% of your budget is used. You can still steer this.`,
      `Just so you know, you're at {pct}% of your monthly budget.`,
    ],
    mix: [
      `You're at {pct}% of this month's budget with {daysLeft} days left.`,
      `Budget check: {pct}% used. Keep an eye on it.`,
      `{pct}% of the monthly budget is spent.`,
    ],
  },

  budget_over: {
    tough: [
      `You're over budget this month. Stop spending where you can.`,
      `Over budget with {daysLeft} days left. That's on you. Rein it in.`,
      `The budget's blown for this month. Don't make it worse.`,
    ],
    gentle: [
      `You've gone over this month's budget. It happens. Be easy on yourself and careful with the rest.`,
      `This month's budget is used up. Let's be careful for the next {daysLeft} days.`,
      `You passed your monthly budget. No guilt, just a fresh look at what's left.`,
    ],
    mix: [
      `You're over this month's budget. {daysLeft} days left, so go easy.`,
      `The budget's been passed for the month. Hold off on extras.`,
      `Over budget now. Worth a look at where it went.`,
    ],
  },

  // {category} is a category with its own budget, {pct} how much is used.
  category_near: {
    tough: [
      `{category} is at {pct}% of its budget. Slow down.`,
      `{pct}% of your {category} budget is gone. Watch it.`,
    ],
    gentle: [
      `{category} is at {pct}% of its budget. Worth a gentle look.`,
      `Your {category} budget is {pct}% used. Maybe ease off a bit.`,
    ],
    mix: [
      `{category} is at {pct}% of its budget.`,
      `Heads up, {category} is {pct}% used.`,
    ],
  },

  category_over: {
    tough: [
      `You blew through your {category} budget. Stop.`,
      `{category} is over budget. Cut it out for now.`,
    ],
    gentle: [
      `You've gone past your {category} budget. Next time you spend there, take a breath first.`,
      `{category} went over budget. It's okay, just notice it.`,
    ],
    mix: [
      `{category} is over its budget. Go easy there.`,
      `You've passed your {category} budget.`,
    ],
  },

  // {days} is how many days since they last logged an expense (3 to 30).
  expense_log: {
    tough: [
      `{days} days without logging a single expense. Log them.`,
      `I haven't seen an expense from you in {days} days. Don't tell me you spent nothing.`,
      `Your spending tracker is {days} days behind. Catch it up.`,
    ],
    gentle: [
      `It's been {days} days since you logged any spending. Want to catch up?`,
      `If you spent anything lately, you can log it now. It's been {days} days.`,
      `Whenever you have a minute, add what you've spent over the last {days} days.`,
    ],
    mix: [
      `No expenses logged in {days} days. Anything to add?`,
      `Your spending log has been quiet for {days} days. Catch it up when you can.`,
      `{days} days since your last logged expense. Add what you remember.`,
    ],
  },
};

// Lines that only make sense for someone who gave a particular answer at
// onboarding (or at a particular time of day). Used in preference to the
// generic lines above when they apply. See Tag for what each need means.
// Nothing here ever quotes the person's own free text: a stressor, for
// example, is only ever acknowledged ("a lot on your mind"), never repeated,
// because a push notification shows on the lock screen.
const PERSONAL: Partial<Record<Intent, Record<Tone, PersonalLine[]>>> = {
  task_named: {
    tough: [
      p(['routine_early', 'morning'], `You're up early. Use it on "{task}".`),
      p(['routine_night', 'evening'], `I know you come alive late. "{task}" still can't wait for midnight.`),
      p(['routine_9to5', 'evening'], `Work is over. "{task}" is next.`),
      p(['routine_irregular'], `No fixed schedule is not an excuse. "{task}", now.`),
      p(['living_alone'], `Nobody else is doing "{task}" for you. Go.`),
      p(['living_partner'], `Do "{task}" before it turns into a conversation at home.`),
      p(['living_family'], `Everyone at home has their own stuff going on. "{task}" is still yours.`),
      p(['living_roommates'], `Your roommates aren't doing "{task}" for you. Neither am I.`),
      p(['stressor'], `Stressed is exactly when you start avoiding things. Don't. "{task}".`),
      p(['goal_habits', 'task_habit'], `You said you want to build habits. "{task}" is one, and it's open.`),
    ],
    gentle: [
      p(['routine_early', 'morning'], `Mornings are your best time. "{task}" would feel good to finish early.`),
      p(['routine_night', 'evening'], `Your evening energy is coming. "{task}" would be a nice thing to finish with it.`),
      p(['routine_9to5', 'evening'], `You're done with work for the day. "{task}" is a nice small thing to close it out.`),
      p(['routine_irregular'], `No two days look the same for you, so let's pin "{task}" down right now.`),
      p(['living_alone'], `It's just you at home, so "{task}" is all yours. Maybe one small step?`),
      p(['living_partner'], `Maybe finish "{task}" so your evening together can be lighter.`),
      p(['living_family'], `Home can be busy. Find five quiet minutes for "{task}".`),
      p(['living_roommates'], `Maybe find a quiet corner at home for "{task}"?`),
      p(['stressor'], `I know you've got a lot on your mind. "{task}" is a small one to take off the pile.`),
      p(['goal_habits', 'task_habit'], `You told me you want to build habits. "{task}" today is one more small proof.`),
    ],
    mix: [
      p(['routine_early', 'morning'], `You're an early riser, so "{task}" is easy to knock out before the day gets going.`),
      p(['routine_night', 'evening'], `Night owl hours are close. Get "{task}" done before you go full gremlin.`),
      p(['routine_9to5', 'evening'], `Workday's over. "{task}" is still waiting.`),
      p(['routine_irregular'], `Your days don't follow a pattern, so "{task}" won't remind itself. Do it now.`),
      p(['living_alone'], `You live on your own, so "{task}" is on you. Ten minutes.`),
      p(['living_partner'], `"{task}" is still open. Get it done and it's one less thing to talk about at home.`),
      p(['living_family'], `Get "{task}" done before the house gets busy.`),
      p(['living_roommates'], `Shared house, shared noise. Carve out ten minutes for "{task}".`),
      p(['stressor'], `A lot going on lately, I know. Getting "{task}" done clears some head space.`),
      p(['goal_habits', 'task_habit'], `Building habits means showing up. "{task}" is waiting.`),
    ],
  },

  task_count: {
    tough: [
      p(['goal_more_done'], `You wanted to get more done. {count} things still open today.`),
      p(['stressor'], `Stress is when momentum matters most. {count} things left. Start.`),
      p(['routine_9to5', 'evening'], `Work's done for the day. {count} things still open.`),
    ],
    gentle: [
      p(['goal_more_done'], `You told me you want to get more done. {count} left today, and each one counts.`),
      p(['stressor'], `I know there's a lot on your mind. {count} things left today, one at a time.`),
      p(['routine_9to5', 'evening'], `You're done with work. {count} things left today, whenever you're ready.`),
    ],
    mix: [
      p(['goal_more_done'], `Get-more-done check: {count} still open today.`),
      p(['stressor'], `A lot going on lately. {count} things left, and you can take them one at a time.`),
      p(['routine_9to5', 'evening'], `Workday's over. {count} things still open.`),
    ],
  },

  water: {
    tough: [p(['goal_healthier'], `You said you wanted to get healthier. {have} of {goal} glasses says otherwise.`)],
    gentle: [p(['goal_healthier'], `You told me you want to get healthier. A glass of water is an easy start. {have} of {goal} so far.`)],
    mix: [p(['goal_healthier'], `Getting healthier starts small: {have} of {goal} glasses so far.`)],
  },
  water_unlogged: {
    tough: [p(['goal_healthier'], `You wanted to get healthier. Not one glass logged today.`)],
    gentle: [p(['goal_healthier'], `You told me you want to be healthier. A first glass of water today would be a nice start.`)],
    mix: [p(['goal_healthier'], `Getting healthier starts with a glass of water. Nothing logged yet today.`)],
  },
  sleep: {
    tough: [p(['goal_healthier'], `Getting healthier includes sleep. Log last night.`)],
    gentle: [p(['goal_healthier'], `You said you want to get healthier. How you slept is part of that. Log it when you can.`)],
    mix: [p(['goal_healthier'], `Healthy habits include sleep. Log how you slept.`)],
  },
  workout: {
    tough: [p(['goal_healthier'], `Getting healthier was your goal. {left} minutes of exercise left today.`)],
    gentle: [p(['goal_healthier'], `You said you wanted to get healthier. {left} minutes of movement would count today.`)],
    mix: [p(['goal_healthier'], `For the get-healthier plan: {left} minutes left to go today.`)],
  },
  activity: {
    tough: [p(['goal_healthier'], `You wanted to get healthier. {left} minutes of {activity} left.`)],
    gentle: [p(['goal_healthier'], `Your health goal would love {left} more minutes of {activity}.`)],
    mix: [p(['goal_healthier'], `Get-healthier plan: {left} more minutes of {activity}.`)],
  },
  activity_unlogged: {
    tough: [p(['goal_healthier'], `You wanted to get healthier. No {activity} logged today.`)],
    gentle: [p(['goal_healthier'], `You told me you want to get healthier. Even a little {activity} today would help.`)],
    mix: [p(['goal_healthier'], `Getting healthier means some {activity}. Nothing's logged today.`)],
  },

  budget_near: {
    tough: [p(['goal_spend_less'], `You said you wanted to spend less. {pct}% of your budget is gone.`)],
    gentle: [p(['goal_spend_less'], `You told me you want to spend less. You're at {pct}% of this month's budget.`)],
    mix: [p(['goal_spend_less'], `Spend-less goal check: {pct}% of the budget is used.`)],
  },
  budget_over: {
    tough: [p(['goal_spend_less'], `You said you wanted to spend less. You're over budget.`)],
    gentle: [p(['goal_spend_less'], `You told me you want to spend less. You're over budget this month, so this is a good time to pause.`)],
    mix: [p(['goal_spend_less'], `Spending less was the plan, and the budget's been passed. Time to pull back.`)],
  },
  category_near: {
    tough: [p(['goal_spend_less'], `You wanted to spend less. {category} is at {pct}% of its budget.`)],
    gentle: [p(['goal_spend_less'], `Since you want to spend less, {category} at {pct}% of its budget is worth a look.`)],
    mix: [p(['goal_spend_less'], `Spend-less check: {category} is at {pct}% of budget.`)],
  },
  category_over: {
    tough: [p(['goal_spend_less'], `You wanted to spend less. {category} is over budget.`)],
    gentle: [p(['goal_spend_less'], `You told me you want to spend less. {category} went over budget, so maybe pause there.`)],
    mix: [p(['goal_spend_less'], `Spend-less goal: {category} is already over budget.`)],
  },
  expense_log: {
    tough: [p(['goal_spend_less'], `You said you want to spend less. You can't if you don't track it. {days} days without a log.`)],
    gentle: [p(['goal_spend_less'], `Tracking helps you spend less. It's been {days} days since you logged anything.`)],
    mix: [p(['goal_spend_less'], `Spending less starts with tracking. {days} days since your last log.`)],
  },
};

export function toneFor(motivationStyle: string | null | undefined): Tone {
  if (motivationStyle === 'Tough love, tell it straight') return 'tough';
  if (motivationStyle === 'Gentle encouragement') return 'gentle';
  // "A mix of both", and anyone who skipped the question.
  return 'mix';
}

const TOKEN = /\{(\w+)\}/g;

function hasValues(template: string, vars: Vars): boolean {
  for (const match of template.matchAll(TOKEN)) {
    const value = vars[match[1]];
    if (value === undefined || value === '') return false;
  }
  return true;
}

/**
 * Picks and fills in one line. A line is only eligible when every {token}
 * in it has a value, and (for personalised lines) every tag it needs is
 * present. When any personalised line is eligible it's chosen most of the
 * time, since "you told me you want to spend less" is the point of having
 * asked; generic lines cover the rest and everyone who has no match.
 */
export function renderNudge(
  intent: Intent,
  tone: Tone,
  vars: Vars,
  tags: ReadonlySet<Tag> = new Set(),
  rand: () => number = Math.random,
): string {
  const generic = COPY[intent][tone].filter((t) => hasValues(t, vars));
  const personal = (PERSONAL[intent]?.[tone] ?? [])
    .filter((l) => l.needs.every((n) => tags.has(n)) && hasValues(l.text, vars))
    .map((l) => l.text);

  const pool = personal.length > 0 && (generic.length === 0 || rand() < PERSONAL_SHARE) ? personal : generic;
  if (pool.length === 0) throw new Error(`No usable ${tone} line for ${intent}`);
  const template = pool[Math.floor(rand() * pool.length)];
  return template.replace(TOKEN, (_, key: string) => String(vars[key]));
}

/** Every line, for counting and for tests that scan the wording. */
export function allLines(): { intent: Intent; tone: Tone; line: string; needs: Tag[] }[] {
  const out: { intent: Intent; tone: Tone; line: string; needs: Tag[] }[] = [];
  for (const intent of Object.keys(COPY) as Intent[]) {
    for (const tone of Object.keys(COPY[intent]) as Tone[]) {
      for (const line of COPY[intent][tone]) out.push({ intent, tone, line, needs: [] });
      for (const l of PERSONAL[intent]?.[tone] ?? []) out.push({ intent, tone, line: l.text, needs: l.needs });
    }
  }
  return out;
}
