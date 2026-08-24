import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task_item.dart';

/// One-off tasks and recurring habits share the `tasks` table (see the
/// planning note: they're the same entity). "Done today" isn't a column
/// on `tasks` — it's derived from whether a `task_completions` row
/// exists for today, which is also what the streak trigger keys off.
class TasksRepository {
  TasksRepository(this._client);

  final SupabaseClient _client;

  String _today() => _dateOnly(DateTime.now());

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// The DB column is free text (a built-in category's `.name`, or
  /// whatever custom text someone typed) — [TaskCategory.values.byName]
  /// would throw on a custom value, so match it manually instead.
  TaskCategory _parseCategoryKind(String raw) {
    for (final c in TaskCategory.values) {
      if (c.name == raw) return c;
    }
    return TaskCategory.other;
  }

  String _categoryLabel(String raw) {
    for (final c in TaskCategory.values) {
      if (c.name == raw) return c.label;
    }
    return raw;
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
          category: _parseCategoryKind(row['category'] as String),
          categoryLabel: _categoryLabel(row['category'] as String),
          recurrence: RecurrenceType.values.byName(row['recurrence'] as String),
          streakCount: row['streak_count'] as int,
          streakFreezesAvailable: row['streak_freezes_available'] as int,
          done: doneIds.contains(row['id']),
          dueTime: row['due_time'] as String?,
        ),
    ];
  }

  /// [category] is the raw value to store — either a built-in
  /// [TaskCategory]'s `.name`, or free-typed custom text.
  Future<void> addTask({
    required String userId,
    required String title,
    required String category,
    RecurrenceType recurrence = RecurrenceType.none,
    String? dueTime,
  }) {
    return _client.from('tasks').insert({
      'user_id': userId,
      'title': title,
      'category': category,
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

  /// Which dates in [month] have at least one completed task, and what
  /// those tasks were titled — for the dashboard calendar's day dots
  /// and per-day summary. Keyed by `yyyy-MM-dd`.
  Future<Map<String, List<String>>> fetchCompletionsForMonth(String userId, DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final rows = await _client
        .from('task_completions')
        .select('completed_date, tasks(title)')
        .eq('user_id', userId)
        .gte('completed_date', _dateOnly(start))
        .lt('completed_date', _dateOnly(end));

    final byDate = <String, List<String>>{};
    for (final row in rows) {
      final date = row['completed_date'] as String;
      final title = (row['tasks'] as Map?)?['title'] as String? ?? 'Task';
      (byDate[date] ??= []).add(title);
    }
    return byDate;
  }

  Future<void> archiveTask(String taskId) {
    return _client.from('tasks').update({'archived_at': DateTime.now().toIso8601String()}).eq('id', taskId);
  }
}
