import 'package:flutter_test/flutter_test.dart';
import 'package:thali/features/history/data/models/meal_model.dart';

void main() {
  group('MealAnalysis model', () {
    MealAnalysis sample({String id = 'm1'}) => MealAnalysis(
          id: id,
          items: [
            FoodItem(
              name: 'Roti',
              calories: 120,
              protein: 3.5,
              carbs: 20,
              fat: 3.5,
              fiber: 1.2,
              portion: '1 piece',
              cookingStyle: 'Home',
            ),
          ],
          totalCalories: 120,
          totalProtein: 3.5,
          totalCarbs: 20,
          totalFat: 3.5,
          totalFiber: 1.2,
          mealType: 'lunch',
          healthScore: 7,
          healthTip: 'Looks good.',
        );

    test('round-trips through JSON without rotiCount', () {
      final meal = sample();
      final json = meal.toJson();
      expect(json.containsKey('rotiCount'), isFalse,
          reason: 'rotiCount should no longer be written on save.');

      final decoded = MealAnalysis.fromJson(json);
      expect(decoded.id, meal.id);
      expect(decoded.totalCalories, meal.totalCalories);
      expect(decoded.items.length, 1);
      expect(decoded.items.first.name, 'Roti');
    });

    test('backward-compat: legacy JSON with rotiCount still decodes', () {
      // Simulate a meal saved by an older version of the app.
      final legacyJson = <String, dynamic>{
        'id': 'legacy-1',
        'items': [
          {
            'name': 'Roti',
            'calories': 120,
            'protein': 3.5,
            'carbs': 20.0,
            'fat': 3.5,
            'fiber': 1.2,
            'portion': '2 pieces',
            'cooking_style': 'Home',
          }
        ],
        'totalCalories': 120.0,
        'totalProtein': 3.5,
        'totalCarbs': 20.0,
        'totalFat': 3.5,
        'totalFiber': 1.2,
        'rotiCount': 2, // legacy field — should be silently ignored
        'imagePath': '/tmp/fake.jpg',
        'timestamp': DateTime.now().toIso8601String(),
        'mealType': 'lunch',
        'healthScore': 7,
      };

      final meal = MealAnalysis.fromJson(legacyJson);
      expect(meal.id, 'legacy-1');
      expect(meal.totalCalories, 120.0);
      expect(meal.items.first.name, 'Roti');
    });
  });
}
