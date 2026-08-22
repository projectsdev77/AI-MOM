import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task_item.dart';

/// One-off tasks and recurring habits share the `tasks` table (see the
/// planning note: they're the same entity). "Done today" isn't a column
/// on `tasks` — it's derived from whether a `task_completions` row
/// exists for today, which is also what the streak trigger keys off.
class TasksRepository {
  TasksRepository(this._client);

  final SupabaseClient _client;

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<List<TaskItem>> fetchTasks(String userId) async {
    final today = _today();

    final taskRows = await _client
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .isFilter('archived_at', null)
        .order('created_at');

    final completionRows = await _client
        .from('task_completions')
        .select('task_id')
        .eq('user_id', userId)
        .eq('completed_date', today);

    final doneIds = {for (final row in completionRows) row['task_id'] as String};

    return [
      for (final row in taskRows)
        TaskItem(
          id: row['id'] as String,
          title: row['title'] as String,
          category: TaskCategory.values.byName(row['category'] as String),
          recurrence: RecurrenceType.values.byName(row['recurrence'] as String),
          streakCount: row['streak_count'] as int,
          streakFreezesAvailable: row['streak_freezes_available'] as int,
          done: doneIds.contains(row['id']),
          dueTime: row['due_time'] as String?,
        ),
    ];
  }

  Future<void> addTask({
    required String userId,
    required String title,
    required TaskCategory category,
    RecurrenceType recurrence = RecurrenceType.none,
    String? dueTime,
  }) {
    return _client.from('tasks').insert({
      'user_id': userId,
      'title': title,
      'category': category.name,
      'recurrence': recurrence.name,
      if (dueTime != null) 'due_time': dueTime,
    });
  }

  Future<void> setDone({required String taskId, required String userId, required bool done}) {
    if (done) {
      return _client.from('task_completions').insert({
        'task_id': taskId,
        'user_id': userId,
        'completed_date': _today(),
      });
    }
    return _client
        .from('task_completions')
        .delete()
        .eq('task_id', taskId)
        .eq('completed_date', _today());
  }

  Future<void> archiveTask(String taskId) {
    return _client.from('tasks').update({'archived_at': DateTime.now().toIso8601String()}).eq('id', taskId);
  }
}
