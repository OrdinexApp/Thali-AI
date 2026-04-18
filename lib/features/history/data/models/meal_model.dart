class NutrientInfo {
  final String name;
  final double amount;
  final String unit;

  NutrientInfo({
    required this.name,
    required this.amount,
    this.unit = 'g',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'unit': unit,
      };

  factory NutrientInfo.fromJson(Map<String, dynamic> json) => NutrientInfo(
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        unit: json['unit'] as String? ?? 'g',
      );
}

class FoodItem {
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final String? portion;
  final String? cookingStyle;

  FoodItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    this.portion,
    this.cookingStyle,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'portion': portion,
        'cooking_style': cookingStyle,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        name: json['name'] as String? ?? 'Unknown',
        calories: (json['calories'] as num?)?.toDouble() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
        fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
        portion: json['portion'] as String?,
        cookingStyle: json['cooking_style'] as String?,
      );

  /// Row layout for the `public.meal_items` table.
  Map<String, dynamic> toItemRow({
    required String mealId,
    required int sortOrder,
  }) =>
      {
        'meal_id': mealId,
        'sort_order': sortOrder,
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'portion': portion,
        'cooking_style': cookingStyle,
      };

  factory FoodItem.fromRow(Map<String, dynamic> row) => FoodItem(
        name: row['name'] as String? ?? 'Unknown',
        calories: (row['calories'] as num?)?.toDouble() ?? 0,
        protein: (row['protein'] as num?)?.toDouble() ?? 0,
        carbs: (row['carbs'] as num?)?.toDouble() ?? 0,
        fat: (row['fat'] as num?)?.toDouble() ?? 0,
        fiber: (row['fiber'] as num?)?.toDouble() ?? 0,
        portion: row['portion'] as String?,
        cookingStyle: row['cooking_style'] as String?,
      );
}

class MealAnalysis {
  final String id;
  final List<FoodItem> items;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalFiber;
  final String? imagePath;
  final DateTime timestamp;
  final String? mealType;
  final int healthScore;
  final String? healthTip;

  MealAnalysis({
    required this.id,
    required this.items,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalFiber,
    this.imagePath,
    DateTime? timestamp,
    this.mealType,
    this.healthScore = 0,
    this.healthTip,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'items': items.map((e) => e.toJson()).toList(),
        'totalCalories': totalCalories,
        'totalProtein': totalProtein,
        'totalCarbs': totalCarbs,
        'totalFat': totalFat,
        'totalFiber': totalFiber,
        'imagePath': imagePath,
        'timestamp': timestamp.toIso8601String(),
        'mealType': mealType,
        'healthScore': healthScore,
        'healthTip': healthTip,
      };

  /// Backward-compatible: older persisted meals may have a `rotiCount` field,
  /// which is silently ignored on load.
  factory MealAnalysis.fromJson(Map<String, dynamic> json) => MealAnalysis(
        id: json['id'] as String,
        items: (json['items'] as List)
            .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalCalories: (json['totalCalories'] as num).toDouble(),
        totalProtein: (json['totalProtein'] as num).toDouble(),
        totalCarbs: (json['totalCarbs'] as num).toDouble(),
        totalFat: (json['totalFat'] as num).toDouble(),
        totalFiber: (json['totalFiber'] as num).toDouble(),
        imagePath: json['imagePath'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        mealType: json['mealType'] as String?,
        healthScore: (json['healthScore'] as num?)?.toInt() ?? 0,
        healthTip: json['healthTip'] as String?,
      );

  /// Row layout for the `public.meals` table. Items are inserted separately
  /// into `public.meal_items` via [FoodItem.toItemRow].
  Map<String, dynamic> toMealRow({
    required String userId,
    String? imageStoragePath,
  }) =>
      {
        'id': id,
        'user_id': userId,
        'logged_at': timestamp.toUtc().toIso8601String(),
        'meal_type': mealType,
        'total_calories': totalCalories,
        'total_protein': totalProtein,
        'total_carbs': totalCarbs,
        'total_fat': totalFat,
        'total_fiber': totalFiber,
        'health_score': healthScore == 0 ? null : healthScore,
        'health_tip': healthTip,
        'image_storage_path': imageStoragePath,
      };

  /// Reassemble a [MealAnalysis] from a `meals` row plus the rows from
  /// `meal_items` (already filtered to this meal). [imagePath] should be a
  /// pre-resolved signed URL or null.
  factory MealAnalysis.fromRow({
    required Map<String, dynamic> meal,
    required List<Map<String, dynamic>> items,
    String? imagePath,
  }) {
    final sorted = [...items]
      ..sort((a, b) {
        final ao = (a['sort_order'] as num?)?.toInt() ?? 0;
        final bo = (b['sort_order'] as num?)?.toInt() ?? 0;
        return ao.compareTo(bo);
      });

    return MealAnalysis(
      id: meal['id'] as String,
      items: sorted.map(FoodItem.fromRow).toList(),
      totalCalories: (meal['total_calories'] as num?)?.toDouble() ?? 0,
      totalProtein: (meal['total_protein'] as num?)?.toDouble() ?? 0,
      totalCarbs: (meal['total_carbs'] as num?)?.toDouble() ?? 0,
      totalFat: (meal['total_fat'] as num?)?.toDouble() ?? 0,
      totalFiber: (meal['total_fiber'] as num?)?.toDouble() ?? 0,
      imagePath: imagePath,
      timestamp: DateTime.parse(meal['logged_at'] as String).toLocal(),
      mealType: meal['meal_type'] as String?,
      healthScore: (meal['health_score'] as num?)?.toInt() ?? 0,
      healthTip: meal['health_tip'] as String?,
    );
  }
}
