import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/image_upload_service.dart';
import '../../../../services/supabase_service.dart';
import '../models/meal_model.dart';
import 'meal_repository.dart';

/// Cloud-backed meal repository. All reads and writes are scoped to the
/// authenticated user via Supabase RLS policies.
class SupabaseMealRepository implements MealRepository {
  SupabaseMealRepository({
    SupabaseClient? client,
    ImageUploadService? imageUploadService,
  })  : _client = client ?? SupabaseService.client,
        _imageUploadService = imageUploadService ?? ImageUploadService();

  final SupabaseClient _client;
  final ImageUploadService _imageUploadService;

  String? get _uid => _client.auth.currentUser?.id;

  /// Persist a meal: optionally upload its photo to Storage, then insert
  /// the meal row and all child food-item rows.
  @override
  Future<void> saveMeal(MealAnalysis meal) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Cannot save a meal without an authenticated user.');
    }

    String? storagePath;
    final localPath = meal.imagePath;
    if (localPath != null && localPath.isNotEmpty && !_isRemotePath(localPath)) {
      try {
        storagePath = await _imageUploadService.uploadMealImage(
          localPath: localPath,
          mealId: meal.id,
        );
      } catch (e, st) {
        // Image upload is best-effort: still save the nutrition row so the
        // user's calorie history stays accurate.
        debugPrint('[SaveMeal] image upload failed (continuing without photo): $e');
        debugPrintStack(stackTrace: st, label: '[SaveMeal][upload]');
        storagePath = null;
      }
    }

    try {
      await _client.from('meals').insert(
            meal.toMealRow(userId: uid, imageStoragePath: storagePath),
          );
    } catch (e, st) {
      debugPrint('[SaveMeal] meals insert failed: $e');
      debugPrintStack(stackTrace: st, label: '[SaveMeal][meals]');
      rethrow;
    }

    if (meal.items.isNotEmpty) {
      final itemRows = <Map<String, dynamic>>[];
      for (var i = 0; i < meal.items.length; i++) {
        itemRows.add(meal.items[i].toItemRow(mealId: meal.id, sortOrder: i));
      }
      try {
        await _client.from('meal_items').insert(itemRows);
      } catch (e, st) {
        debugPrint('[SaveMeal] meal_items insert failed: $e');
        debugPrintStack(stackTrace: st, label: '[SaveMeal][items]');
        rethrow;
      }
    }
  }

  @override
  Future<List<MealAnalysis>> getAllMeals() async {
    final uid = _uid;
    if (uid == null) return [];

    final mealRows = await _client
        .from('meals')
        .select()
        .eq('user_id', uid)
        .order('logged_at', ascending: false);

    return _hydrateMeals(List<Map<String, dynamic>>.from(mealRows));
  }

  @override
  Future<List<MealAnalysis>> getTodayMeals() async {
    final uid = _uid;
    if (uid == null) return [];

    final now = DateTime.now();
    final startLocal = DateTime(now.year, now.month, now.day);
    final endLocal = startLocal.add(const Duration(days: 1));

    final mealRows = await _client
        .from('meals')
        .select()
        .eq('user_id', uid)
        .gte('logged_at', startLocal.toUtc().toIso8601String())
        .lt('logged_at', endLocal.toUtc().toIso8601String())
        .order('logged_at', ascending: false);

    return _hydrateMeals(List<Map<String, dynamic>>.from(mealRows));
  }

  @override
  Future<double> getTodayCalories() async {
    final meals = await getTodayMeals();
    double total = 0;
    for (final m in meals) {
      total += m.totalCalories;
    }
    return total;
  }

  @override
  Future<void> deleteMeal(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('meals').delete().eq('id', id).eq('user_id', uid);
    // meal_items rows cascade via FK.
  }

  Future<List<MealAnalysis>> _hydrateMeals(
    List<Map<String, dynamic>> mealRows,
  ) async {
    if (mealRows.isEmpty) return [];

    final ids = mealRows.map((m) => m['id'] as String).toList();
    final itemRowsRaw =
        await _client.from('meal_items').select().inFilter('meal_id', ids);
    final itemRows = List<Map<String, dynamic>>.from(itemRowsRaw);

    final byMeal = <String, List<Map<String, dynamic>>>{};
    for (final row in itemRows) {
      final mealId = row['meal_id'] as String;
      byMeal.putIfAbsent(mealId, () => []).add(row);
    }

    final results = <MealAnalysis>[];
    for (final m in mealRows) {
      final id = m['id'] as String;
      final storagePath = m['image_storage_path'] as String?;
      String? imageUrl;
      if (storagePath != null && storagePath.isNotEmpty) {
        try {
          imageUrl = await _imageUploadService.signedUrl(storagePath);
        } catch (_) {
          imageUrl = null;
        }
      }
      results.add(
        MealAnalysis.fromRow(
          meal: m,
          items: byMeal[id] ?? const [],
          imagePath: imageUrl,
        ),
      );
    }
    return results;
  }

  bool _isRemotePath(String path) =>
      path.startsWith('http://') || path.startsWith('https://');
}
