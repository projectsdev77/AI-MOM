import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_mom/core/models/task_item.dart';
import 'package:ai_mom/core/providers/app_state_provider.dart';
import 'package:ai_mom/core/providers/service_providers.dart';

/// A task list that is simply handed over, with no server behind it.
class _FakeTasks extends TasksNotifier {
  _FakeTasks(this._tasks);
  final List<TaskItem> _tasks;

  @override
  List<TaskItem> build() => _tasks;
}

TaskItem _task({RecurrenceType recurrence = RecurrenceType.daily, DateTime? createdAt, bool done = false}) => TaskItem(
      id: 't${recurrence.name}${createdAt ?? ''}',
      title: 'Task',
      category: TaskCategory.personal,
      categoryLabel: 'Personal',
      createdAt: createdAt ?? DateTime.now(),
      recurrence: recurrence,
      done: done,
    );

Future<ProviderContainer> _setup({
  List<TaskItem> tasks = const [],
  bool loaded = true,
  Duration accountAge = const Duration(days: 30),
  String name = 'Meaza',
}) async {
  final container = ProviderContainer(overrides: [
    tasksProvider.overrideWith(() => _FakeTasks(tasks)),
    tasksLoadedProvider.overrideWith((ref) => loaded),
    profileProvider.overrideWith((ref) async => {
          'name': name,
          'created_at': DateTime.now().subtract(accountAge).toUtc().toIso8601String(),
        }),
  ]);
  addTearDown(container.dispose);
  await container.read(profileProvider.future);
  return container;
}

void main() {
  test('brand-new account with no tasks: Mom says welcome, by name', () async {
    final c = await _setup(accountAge: const Duration(minutes: 5));
    expect(c.read(momGreetingProvider), MomGreeting.welcome);
    expect(c.read(momMessageProvider), startsWith('Welcome, Meaza!'));
    expect(c.read(momMessageProvider), isNot(contains('Not bad')));
  });

  test('welcome still reads fine when there is no name', () async {
    final c = await _setup(accountAge: const Duration(minutes: 5), name: '  ');
    expect(c.read(momMessageProvider), startsWith('Welcome! '));
  });

  test('older account with no tasks: Mom says you have not added any', () async {
    final c = await _setup(accountAge: const Duration(days: 3));
    expect(c.read(momGreetingProvider), MomGreeting.noTasks);
    expect(c.read(momMessageProvider), contains("haven't added any tasks"));
    expect(c.read(momMessageProvider), isNot(contains('Not bad')));
  });

  test('the welcome ends after a day even if the list is still empty', () async {
    final c = await _setup(accountAge: const Duration(hours: 25));
    expect(c.read(momGreetingProvider), MomGreeting.noTasks);
  });

  test('a new account that has added a task gets the normal score message, not the welcome', () async {
    final c = await _setup(accountAge: const Duration(minutes: 5), tasks: [_task()]);
    expect(c.read(momGreetingProvider), MomGreeting.normal);
    expect(c.read(momMessageProvider), isNot(startsWith('Welcome')));
  });

  test('tasks exist but none are for today: says nothing is on the list today', () async {
    final lastWeek = DateTime.now().subtract(const Duration(days: 9));
    final c = await _setup(tasks: [_task(recurrence: RecurrenceType.none, createdAt: lastWeek)]);
    expect(c.read(momGreetingProvider), MomGreeting.nothingToday);
    expect(c.read(momMessageProvider), startsWith('Nothing on your list for today'));
  });

  test('before the list has loaded Mom does not claim it is empty', () async {
    final c = await _setup(loaded: false, accountAge: const Duration(minutes: 5));
    expect(c.read(momGreetingProvider), MomGreeting.loading);
    expect(c.read(momMessageProvider), isNot(contains("haven't added")));
    expect(c.read(momMessageProvider), isNot(startsWith('Welcome')));
  });

  test('with tasks for today the usual score-based lines are unchanged', () async {
    final done = await _setup(tasks: [_task(done: true), _task(recurrence: RecurrenceType.weekly, done: true)]);
    expect(done.read(momGreetingProvider), MomGreeting.normal);
    expect(done.read(momMessageProvider), startsWith('Look at you go'));

    final none = await _setup(tasks: [_task(), _task(recurrence: RecurrenceType.weekly)]);
    expect(none.read(momMessageProvider), startsWith('We need to talk'));
  });

  test('empty-list moments use their own heading and face, normal ones keep the mood', () {
    expect(MomGreeting.welcome.eyebrow, 'Welcome');
    expect(MomGreeting.noTasks.eyebrow, 'Getting started');
    expect(MomGreeting.normal.eyebrow, isNull);
    expect(MomGreeting.normal.expression, isNull);
  });
}
