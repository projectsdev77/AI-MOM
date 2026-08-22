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
      'updated_at': DateTime.now().toIso8601String(),
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
}
