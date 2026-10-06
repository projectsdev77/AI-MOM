import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task_item.dart';
import '../services/notification_service.dart';
import '../theme/mom_mood.dart';
import '../utils/mom_messages.dart';
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

/// False until the task list has come back from the server at least once, so
/// "you have no tasks" is never shown just because the list hasn't loaded yet.
final tasksLoadedProvider = StateProvider<bool>((ref) => false);

class TasksNotifier extends Notifier<List<TaskItem>> {
  @override
  List<TaskItem> build() {
    Future.microtask(() {
      ref.read(tasksLoadedProvider.notifier).state = false;
      return refresh();
    });
    return const [];
  }

  Future<void> refresh() async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;
    state = await ref.read(tasksRepositoryProvider).fetchTasks(userId);
    ref.read(tasksLoadedProvider.notifier).state = true;
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

  /// [dueTime] null means "no reminder" — explicitly cancels any
  /// previously-scheduled one, since [refresh] only re-schedules tasks
  /// that currently have a dueTime and wouldn't otherwise notice one
  /// was just cleared.
  Future<void> updateTask({
    required String taskId,
    required String title,
    required String category,
    required RecurrenceType recurrence,
    String? dueTime,
  }) async {
    await ref.read(tasksRepositoryProvider).updateTask(
          taskId: taskId,
          title: title,
          category: category,
          recurrence: recurrence,
          dueTime: dueTime,
        );
    if (dueTime != null) {
      await NotificationService.scheduleTaskReminder(taskId: taskId, title: title, dueTime: dueTime);
    } else {
      await NotificationService.cancelTaskReminder(taskId);
    }
    await refresh();
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
  // Reminder-time order, earliest first, so what's coming up soonest is on top.
  final matching = ref.watch(tasksProvider).where((t) => t.appliesToDay(day)).toList()
    ..sort(compareTasksForDisplay);

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

/// What Mom has to say right now, before the score comes into it: an account
/// that has never had a task, an empty list, or a day with nothing on it each get their own line
/// instead of the score-based one (an empty list scores 0 and would otherwise
/// read as "not bad so far").
enum MomGreeting { loading, welcome, noTasks, nothingToday, normal }

extension MomGreetingX on MomGreeting {
  /// Heading over the message. `null` means keep the usual mood label.
  String? get eyebrow => switch (this) {
        MomGreeting.welcome => 'Welcome',
        MomGreeting.noTasks => 'Getting started',
        MomGreeting.nothingToday => 'Clear day',
        MomGreeting.loading || MomGreeting.normal => null,
      };

  /// Mom's face for these moments. `null` means keep the mood's own.
  MomExpression? get expression => switch (this) {
        MomGreeting.welcome => MomExpression.happy,
        MomGreeting.noTasks || MomGreeting.nothingToday || MomGreeting.loading => MomExpression.normal,
        MomGreeting.normal => null,
      };
}

/// Whether this account has ever added a task (deleted ones count). Mom says
/// welcome only until this turns true. Re-checked whenever the list changes.
final hasEverAddedTaskProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (ref.watch(tasksProvider).isNotEmpty) return true;
  final userId = ref.read(authServiceProvider).currentUser?.id;
  if (userId == null) return false;
  return ref.read(tasksRepositoryProvider).hasEverAddedTask(userId);
});

final momGreetingProvider = Provider<MomGreeting>((ref) {
  final tasks = ref.watch(tasksProvider);
  final loaded = ref.watch(tasksLoadedProvider);
  final profileAsync = ref.watch(profileProvider);
  if (!loaded || (profileAsync.isLoading && !profileAsync.hasValue)) return MomGreeting.loading;

  if (tasks.isEmpty) {
    final everAdded = ref.watch(hasEverAddedTaskProvider);
    if (everAdded.isLoading && !everAdded.hasValue) return MomGreeting.loading;
    return everAdded.valueOrNull == true ? MomGreeting.noTasks : MomGreeting.welcome;
  }
  if (!tasks.any((t) => t.appliesToDay(DateTime.now()))) return MomGreeting.nothingToday;
  return MomGreeting.normal;
});

final momMessageProvider = Provider<String>((ref) {
  switch (ref.watch(momGreetingProvider)) {
    case MomGreeting.loading:
      return 'Let me take a look at your list…';
    case MomGreeting.welcome:
      final name = (ref.watch(profileProvider).valueOrNull?['name'] as String?)?.trim() ?? '';
      return name.isEmpty
          ? "Welcome! I'm so glad you're here. Add your first task and let's get you started."
          : "Welcome, $name! I'm so glad you're here. Add your first task and let's get you started.";
    case MomGreeting.noTasks:
      return "You haven't added any tasks yet. Add one and I'll start keeping an eye on you.";
    case MomGreeting.nothingToday:
      return "Nothing on your list for today. Enjoy it — or add something, so I have something to ask about.";
    case MomGreeting.normal:
      break;
  }
  final mood = ref.watch(momMoodProvider);
  final today = DateTime.now();
  final todayTasks = ref.watch(tasksProvider).where((t) => t.appliesToDay(today));
  return momTaskMessage(
    mood: mood,
    done: todayTasks.where((t) => t.done).length,
    total: todayTasks.length,
    day: today,
  );
});
