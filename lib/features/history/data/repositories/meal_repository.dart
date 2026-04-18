import '../models/meal_model.dart';

/// Abstraction over the meal storage backend. Lets tests swap in an
/// in-memory implementation without booting Supabase.
abstract class MealRepository {
  Future<void> saveMeal(MealAnalysis meal);
  Future<List<MealAnalysis>> getAllMeals();
  Future<List<MealAnalysis>> getTodayMeals();
  Future<double> getTodayCalories();
  Future<void> deleteMeal(String id);
}
