import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_service.dart';
import 'models/profile_model.dart';

class ProfileRepository {
  ProfileRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  /// Returns the current user's profile, or null if not signed in.
  /// The DB trigger creates a default row on sign-up, so this should always
  /// return a row for an authenticated user.
  Future<Profile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) return null;
    return Profile.fromRow(row);
  }

  Future<Profile> updateGoals({
    int? dailyCalorieGoal,
    int? proteinGoalG,
    int? carbsGoalG,
    int? fatGoalG,
    int? fiberGoalG,
    String? displayName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Cannot update profile without an authenticated user.');
    }

    final updates = <String, dynamic>{};
    if (dailyCalorieGoal != null) {
      updates['daily_calorie_goal'] = dailyCalorieGoal;
    }
    if (proteinGoalG != null) updates['protein_goal_g'] = proteinGoalG;
    if (carbsGoalG != null) updates['carbs_goal_g'] = carbsGoalG;
    if (fatGoalG != null) updates['fat_goal_g'] = fatGoalG;
    if (fiberGoalG != null) updates['fiber_goal_g'] = fiberGoalG;
    if (displayName != null) updates['display_name'] = displayName;

    final row = await _client
        .from('profiles')
        .update(updates)
        .eq('id', user.id)
        .select()
        .single();

    return Profile.fromRow(row);
  }
}
