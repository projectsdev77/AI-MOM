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
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          recurrence: RecurrenceType.values.byName(row['recurrence'] as String),
          recurrenceDays: (row['recurrence_days'] as List?)?.cast<int>(),
          streakCount: row['streak_count'] as int,
          streakFreezesAvailable: row['streak_freezes_available'] as int,
          done: doneIds.contains(row['id']),
          dueTime: row['due_time'] as String?,
        ),
    ];
  }

  /// Which of [taskIds] have a completion logged on [date] specifically
  /// — used to show correct done/undone state when browsing a day other
  /// than today via the calendar, since [fetchTasks]'s `done` field is
  /// always "done today."
  Future<Set<String>> fetchCompletionsForDate({
    required String userId,
    required DateTime date,
    required List<String> taskIds,
  }) async {
    if (taskIds.isEmpty) return {};
    final rows = await _client
        .from('task_completions')
        .select('task_id')
        .eq('user_id', userId)
        .eq('completed_date', _dateOnly(date))
        .inFilter('task_id', taskIds);
    return {for (final row in rows) row['task_id'] as String};
  }

  /// [category] is the raw value to store — either a built-in
  /// [TaskCategory]'s `.name`, or free-typed custom text. [createdAt]
  /// lets a task be added as of a calendar day other than right now
  /// (e.g. adding while browsing a different day) — `appliesToDay` for
  /// a one-off task, and the weekday anchor for a weekly one, are both
  /// derived from `created_at`, so leaving it to the DB's `now()`
  /// default would always file the task under today regardless of
  /// which day was selected. Returns the new task's id, so a reminder
  /// notification can be scheduled against it when [dueTime] is set.
  Future<String> addTask({
    required String userId,
    required String title,
    required String category,
    RecurrenceType recurrence = RecurrenceType.none,
    String? dueTime,
    DateTime? createdAt,
  }) async {
    final row = await _client
        .from('tasks')
        .insert({
          'user_id': userId,
          'title': title,
          'category': category,
          'recurrence': recurrence.name,
          if (dueTime != null) 'due_time': dueTime,
          if (createdAt != null) 'created_at': createdAt.toIso8601String(),
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> setDone({
    required String taskId,
    required String userId,
    required bool done,
    DateTime? date,
  }) {
    final dateStr = date != null ? _dateOnly(date) : _today();
    if (done) {
      return _client.from('task_completions').insert({
        'task_id': taskId,
        'user_id': userId,
        'completed_date': dateStr,
      });
    }
    return _client
        .from('task_completions')
        .delete()
        .eq('task_id', taskId)
        .eq('completed_date', dateStr);
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
