import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/history/data/models/meal_model.dart';
import '../features/history/data/repositories/meal_repository.dart';
import 'gemini_service.dart';

// Repository & Service providers
final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return MealRepository();
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

// Image path state
final selectedImagePathProvider = StateProvider<String?>((ref) => null);

// Roti count state
final rotiCountProvider = StateProvider<int>((ref) => 2);

// Analysis state
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

  AnalysisState copyWith({
    AnalysisStatus? status,
    MealAnalysis? result,
    String? error,
  }) {
    return AnalysisState(
      status: status ?? this.status,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }
}

class AnalysisNotifier extends StateNotifier<AnalysisState> {
  final GeminiService _geminiService;
  final MealRepository _mealRepository;

  AnalysisNotifier(this._geminiService, this._mealRepository)
      : super(const AnalysisState());

  Future<void> analyzeImage({
    required String imagePath,
    required int rotiCount,
  }) async {
    state = state.copyWith(status: AnalysisStatus.loading);

    try {
      final mealId = DateTime.now().millisecondsSinceEpoch.toString();
      final result = await _geminiService.analyzeThaliImage(
        imagePath: imagePath,
        rotiCount: rotiCount,
        mealId: mealId,
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

// Meal history
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
