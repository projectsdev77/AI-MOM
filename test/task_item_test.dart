import 'package:flutter_test/flutter_test.dart';

import 'package:ai_mom/core/models/task_item.dart';

TaskItem _task({
  required DateTime createdAt,
  required RecurrenceType recurrence,
  List<int>? recurrenceDays,
  String id = 'id',
  String? dueTime,
}) {
  return TaskItem(
    id: id,
    dueTime: dueTime,
    title: 'title',
    category: TaskCategory.personal,
    categoryLabel: 'Personal',
    createdAt: createdAt,
    recurrence: recurrence,
    recurrenceDays: recurrenceDays,
  );
}

void main() {
  // A Monday, so weekday-dependent cases below have a known anchor.
  final monday = DateTime(2026, 8, 24);
  final tuesday = DateTime(2026, 8, 25);
  final nextMonday = DateTime(2026, 8, 31);

  group('TaskItem.appliesToDay', () {
    test('daily task applies to every day, past and future', () {
      final task = _task(createdAt: monday, recurrence: RecurrenceType.daily);
      expect(task.appliesToDay(monday), isTrue);
      expect(task.appliesToDay(tuesday), isTrue);
      expect(task.appliesToDay(nextMonday), isTrue);
      expect(task.appliesToDay(DateTime(2020, 1, 1)), isTrue);
    });

    test('weekly task only applies to the weekday it was created on', () {
      final task = _task(createdAt: monday, recurrence: RecurrenceType.weekly);
      expect(task.appliesToDay(monday), isTrue);
      expect(task.appliesToDay(nextMonday), isTrue, reason: 'same weekday, later week');
      expect(task.appliesToDay(tuesday), isFalse);
    });

    test('custom task applies only to its chosen weekdays', () {
      final task = _task(
        createdAt: monday,
        recurrence: RecurrenceType.custom,
        recurrenceDays: [DateTime.monday, DateTime.wednesday],
      );
      expect(task.appliesToDay(monday), isTrue);
      expect(task.appliesToDay(DateTime(2026, 8, 26)), isTrue, reason: 'the Wednesday');
      expect(task.appliesToDay(tuesday), isFalse);
    });

    test('custom task with no days set applies to nothing', () {
      final task = _task(createdAt: monday, recurrence: RecurrenceType.custom);
      expect(task.appliesToDay(monday), isFalse);
    });

    test('one-off task only applies to the exact day it was made', () {
      final task = _task(createdAt: monday, recurrence: RecurrenceType.none);
      expect(task.appliesToDay(monday), isTrue);
      expect(task.appliesToDay(tuesday), isFalse);
      expect(task.appliesToDay(nextMonday), isFalse);
    });

    test('one-off task ignores time-of-day when comparing the date', () {
      final createdLateAtNight = DateTime(2026, 8, 24, 23, 45);
      final task = _task(createdAt: createdLateAtNight, recurrence: RecurrenceType.none);
      expect(task.appliesToDay(DateTime(2026, 8, 24, 6)), isTrue);
    });
  });

  group('compareTasksForDisplay', () {
    TaskItem t(String id, DateTime created, {String? time}) =>
        _task(id: id, createdAt: created, recurrence: RecurrenceType.none, dueTime: time);
    List<String> order(List<TaskItem> tasks) => ([...tasks]..sort(compareTasksForDisplay)).map((x) => x.id).toList();

    final first = DateTime(2026, 8, 24, 9, 0);
    final second = DateTime(2026, 8, 24, 9, 1);
    final third = DateTime(2026, 8, 24, 9, 2);

    test('a reminder 5 minutes away goes above one 20 minutes away, even if made later', () {
      // 20-minute task made first, 5-minute task made second.
      expect(order([t('in20', first, time: '09:20:00'), t('in5', second, time: '09:05:00')]), ['in5', 'in20']);
    });

    test('tasks without a time come after every task that has one', () {
      expect(
        order([t('none', first), t('late', second, time: '23:30:00'), t('early', third, time: '06:00:00')]),
        ['early', 'late', 'none'],
      );
    });

    test('tasks without a time stay in the order they were made', () {
      expect(order([t('c', third), t('a', first), t('b', second)]), ['a', 'b', 'c']);
    });

    test('tasks at the same time stay in the order they were made', () {
      expect(
        order([t('b', second, time: '08:00:00'), t('a', first, time: '08:00:00')]),
        ['a', 'b'],
      );
    });

    test('compares real times, not text: 9:05 is before 10:00', () {
      expect(order([t('ten', first, time: '10:00:00'), t('nine', second, time: '9:05')]), ['nine', 'ten']);
    });

    test('accepts both HH:mm and HH:mm:ss', () {
      expect(order([t('b', first, time: '14:30:00'), t('a', second, time: '14:29')]), ['a', 'b']);
    });

    test('a time that cannot be read is treated as no time, not a crash', () {
      expect(order([t('bad', first, time: 'soon'), t('good', second, time: '07:00:00')]), ['good', 'bad']);
    });

    test('a full mixed list ends up in the expected order', () {
      expect(
        order([
          t('none1', DateTime(2026, 8, 24, 9, 0)),
          t('five1', DateTime(2026, 8, 24, 9, 1), time: '17:00:00'),
          t('morning', DateTime(2026, 8, 24, 9, 2), time: '08:30:00'),
          t('five2', DateTime(2026, 8, 24, 9, 3), time: '17:00:00'),
          t('none2', DateTime(2026, 8, 24, 9, 4)),
        ]),
        ['morning', 'five1', 'five2', 'none1', 'none2'],
      );
    });
  });
}
