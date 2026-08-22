import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task_item.dart';
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
  }

  Future<void> toggleDone(String id) async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;
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
    } catch (_) {
      state = [
        for (final t in state)
          if (t.id == id) t.copyWith(done: !newDone) else t,
      ];
    }
  }

  Future<void> addTask({
    required String title,
    required TaskCategory category,
    RecurrenceType recurrence = RecurrenceType.none,
  }) async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;
    await ref.read(tasksRepositoryProvider).addTask(
          userId: userId,
          title: title,
          category: category,
          recurrence: recurrence,
        );
    await refresh();
  }
}

final tasksProvider = NotifierProvider<TasksNotifier, List<TaskItem>>(
  TasksNotifier.new,
);

/// Rolling completion score -> mood, per the planning doc's mood rule.
final momMoodProvider = Provider<MomMood>((ref) {
  final tasks = ref.watch(tasksProvider);
  if (tasks.isEmpty) return MomMood.neutral;
  final doneRatio = tasks.where((t) => t.done).length / tasks.length;
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
      'Look at you go. I might actually brag about you at dinner tonight.',
    MomMood.neutral =>
      'Not bad so far today. Keep it up and I will stop side-eyeing your to-do list.',
    MomMood.disappointed =>
      'A few things are slipping. I am not mad, just a little disappointed.',
    MomMood.veryDisappointed =>
      'We need to talk. Open your task list before I start calling twice a day.',
  };
});
