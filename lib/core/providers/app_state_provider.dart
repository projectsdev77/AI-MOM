import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task_item.dart';
import '../services/notification_service.dart';
import '../theme/mom_mood.dart';
import '../widgets/mom_avatar.dart';
import 'service_providers.dart';

/// [momAvatarStyleProvider] is genuinely local state during onboarding,
/// then seeded from the saved profile after sign-in — see
/// [effectiveMomAvatarProvider]. [planProvider] now lives in
/// service_providers.dart, driven by RevenueCat entitlements.

final momAvatarStyleProvider =
    StateProvider<MomAvatarStyle>((ref) => MomAvatarStyle.terracotta);

/// The avatar to actually render: the saved profile once one exists,
/// otherwise whatever's currently selected in onboarding.
final effectiveMomAvatarProvider = Provider<MomAvatarStyle>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  final savedStyle = profile?['mom_avatar_style'] as String?;
  if (savedStyle != null) return MomAvatarStyle.values.byName(savedStyle);
  return ref.watch(momAvatarStyleProvider);
});

class TasksNotifier extends Notifier<List<TaskItem>> {
  @override
  List<TaskItem> build() {
    Future.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;
    state = await ref.read(tasksRepositoryProvider).fetchTasks(userId);
    // Re-registers each task's reminder every refresh — cheap (just
    // replaces a pending OS alarm) and keeps reminders correct after
    // a reinstall or a fresh login on a new device, where nothing
    // would otherwise be scheduled on-device yet.
    for (final task in state) {
      if (task.dueTime != null) {
        await NotificationService.scheduleTaskReminder(
          taskId: task.id,
          title: task.title,
          dueTime: task.dueTime!,
        );
      }
    }
  }

  /// Returns the task's fresh state (with the server-computed
  /// `streak_count`) once the write lands, or `null` if it failed — the
  /// caller uses this to notice a streak that just went up and show a
  /// celebration. Reverts the optimistic flip on failure.
  Future<TaskItem?> toggleDone(String id) async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return null;
    final task = state.firstWhere((t) => t.id == id);
    final newDone = !task.done;

    // Flip immediately for a responsive UI; reconcile with the server
    // (which owns streak_count via a trigger) once the write lands.
    state = [
      for (final t in state)
        if (t.id == id) t.copyWith(done: newDone) else t,
    ];

    try {
      await ref.read(tasksRepositoryProvider).setDone(taskId: id, userId: userId, done: newDone);
      await refresh();
      for (final t in state) {
        if (t.id == id) return t;
      }
      return null;
    } catch (e, st) {
      debugPrint('toggleDone failed: $e\n$st');
      state = [
        for (final t in state)
          if (t.id == id) t.copyWith(done: !newDone) else t,
      ];
      return null;
    }
  }

  Future<void> archiveTask(String id) async {
    final previous = state;
    state = [for (final t in state) if (t.id != id) t];
    try {
      await ref.read(tasksRepositoryProvider).archiveTask(id);
      await NotificationService.cancelTaskReminder(id);
    } catch (e, st) {
      debugPrint('archiveTask failed: $e\n$st');
      state = previous;
      rethrow;
    }
  }

  /// [category] is the raw value to store — either a known
  /// [TaskCategory]'s `.name` or a free-typed custom category.
  /// Returns the new task's id (e.g. to schedule a reminder against),
  /// or null if there's no signed-in user.
  Future<String?> addTask({
    required String title,
    required String category,
    RecurrenceType recurrence = RecurrenceType.none,
    String? dueTime,
    DateTime? createdAt,
  }) async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return null;
    final id = await ref.read(tasksRepositoryProvider).addTask(
          userId: userId,
          title: title,
          category: category,
          recurrence: recurrence,
          dueTime: dueTime,
          createdAt: createdAt,
        );
    await refresh();
    return id;
  }
}

final tasksProvider = NotifierProvider<TasksNotifier, List<TaskItem>>(
  TasksNotifier.new,
);

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The day currently selected on the Tasks page's calendar — defaults
/// to today.
final selectedTaskDayProvider = StateProvider<DateTime>((ref) => _dateOnly(DateTime.now()));

/// Every active task that belongs on [selectedTaskDayProvider] (see
/// [TaskItem.appliesToDay]), with `done` reflecting completion on that
/// specific day rather than [tasksProvider]'s always-today value.
final tasksForSelectedDayProvider = FutureProvider.autoDispose<List<TaskItem>>((ref) async {
  final day = ref.watch(selectedTaskDayProvider);
  final matching = ref.watch(tasksProvider).where((t) => t.appliesToDay(day)).toList();

  if (_dateOnly(DateTime.now()) == day) return matching;

  final userId = ref.read(authServiceProvider).currentUser?.id;
  if (userId == null) return matching;
  final doneIds = await ref.read(tasksRepositoryProvider).fetchCompletionsForDate(
        userId: userId,
        date: day,
        taskIds: [for (final t in matching) t.id],
      );
  return [for (final t in matching) t.copyWith(done: doneIds.contains(t.id))];
});

/// Today's completion score -> mood, per the planning doc's mood rule.
/// Filtered to tasks that actually apply to today — a task due on
/// another day shouldn't count against (or for) today's mood.
final momMoodProvider = Provider<MomMood>((ref) {
  final todayTasks = ref.watch(tasksProvider).where((t) => t.appliesToDay(DateTime.now())).toList();
  if (todayTasks.isEmpty) return MomMood.neutral;
  final doneRatio = todayTasks.where((t) => t.done).length / todayTasks.length;
  final score = doneRatio * 100;
  if (score >= 80) return MomMood.proud;
  if (score >= 55) return MomMood.neutral;
  if (score >= 30) return MomMood.disappointed;
  return MomMood.veryDisappointed;
});

final momMessageProvider = Provider<String>((ref) {
  final mood = ref.watch(momMoodProvider);
  return switch (mood) {
    MomMood.proud =>
      "Look at you go. I might actually brag about you to your aunt.",
    MomMood.neutral =>
      "Not bad so far today. Keep going and I'll stop hovering over that to-do list.",
    MomMood.disappointed =>
      "A few things are slipping. I'm not mad — just a little disappointed.",
    MomMood.veryDisappointed =>
      "We need to talk. Open your task list before I start calling twice a day.",
  };
});
