import 'package:flutter_test/flutter_test.dart';

import 'package:ai_mom/core/models/task_item.dart';

TaskItem _task({
  required DateTime createdAt,
  required RecurrenceType recurrence,
  List<int>? recurrenceDays,
}) {
  return TaskItem(
    id: 'id',
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
}
