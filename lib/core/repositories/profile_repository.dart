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
    String? name,
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
      // The handle_new_user trigger only ever seeds this from
      // raw_user_meta_data, which email signup populates but Google/Apple
      // sign-in doesn't (it's whatever the OAuth provider's own ID token
      // happens to include, if anything) — so what was actually typed into
      // onboarding's name step needs writing here too, for every sign-in
      // method, or it's silently lost for social sign-in.
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      'daily_routine': ?dailyRoutine,
      'living_situation': ?livingSituation,
      'motivation_style': ?motivationStyle,
      if (currentStressor != null && currentStressor.trim().isNotEmpty)
        'current_stressor': currentStressor.trim(),
    }).eq('id', userId);
  }

  /// Unlike [saveOnboardingAnswers] (which only ever adds values, on the
  /// one-time onboarding submit), this is a real edit: an explicit null
  /// here clears that answer back to unset, same as leaving an
  /// onboarding question unanswered in the first place.
  Future<void> updateOnboardingExtras({
    required String userId,
    required List<String> goals,
    required List<String> procrastinationAreas,
    String? dailyRoutine,
    String? livingSituation,
    String? motivationStyle,
    String? currentStressor,
  }) {
    return _client.from('profiles').update({
      'goals': goals,
      'procrastination_areas': procrastinationAreas,
      'daily_routine': dailyRoutine,
      'living_situation': livingSituation,
      'motivation_style': motivationStyle,
      'current_stressor':
          currentStressor != null && currentStressor.trim().isNotEmpty ? currentStressor.trim() : null,
    }).eq('id', userId);
  }

  Future<Map<String, dynamic>> fetch(String userId) {
    return _client.from('profiles').select().eq('id', userId).single();
  }

  Future<void> updateCheckInFrequency({required String userId, required String frequency}) {
    return _client.from('profiles').update({'check_in_frequency': frequency}).eq('id', userId);
  }

  Future<void> updateName({required String userId, required String name}) {
    return _client.from('profiles').update({'name': name}).eq('id', userId);
  }

  Future<void> updateMomAvatarStyle({required String userId, required String style}) {
    return _client.from('profiles').update({'mom_avatar_style': style}).eq('id', userId);
  }

  Future<void> updateFcmToken({required String userId, required String token}) {
    return _client.from('profiles').update({'fcm_token': token}).eq('id', userId);
  }

  Future<void> updatePushNudgesEnabled({required String userId, required bool enabled}) {
    return _client.from('profiles').update({'push_nudges_enabled': enabled}).eq('id', userId);
  }
}
