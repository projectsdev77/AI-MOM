import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_mom/core/models/task_item.dart';
import 'package:ai_mom/core/providers/app_state_provider.dart';
import 'package:ai_mom/core/providers/service_providers.dart';
import 'package:ai_mom/core/services/auth_service.dart';
import 'package:ai_mom/core/widgets/app_resume_refresher.dart';

const _user = User(id: 'u1', appMetadata: {}, userMetadata: {}, aud: 'authenticated', createdAt: '2026-01-01T00:00:00Z');

class _FakeAuth implements AuthService {
  _FakeAuth({this.signedIn = true});
  final bool signedIn;
  int timezoneSaves = 0;

  @override
  User? get currentUser => signedIn ? _user : null;

  @override
  Future<void> refreshTimezone() async => timezoneSaves++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CountingTasks extends TasksNotifier {
  _CountingTasks(this.counter);
  final List<int> counter;

  @override
  List<TaskItem> build() => const [];

  @override
  Future<void> refresh() async => counter.add(1);
}

class _Harness {
  int profileFetches = 0;
  final taskRefreshes = <int>[];
  late final _FakeAuth auth;
}

Future<_Harness> _pump(WidgetTester tester, {bool signedIn = true, Duration minGap = const Duration(seconds: 5)}) async {
  final h = _Harness()..auth = _FakeAuth(signedIn: signedIn);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(h.auth),
      profileProvider.overrideWith((ref) async {
        h.profileFetches++;
        return {'plan': 'basic'};
      }),
      tasksProvider.overrideWith(() => _CountingTasks(h.taskRefreshes)),
    ],
    child: MaterialApp(
      home: AppResumeRefresher(
        minGap: minGap,
        // Watching keeps the profile provider alive, like the real screens do.
        child: Consumer(builder: (context, ref, _) {
          ref.watch(profileProvider);
          return const Text('app');
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return h;
}

Future<void> _backgroundThenForeground(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('coming back to the app re-reads the profile (the plan), tasks and timezone', (tester) async {
    final h = await _pump(tester);
    expect(h.profileFetches, 1);

    await _backgroundThenForeground(tester);

    expect(h.profileFetches, 2, reason: 'the profile holds the server plan, so it must be re-read');
    expect(h.taskRefreshes.length, 1);
    expect(h.auth.timezoneSaves, 1);
  });

  testWidgets('going to the background alone refreshes nothing', (tester) async {
    final h = await _pump(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(h.profileFetches, 1);
    expect(h.taskRefreshes, isEmpty);
  });

  testWidgets('signed out: nothing is fetched on resume', (tester) async {
    final h = await _pump(tester, signedIn: false);
    final before = h.profileFetches;
    await _backgroundThenForeground(tester);
    expect(h.profileFetches, before);
    expect(h.taskRefreshes, isEmpty);
    expect(h.auth.timezoneSaves, 0);
  });

  testWidgets('very quick app switches do not refresh again and again', (tester) async {
    final h = await _pump(tester);
    await _backgroundThenForeground(tester);
    await _backgroundThenForeground(tester);
    await _backgroundThenForeground(tester);
    expect(h.taskRefreshes.length, 1, reason: 'three resumes inside the 5 second gap count once');
  });

  testWidgets('with no gap every return refreshes', (tester) async {
    final h = await _pump(tester, minGap: Duration.zero);
    await _backgroundThenForeground(tester);
    await _backgroundThenForeground(tester);
    expect(h.taskRefreshes.length, 2);
  });

  testWidgets('the refresh still works when the store is unreachable', (tester) async {
    // RevenueCat is not mocked here, so asking it throws; the rest must still run.
    final h = await _pump(tester);
    await _backgroundThenForeground(tester);
    expect(tester.takeException(), isNull);
    expect(h.taskRefreshes.length, 1);
    expect(h.auth.timezoneSaves, 1);
  });
}
