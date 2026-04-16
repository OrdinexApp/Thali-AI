import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/meal_model.dart';

class MealRepository {
  static const String _boxName = 'meals';

  Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  Future<void> saveMeal(MealAnalysis meal) async {
    final box = await _getBox();
    await box.put(meal.id, jsonEncode(meal.toJson()));
  }

  Future<List<MealAnalysis>> getAllMeals() async {
    final box = await _getBox();
    final meals = <MealAnalysis>[];
    for (var key in box.keys) {
      try {
        final json = jsonDecode(box.get(key) as String) as Map<String, dynamic>;
        meals.add(MealAnalysis.fromJson(json));
      } catch (_) {
        continue;
      }
    }
    meals.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return meals;
  }

  Future<List<MealAnalysis>> getTodayMeals() async {
    final all = await getAllMeals();
    final now = DateTime.now();
    return all.where((m) {
      return m.timestamp.year == now.year &&
          m.timestamp.month == now.month &&
          m.timestamp.day == now.day;
    }).toList();
  }

  Future<double> getTodayCalories() async {
    final todayMeals = await getTodayMeals();
    double total = 0;
    for (final m in todayMeals) {
      total += m.totalCalories;
    }
    return total;
  }

  Future<void> deleteMeal(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }
}
