import 'package:supabase_flutter/supabase_flutter.dart';

class HealthGoals {
  const HealthGoals({
    required this.waterTarget,
    required this.sleepTargetHours,
    required this.workoutTargetMinutes,
  });

  final int waterTarget;
  final double sleepTargetHours;
  final int workoutTargetMinutes;
}

class HealthToday {
  const HealthToday({required this.waterCount, this.sleepHours, required this.workoutMinutes});
  final int waterCount;
  final double? sleepHours;
  final int workoutMinutes;
}

/// A user-defined "stay active" activity (e.g. "Tennis", goal 60
/// min/day) — same idea as a habit on the Tasks tab, but tracked in
/// minutes-per-day against a target instead of a done/not-done check.
class HealthActivity {
  const HealthActivity({
    required this.id,
    required this.title,
    required this.targetMinutes,
    required this.todayMinutes,
  });

  final String id;
  final String title;
  final int targetMinutes;
  final int todayMinutes;
}

/// Goals aren't asked at onboarding — the plan is to prompt for them the
/// first time the user opens the Health tab (see [fetchGoals] returning
/// null when no row exists yet), and let them change goals later.
class HealthRepository {
  HealthRepository(this._client);

  final SupabaseClient _client;

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<HealthGoals?> fetchGoals(String userId) async {
    final row = await _client.from('health_goals').select().eq('user_id', userId).maybeSingle();
    if (row == null) return null;
    return HealthGoals(
      waterTarget: row['water_target'] as int,
      sleepTargetHours: (row['sleep_target_hours'] as num).toDouble(),
      workoutTargetMinutes: row['workout_target_minutes'] as int,
    );
  }

  Future<void> setGoals({
    required String userId,
    required int waterTarget,
    required double sleepTargetHours,
    required int workoutTargetMinutes,
  }) {
    return _client.from('health_goals').upsert({
      'user_id': userId,
      'water_target': waterTarget,
      'sleep_target_hours': sleepTargetHours,
      'workout_target_minutes': workoutTargetMinutes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<HealthToday> fetchToday(String userId) async {
    final row = await _client
        .from('health_logs')
        .select()
        .eq('user_id', userId)
        .eq('log_date', _today())
        .maybeSingle();
    if (row == null) return const HealthToday(waterCount: 0, workoutMinutes: 0);
    return HealthToday(
      waterCount: row['water_count'] as int,
      sleepHours: (row['sleep_hours'] as num?)?.toDouble(),
      workoutMinutes: row['workout_minutes'] as int,
    );
  }

  Future<void> logToday({
    required String userId,
    int? waterCount,
    double? sleepHours,
    int? workoutMinutes,
  }) {
    return _client.from('health_logs').upsert({
      'user_id': userId,
      'log_date': _today(),
      if (waterCount != null) 'water_count': waterCount,
      if (sleepHours != null) 'sleep_hours': sleepHours,
      if (workoutMinutes != null) 'workout_minutes': workoutMinutes,
    }, onConflict: 'user_id,log_date');
  }

  Future<List<HealthActivity>> fetchActivities(String userId) async {
    final today = _today();
    final activityRows = await _client
        .from('health_activities')
        .select()
        .eq('user_id', userId)
        .isFilter('archived_at', null)
        .order('created_at');
    final logRows = await _client
        .from('health_activity_logs')
        .select('activity_id, minutes')
        .eq('user_id', userId)
        .eq('log_date', today);
    final minutesByActivity = {
      for (final row in logRows) row['activity_id'] as String: row['minutes'] as int,
    };
    return [
      for (final row in activityRows)
        HealthActivity(
          id: row['id'] as String,
          title: row['title'] as String,
          targetMinutes: row['target_minutes'] as int,
          todayMinutes: minutesByActivity[row['id']] ?? 0,
        ),
    ];
  }

  Future<void> addActivity({
    required String userId,
    required String title,
    required int targetMinutes,
  }) {
    return _client.from('health_activities').insert({
      'user_id': userId,
      'title': title,
      'target_minutes': targetMinutes,
    });
  }

  Future<void> archiveActivity(String activityId) {
    return _client
        .from('health_activities')
        .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', activityId);
  }

  Future<void> logActivityMinutes({
    required String activityId,
    required String userId,
    required int minutes,
  }) {
    return _client.from('health_activity_logs').upsert(
      {'activity_id': activityId, 'user_id': userId, 'log_date': _today(), 'minutes': minutes},
      onConflict: 'activity_id,log_date',
    );
  }
}
