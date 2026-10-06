import '../theme/mom_mood.dart';

/// What Mom says about today's list. Each mood has several lines; which one
/// shows depends on how many tasks there are and how many are done, so adding
/// a task or ticking one off moves to a different line even when the mood
/// stays the same. It is worked out from the numbers (not random), so the
/// line holds still while nothing changes.

String _items(int n) => n == 1 ? '1 thing' : '$n things';

List<String> momMessagesFor(MomMood mood, {required int done, required int total}) {
  final left = total - done;
  return switch (mood) {
    MomMood.proud => [
        'Look at you go. I might actually brag about you to your aunt.',
        left == 0
            ? 'All $total done. Who raised you so well? Oh, right — me.'
            : '$done of $total done. Who raised you so well? Oh, right — me.',
        left == 0 ? 'Nothing left on that list. I am not crying, you are crying.' : 'Only ${_items(left)} left. Don\'t stop now, sweetheart.',
        'This is how it\'s done. Keep it up and I\'ll make your favorite dinner.',
        'I see you getting things done. I\'m smiling, don\'t tell anyone.',
      ],
    MomMood.neutral => [
        'Not bad so far today. Keep going and I\'ll stop hovering over that to-do list.',
        '$done down, $left to go. You\'re getting there.',
        'Good start. Don\'t get comfortable yet.',
        'Still ${_items(left)} to do. I\'m watching. Quietly. With love.',
        'A little more and I\'ll be proud. No pressure. (Some pressure.)',
      ],
    MomMood.disappointed => [
        'A few things are slipping. I\'m not mad — just a little disappointed.',
        'Only $done of $total done. I know you can do better.',
        'That list isn\'t going to finish itself, sweetheart.',
        '${_items(left)} still waiting on you. Pick the easiest one and start.',
        'I didn\'t say anything. But I noticed.',
      ],
    MomMood.veryDisappointed => [
        'We need to talk. Open your task list before I start calling twice a day.',
        '$done of $total. Are we doing this today, or what?',
        '${_items(left)} on the list and zero excuses left.',
        'Don\'t make me come over there.',
        'Start with one small thing. Just one. For your mother.',
      ],
  };
}

/// The line to show right now. `total + 2 * done` moves by 1 for every task
/// added and 2 for every task ticked, so (with 5 lines) neither can land on the
/// same line; the day shifts it so tomorrow doesn't open with the same one.
String momTaskMessage({required MomMood mood, required int done, required int total, required DateTime day}) {
  final lines = momMessagesFor(mood, done: done, total: total);
  final dayKey = day.year * 400 + day.month * 31 + day.day;
  return lines[(total + 2 * done + dayKey) % lines.length];
}
