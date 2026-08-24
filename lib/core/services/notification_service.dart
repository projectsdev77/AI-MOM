import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Local, on-device reminders for a task/habit's daily `due_time` —
/// entirely separate from Mom's proactive server-sent nudges (see
/// [PushService]), since these don't need a network round trip: the
/// device already knows the time, so it can fire the alert itself even
/// offline.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (kIsWeb || _ready) return;

    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Falls back to whatever timezone package defaults to (UTC) —
      // reminders still fire, just possibly not at the exact local
      // time until this resolves on a supported platform.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (!kIsWeb && Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    } else if (!kIsWeb && Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _ready = true;
  }

  /// Task ids are UUIDs, not ints — local notifications need a stable
  /// int id, so this hashes it down to one deterministically (same
  /// task always maps to the same notification id, so re-scheduling
  /// naturally replaces the old one instead of stacking duplicates).
  static int _notificationId(String taskId) => taskId.hashCode & 0x7fffffff;

  /// [dueTime] is `HH:mm` or `HH:mm:ss` (as stored in Postgres's `time`
  /// column). Schedules a daily-repeating reminder at that time —
  /// "daily" here means the time of day, not the task's recurrence;
  /// a one-off task with a due time still gets reminded once, that
  /// first occurrence, then the app cancels it after completion.
  static Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required String dueTime,
  }) async {
    if (kIsWeb || !_ready) return;
    final parts = dueTime.split(':');
    if (parts.length < 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      _notificationId(taskId),
      'Mom',
      "Don't forget: $title",
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task reminders',
          channelDescription: "Reminders for tasks you've given a time to",
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelTaskReminder(String taskId) async {
    if (kIsWeb || !_ready) return;
    await _plugin.cancel(_notificationId(taskId));
  }

  /// Fires immediately — used to surface a push notification's content
  /// as a visible system notification when it arrives while the app is
  /// in the foreground, since FCM's own foreground messages don't show
  /// one automatically.
  static Future<void> showNow({required String title, required String body}) async {
    if (kIsWeb || !_ready) return;
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mom_nudges',
          "Mom's check-ins",
          channelDescription: 'Mom checking in when you have incomplete tasks or habits',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
