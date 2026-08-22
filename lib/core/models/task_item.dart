import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/widgets.dart';

import '../widgets/category_chip.dart';

enum TaskCategory { chores, work, health, money, personal }

extension TaskCategoryX on TaskCategory {
  String get label => switch (this) {
        TaskCategory.chores => 'Chores',
        TaskCategory.work => 'Work',
        TaskCategory.health => 'Health',
        TaskCategory.money => 'Money',
        TaskCategory.personal => 'Personal',
      };

  IconData get icon => switch (this) {
        TaskCategory.chores => LucideIcons.home,
        TaskCategory.work => LucideIcons.briefcase,
        TaskCategory.health => LucideIcons.heartPulse,
        TaskCategory.money => LucideIcons.wallet,
        TaskCategory.personal => LucideIcons.user,
      };

  ChipTint get tint => switch (this) {
        TaskCategory.chores => ChipTint.tan,
        TaskCategory.work => ChipTint.sage,
        TaskCategory.health => ChipTint.blush,
        TaskCategory.money => ChipTint.peach,
        TaskCategory.personal => ChipTint.sage,
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
    this.recurrence = RecurrenceType.none,
    this.streakCount = 0,
    this.streakFreezesAvailable = 0,
    this.done = false,
    this.dueTime,
  });

  final String id;
  final String title;
  final TaskCategory category;
  final RecurrenceType recurrence;
  final int streakCount;
  final int streakFreezesAvailable;
  final bool done;
  final String? dueTime;

  bool get isHabit => recurrence != RecurrenceType.none;

  TaskItem copyWith({bool? done}) => TaskItem(
        id: id,
        title: title,
        category: category,
        recurrence: recurrence,
        streakCount: streakCount,
        streakFreezesAvailable: streakFreezesAvailable,
        done: done ?? this.done,
        dueTime: dueTime,
      );
}
