/// Shared between onboarding (where these are first picked) and
/// Settings' "Your onboarding answers" screen (where they can be
/// changed later) so the two never drift apart — same pattern as
/// check_in_frequency.dart.
const goalOptions = ['Get more done', 'Build habits', 'Spend less', 'Get healthier'];
const procrastinationOptions = ['Exercise', 'Chores', 'Work deadlines', 'Sleeping on time', 'Spending less'];
const dailyRoutineOptions = ['Early riser', 'Standard 9-to-5 kind of day', 'Night owl', 'Pretty irregular'];
const dailyRoutineSubs = [
  'Up before 7, done by dinner',
  'Weekday rhythm, protected evenings',
  'Peak focus after 21:00',
  'Shifts, travel, no fixed week',
];
const livingSituationOptions = ['On my own', 'With a partner or spouse', 'With family', 'With roommates'];
const livingSituationSubs = [
  'Nobody else picks up the slack',
  'Shared chores, shared blame',
  'Kids, parents, or both',
  'The dishes are political',
];
const motivationStyleOptions = ['Gentle encouragement', 'Tough love, tell it straight', 'A mix of both'];
const motivationStyleSubs = [
  'Warm, patient, never sharp',
  'She will bring up the streak you dropped',
  "Kind until you've stalled twice",
];
