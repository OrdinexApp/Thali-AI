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
}

class MealAnalysis {
  final String id;
  final List<FoodItem> items;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalFiber;
  final int rotiCount;
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
    required this.rotiCount,
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
        'rotiCount': rotiCount,
        'imagePath': imagePath,
        'timestamp': timestamp.toIso8601String(),
        'mealType': mealType,
        'healthScore': healthScore,
        'healthTip': healthTip,
      };

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
        rotiCount: json['rotiCount'] as int,
        imagePath: json['imagePath'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        mealType: json['mealType'] as String?,
        healthScore: (json['healthScore'] as num?)?.toInt() ?? 0,
        healthTip: json['healthTip'] as String?,
      );
}
