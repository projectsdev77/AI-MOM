// Quiet hours: the stretch of the day Mom's push nudges stay silent. Whole
// hours only, in the person's own timezone. A start later than the end means
// it runs past midnight (10 PM to 7 AM).

const defaultQuietFromHour = 22;
const defaultQuietUntilHour = 7;

/// 0 -> "12 AM", 7 -> "7 AM", 12 -> "12 PM", 22 -> "10 PM".
String formatHour(int hour) {
  final h = hour % 24;
  final suffix = h < 12 ? 'AM' : 'PM';
  final twelve = h % 12 == 0 ? 12 : h % 12;
  return '$twelve $suffix';
}

/// True when the two hours describe a real window. Equal hours would mean
/// either no time or all day, so they are not allowed while quiet hours are on.
bool isValidQuietWindow({required bool enabled, required int from, required int until}) =>
    !enabled || from != until;

/// What the Settings row shows on its right.
String quietHoursLabel({required bool enabled, required int from, required int until}) {
  if (!enabled || from == until) return 'Off';
  return '${formatHour(from)} – ${formatHour(until)}';
}
