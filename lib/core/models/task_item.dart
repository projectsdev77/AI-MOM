import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/widgets.dart';

import '../widgets/category_chip.dart';

/// [other] is the fallback icon/tint "kind" for any custom category text
/// that doesn't match one of the built-in names — see
/// [TasksRepository._parseCategoryKind] in tasks_repository.dart. It's
/// deliberately not offered as a pickable chip in the add-task sheet;
/// picking "Custom" there and typing a label is what produces it.
enum TaskCategory { chores, work, health, money, personal, education, other }

extension TaskCategoryX on TaskCategory {
  String get label => switch (this) {
        TaskCategory.chores => 'Chores',
        TaskCategory.work => 'Work',
        TaskCategory.health => 'Health',
        TaskCategory.money => 'Money',
        TaskCategory.personal => 'Personal',
        TaskCategory.education => 'Education',
        TaskCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        TaskCategory.chores => LucideIcons.home,
        TaskCategory.work => LucideIcons.briefcase,
        TaskCategory.health => LucideIcons.heartPulse,
        TaskCategory.money => LucideIcons.wallet,
        TaskCategory.personal => LucideIcons.user,
        TaskCategory.education => LucideIcons.graduationCap,
        TaskCategory.other => LucideIcons.tag,
      };

  ChipTint get tint => switch (this) {
        TaskCategory.chores => ChipTint.tan,
        TaskCategory.work => ChipTint.sage,
        TaskCategory.health => ChipTint.blush,
        TaskCategory.money => ChipTint.peach,
        TaskCategory.personal => ChipTint.sage,
        TaskCategory.education => ChipTint.blush,
        TaskCategory.other => ChipTint.tan,
      };
}

enum RecurrenceType { none, daily, weekly, custom }

/// Unified task/habit model — a one-off task is just a [Task] with
/// [recurrence] set to [RecurrenceType.none]. See planning notes: tasks
/// and habits are deliberately the same entity, not separate features.
class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.category,
    required this.categoryLabel,
    required this.createdAt,
    this.recurrence = RecurrenceType.none,
    this.recurrenceDays,
    this.streakCount = 0,
    this.streakFreezesAvailable = 0,
    this.done = false,
    this.dueTime,
  });

  final String id;
  final String title;

  /// The icon/tint "kind" — [TaskCategory.other] for any custom category.
  final TaskCategory category;

  /// The text to actually show — a built-in category's pretty label, or
  /// the user's own custom text verbatim.
  final String categoryLabel;
  final DateTime createdAt;
  final RecurrenceType recurrence;

  /// ISO weekday numbers (1=Mon..7=Sun) — only set for
  /// [RecurrenceType.custom]. [RecurrenceType.weekly] instead repeats on
  /// whichever weekday [createdAt] falls on, so it doesn't need this.
  final List<int>? recurrenceDays;
  final int streakCount;
  final int streakFreezesAvailable;
  final bool done;
  final String? dueTime;

  bool get isHabit => recurrence != RecurrenceType.none;

  /// Whether this task belongs on the calendar for [day] — a daily habit
  /// applies to every day, a weekly one repeats on the weekday it was
  /// created, a custom one repeats on its own chosen weekdays, and a
  /// one-off task only ever belongs on the day it was made.
  bool appliesToDay(DateTime day) {
    switch (recurrence) {
      case RecurrenceType.none:
        return _isSameDate(createdAt, day);
      case RecurrenceType.daily:
        return true;
      case RecurrenceType.weekly:
        return createdAt.weekday == day.weekday;
      case RecurrenceType.custom:
        return recurrenceDays?.contains(day.weekday) ?? false;
    }
  }

  /// `dueTime` as stored is `HH:mm:ss` (Postgres `time`) — this turns
  /// it into "8:00 AM" for display, without pulling in a Flutter/intl
  /// dependency into this plain model file.
  String? get dueTimeLabel {
    final raw = dueTime;
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return raw;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  TaskItem copyWith({bool? done}) => TaskItem(
        id: id,
        title: title,
        category: category,
        categoryLabel: categoryLabel,
        createdAt: createdAt,
        recurrence: recurrence,
        recurrenceDays: recurrenceDays,
        streakCount: streakCount,
        streakFreezesAvailable: streakFreezesAvailable,
        done: done ?? this.done,
        dueTime: dueTime,
      );
}

bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
