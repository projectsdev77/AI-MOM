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
  }) {
    return _client.from('profiles').update({
      'mom_avatar_style': momAvatarStyle,
      'goals': goals,
      'procrastination_areas': procrastinationAreas,
      'check_in_frequency': checkInFrequency,
    }).eq('id', userId);
  }

  Future<Map<String, dynamic>> fetch(String userId) {
    return _client.from('profiles').select().eq('id', userId).single();
  }
}
