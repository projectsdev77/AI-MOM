import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<void> saveOnboardingAnswers({
    required String userId,
    required String momAvatarStyle,
    required List<String> goals,
    required List<String> procrastinationAreas,
    required String checkInFrequency,
    String? dailyRoutine,
    String? livingSituation,
    String? motivationStyle,
    String? currentStressor,
  }) {
    return _client.from('profiles').update({
      'mom_avatar_style': momAvatarStyle,
      'goals': goals,
      'procrastination_areas': procrastinationAreas,
      'check_in_frequency': checkInFrequency,
      if (dailyRoutine != null) 'daily_routine': dailyRoutine,
      if (livingSituation != null) 'living_situation': livingSituation,
      if (motivationStyle != null) 'motivation_style': motivationStyle,
      if (currentStressor != null && currentStressor.trim().isNotEmpty)
        'current_stressor': currentStressor.trim(),
    }).eq('id', userId);
  }

  Future<Map<String, dynamic>> fetch(String userId) {
    return _client.from('profiles').select().eq('id', userId).single();
  }

  Future<void> updateCheckInFrequency({required String userId, required String frequency}) {
    return _client.from('profiles').update({'check_in_frequency': frequency}).eq('id', userId);
  }
}
