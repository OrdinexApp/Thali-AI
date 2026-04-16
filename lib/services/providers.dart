import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/history/data/models/meal_model.dart';
import '../features/history/data/repositories/meal_repository.dart';
import 'gemini_service.dart';

final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return MealRepository();
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

final selectedImagePathProvider = StateProvider<String?>((ref) => null);

final rotiCountProvider = StateProvider<int>((ref) => 2);

final detectedItemsProvider = StateProvider<DetectionResult?>((ref) => null);

// --- Detection state (Step 1: detect food items from photo) ---

enum DetectionStatus { idle, loading, success, error }

class DetectionState {
  final DetectionStatus status;
  final DetectionResult? result;
  final String? error;
  final bool isFromApi;

  const DetectionState({
    this.status = DetectionStatus.idle,
    this.result,
    this.error,
    this.isFromApi = false,
  });
}

class DetectionNotifier extends StateNotifier<DetectionState> {
  final GeminiService _geminiService;

  DetectionNotifier(this._geminiService) : super(const DetectionState());

  Future<void> detectItems(String imagePath) async {
    state = const DetectionState(status: DetectionStatus.loading);
    try {
      final result = await _geminiService.detectFoodItems(imagePath);
      state = DetectionState(
        status: DetectionStatus.success,
        result: result,
        isFromApi: result.isFromApi,
      );
    } on GeminiApiException catch (e) {
      debugPrint('[Detection] API failed: $e');
      // API failed — still show success with empty items so user can add manually
      state = DetectionState(
        status: DetectionStatus.error,
        error: e.isQuotaExhausted
            ? 'API quota exhausted for today. You can add items manually below.'
            : 'AI detection failed (${e.statusCode}). You can add items manually.',
      );
    } catch (e) {
      debugPrint('[Detection] Unexpected error: $e');
      state = DetectionState(
        status: DetectionStatus.error,
        error: 'Detection failed. You can add items manually.',
      );
    }
  }

  void updateItem(int index, DetectedItem updatedItem) {
    if (state.result == null) return;
    state = DetectionState(
      status: state.status,
      result: state.result!.copyWithItem(index, updatedItem),
      isFromApi: state.isFromApi,
    );
  }

  void addItem(DetectedItem item) {
    final currentItems = state.result?.items ?? [];
    final currentLabels = state.result?.suggestedLabels ?? [];
    state = DetectionState(
      status: DetectionStatus.success,
      result: DetectionResult(
        items: [...currentItems, item],
        suggestedLabels: [...currentLabels, item.name],
        isFromApi: state.isFromApi,
      ),
      isFromApi: state.isFromApi,
    );
  }

  void removeItem(int index) {
    if (state.result == null) return;
    final newItems = List<DetectedItem>.from(state.result!.items);
    final newLabels = List<String>.from(state.result!.suggestedLabels);
    if (index < newItems.length) newItems.removeAt(index);
    if (index < newLabels.length) newLabels.removeAt(index);
    state = DetectionState(
      status: DetectionStatus.success,
      result: DetectionResult(
        items: newItems,
        suggestedLabels: newLabels,
        isFromApi: state.isFromApi,
      ),
      isFromApi: state.isFromApi,
    );
  }

  void reset() {
    state = const DetectionState();
  }
}

final detectionProvider =
    StateNotifierProvider<DetectionNotifier, DetectionState>((ref) {
  return DetectionNotifier(ref.watch(geminiServiceProvider));
});

// --- Analysis state (Step 2: full nutrition breakdown) ---

enum AnalysisStatus { idle, loading, success, error }

class AnalysisState {
  final AnalysisStatus status;
  final MealAnalysis? result;
  final String? error;

  const AnalysisState({
    this.status = AnalysisStatus.idle,
    this.result,
    this.error,
  });
}

class AnalysisNotifier extends StateNotifier<AnalysisState> {
  final GeminiService _geminiService;
  final MealRepository _mealRepository;

  AnalysisNotifier(this._geminiService, this._mealRepository)
      : super(const AnalysisState());

  Future<void> analyzeImage({
    required String imagePath,
    required int rotiCount,
    DetectionResult? detectedItems,
  }) async {
    state = const AnalysisState(status: AnalysisStatus.loading);

    try {
      final mealId = DateTime.now().millisecondsSinceEpoch.toString();
      final result = await _geminiService.analyzeThaliImage(
        imagePath: imagePath,
        rotiCount: rotiCount,
        mealId: mealId,
        detectedItems: detectedItems,
      );
      state = AnalysisState(
        status: AnalysisStatus.success,
        result: result,
      );
    } catch (e) {
      state = AnalysisState(
        status: AnalysisStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> saveMeal() async {
    if (state.result != null) {
      await _mealRepository.saveMeal(state.result!);
    }
  }

  void reset() {
    state = const AnalysisState();
  }
}

final analysisProvider =
    StateNotifierProvider<AnalysisNotifier, AnalysisState>((ref) {
  return AnalysisNotifier(
    ref.watch(geminiServiceProvider),
    ref.watch(mealRepositoryProvider),
  );
});

// --- Meal history providers ---

final mealHistoryProvider = FutureProvider<List<MealAnalysis>>((ref) async {
  final repo = ref.watch(mealRepositoryProvider);
  return repo.getAllMeals();
});

final todayCaloriesProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(mealRepositoryProvider);
  return repo.getTodayCalories();
});

final todayMealsProvider = FutureProvider<List<MealAnalysis>>((ref) async {
  final repo = ref.watch(mealRepositoryProvider);
  return repo.getTodayMeals();
});
