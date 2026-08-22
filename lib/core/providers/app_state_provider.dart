import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/plan.dart';
import '../models/task_item.dart';
import '../theme/mom_mood.dart';
import '../widgets/mom_avatar.dart';

/// Demo/mock state for the UI shell — no backend wired up yet. Swap these
/// providers for ones backed by Supabase once the API layer exists.

final userNameProvider = StateProvider<String>((ref) => 'Alex');

final planProvider = StateProvider<AppPlan>((ref) => AppPlan.basic);

final momAvatarStyleProvider =
    StateProvider<MomAvatarStyle>((ref) => MomAvatarStyle.terracotta);

class TasksNotifier extends Notifier<List<TaskItem>> {
  @override
  List<TaskItem> build() => const [
        TaskItem(
          id: 't1',
          title: 'Drink 8 glasses of water',
          category: TaskCategory.health,
          recurrence: RecurrenceType.daily,
          streakCount: 6,
          streakFreezesAvailable: 1,
          dueTime: 'All day',
        ),
        TaskItem(
          id: 't2',
          title: 'Finish quarterly report',
          category: TaskCategory.work,
          dueTime: '5:00 PM',
        ),
        TaskItem(
          id: 't3',
          title: 'Take out the trash',
          category: TaskCategory.chores,
          recurrence: RecurrenceType.weekly,
          streakCount: 2,
          dueTime: '8:00 PM',
        ),
        TaskItem(
          id: 't4',
          title: 'Log today\'s spending',
          category: TaskCategory.money,
          recurrence: RecurrenceType.daily,
          streakCount: 12,
          streakFreezesAvailable: 2,
          dueTime: '9:00 PM',
        ),
        TaskItem(
          id: 't5',
          title: 'Call the dentist',
          category: TaskCategory.personal,
          dueTime: '11:00 AM',
        ),
      ];

  void toggleDone(String id) {
    state = [
      for (final t in state)
        if (t.id == id) t.copyWith(done: !t.done) else t,
    ];
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
