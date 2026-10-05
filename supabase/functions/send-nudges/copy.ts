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
  | 'water'
  | 'sleep'
  | 'workout'
  | 'activity'
  | 'budget_near'
  | 'budget_over'
  | 'category_near'
  | 'category_over'
  | 'expense_log';

export type Vars = Record<string, string | number | undefined>;

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

  // {task} is an open task whose category matches something they said at
  // onboarding that they put off.
  task_procrastinated: {
    tough: [
      `"{task}" again? That's exactly what you told me you put off. Today, not tomorrow.`,
      `I know "{task}" is your thing to avoid. Do it anyway.`,
      `"{task}" is the one you always dodge. Not today.`,
    ],
    gentle: [
      `"{task}" is the kind of thing you find hard to start. Just do the first minute.`,
      `I know "{task}" isn't easy to get going on. A small start counts.`,
      `You told me this kind of thing is hard to begin. "{task}" can be tiny today.`,
    ],
    mix: [
      `"{task}" is on the list, and I remember it's your weak spot. Start small.`,
      `This is the kind of task you said you put off. "{task}" is waiting.`,
      `"{task}" again. You know the drill, and I know you. Go.`,
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

export function toneFor(motivationStyle: string | null | undefined): Tone {
  if (motivationStyle === 'Tough love, tell it straight') return 'tough';
  if (motivationStyle === 'Gentle encouragement') return 'gentle';
  // "A mix of both", and anyone who skipped the question.
  return 'mix';
}

const TOKEN = /\{(\w+)\}/g;

function usable(template: string, vars: Vars): boolean {
  for (const match of template.matchAll(TOKEN)) {
    const value = vars[match[1]];
    if (value === undefined || value === '') return false;
  }
  return true;
}

export function renderNudge(
  intent: Intent,
  tone: Tone,
  vars: Vars,
  rand: () => number = Math.random,
): string {
  const pool = COPY[intent][tone].filter((t) => usable(t, vars));
  if (pool.length === 0) throw new Error(`No usable ${tone} line for ${intent}`);
  const template = pool[Math.floor(rand() * pool.length)];
  return template.replace(TOKEN, (_, key: string) => String(vars[key]));
}

/** Every line, for counting and for tests that scan the wording. */
export function allLines(): { intent: Intent; tone: Tone; line: string }[] {
  const out: { intent: Intent; tone: Tone; line: string }[] = [];
  for (const intent of Object.keys(COPY) as Intent[]) {
    for (const tone of Object.keys(COPY[intent]) as Tone[]) {
      for (const line of COPY[intent][tone]) out.push({ intent, tone, line });
    }
  }
  return out;
}
