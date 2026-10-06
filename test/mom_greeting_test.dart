import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_mom/core/models/task_item.dart';
import 'package:ai_mom/core/providers/app_state_provider.dart';
import 'package:ai_mom/core/providers/service_providers.dart';
import 'package:ai_mom/core/theme/mom_mood.dart';
import 'package:ai_mom/core/utils/mom_messages.dart';

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
  bool everAddedTask = false,
  String name = 'Meaza',
}) async {
  final container = ProviderContainer(overrides: [
    tasksProvider.overrideWith(() => _FakeTasks(tasks)),
    tasksLoadedProvider.overrideWith((ref) => loaded),
    hasEverAddedTaskProvider.overrideWith((ref) async => everAddedTask || tasks.isNotEmpty),
    profileProvider.overrideWith((ref) async => {'name': name}),
  ]);
  addTearDown(container.dispose);
  await container.read(profileProvider.future);
  await container.read(hasEverAddedTaskProvider.future);
  return container;
}

void main() {
  test('an account that has never added a task: Mom says welcome, by name', () async {
    final c = await _setup();
    expect(c.read(momGreetingProvider), MomGreeting.welcome);
    expect(c.read(momMessageProvider), startsWith('Welcome, Meaza!'));
    expect(c.read(momMessageProvider), isNot(contains('Not bad')));
  });

  test('the name comes from the profile, whatever it is', () async {
    final c = await _setup(name: 'Priya');
    expect(c.read(momMessageProvider), startsWith('Welcome, Priya!'));
  });

  test('welcome still reads fine when there is no name', () async {
    final c = await _setup(name: '  ');
    expect(c.read(momMessageProvider), startsWith('Welcome! '));
  });

  test('the welcome does not expire with time: it lasts until the first task', () async {
    // Nothing in the greeting looks at how old the account is.
    final c = await _setup();
    expect(c.read(momGreetingProvider), MomGreeting.welcome);
  });

  test('after the first task is added the welcome is gone', () async {
    final c = await _setup(tasks: [_task()]);
    expect(c.read(momGreetingProvider), MomGreeting.normal);
    expect(c.read(momMessageProvider), isNot(startsWith('Welcome')));
  });

  test('added a task and then deleted it: no second welcome, just "you have no tasks"', () async {
    final c = await _setup(everAddedTask: true);
    expect(c.read(momGreetingProvider), MomGreeting.noTasks);
    expect(c.read(momMessageProvider), contains("haven't added any tasks"));
    expect(c.read(momMessageProvider), isNot(contains('Not bad')));
  });

  test('tasks exist but none are for today: says nothing is on the list today', () async {
    final lastWeek = DateTime.now().subtract(const Duration(days: 9));
    final c = await _setup(tasks: [_task(recurrence: RecurrenceType.none, createdAt: lastWeek)]);
    expect(c.read(momGreetingProvider), MomGreeting.nothingToday);
    expect(c.read(momMessageProvider), startsWith('Nothing on your list for today'));
  });

  test('before the list has loaded Mom does not claim it is empty', () async {
    final c = await _setup(loaded: false);
    expect(c.read(momGreetingProvider), MomGreeting.loading);
    expect(c.read(momMessageProvider), isNot(contains("haven't added")));
    expect(c.read(momMessageProvider), isNot(startsWith('Welcome')));
  });

  test('with tasks for today Mom uses her score-based lines for that mood', () async {
    final done = await _setup(tasks: [_task(done: true), _task(recurrence: RecurrenceType.weekly, done: true)]);
    expect(done.read(momGreetingProvider), MomGreeting.normal);
    expect(momMessagesFor(MomMood.proud, done: 2, total: 2), contains(done.read(momMessageProvider)));

    final none = await _setup(tasks: [_task(), _task(recurrence: RecurrenceType.weekly)]);
    expect(momMessagesFor(MomMood.veryDisappointed, done: 0, total: 2), contains(none.read(momMessageProvider)));
  });

  test('empty-list moments use their own heading and face, normal ones keep the mood', () {
    expect(MomGreeting.welcome.eyebrow, 'Welcome');
    expect(MomGreeting.noTasks.eyebrow, 'Getting started');
    expect(MomGreeting.normal.eyebrow, isNull);
    expect(MomGreeting.normal.expression, isNull);
  });
}
