class Profile {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final int dailyCalorieGoal;
  final int? proteinGoalG;
  final int? carbsGoalG;
  final int? fatGoalG;
  final int? fiberGoalG;
  final List<String> dietaryRestrictions;
  final String timezone;

  const Profile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.dailyCalorieGoal = 2000,
    this.proteinGoalG,
    this.carbsGoalG,
    this.fatGoalG,
    this.fiberGoalG,
    this.dietaryRestrictions = const [],
    this.timezone = 'Asia/Kolkata',
  });

  Profile copyWith({
    String? displayName,
    String? avatarUrl,
    int? dailyCalorieGoal,
    int? proteinGoalG,
    int? carbsGoalG,
    int? fatGoalG,
    int? fiberGoalG,
    List<String>? dietaryRestrictions,
    String? timezone,
  }) {
    return Profile(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      proteinGoalG: proteinGoalG ?? this.proteinGoalG,
      carbsGoalG: carbsGoalG ?? this.carbsGoalG,
      fatGoalG: fatGoalG ?? this.fatGoalG,
      fiberGoalG: fiberGoalG ?? this.fiberGoalG,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      timezone: timezone ?? this.timezone,
    );
  }

  factory Profile.fromRow(Map<String, dynamic> row) {
    return Profile(
      id: row['id'] as String,
      displayName: row['display_name'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      dailyCalorieGoal: (row['daily_calorie_goal'] as num?)?.toInt() ?? 2000,
      proteinGoalG: (row['protein_goal_g'] as num?)?.toInt(),
      carbsGoalG: (row['carbs_goal_g'] as num?)?.toInt(),
      fatGoalG: (row['fat_goal_g'] as num?)?.toInt(),
      fiberGoalG: (row['fiber_goal_g'] as num?)?.toInt(),
      dietaryRestrictions: (row['dietary_restrictions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      timezone: row['timezone'] as String? ?? 'Asia/Kolkata',
    );
  }
}
