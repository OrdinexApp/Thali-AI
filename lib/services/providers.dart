import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/history/data/models/meal_model.dart';
import '../features/history/data/repositories/meal_repository.dart';
import '../features/history/data/repositories/supabase_meal_repository.dart';
import '../features/profile/data/models/profile_model.dart';
import '../features/profile/data/profile_repository.dart';
import 'connectivity_service.dart';
import 'gemini_service.dart';
import 'image_upload_service.dart';

// --- Infra services ---

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Pushes online/offline status. Combines an initial check with the
/// platform connectivity stream so the UI updates as soon as the user
/// (re)connects.
final connectivityStatusProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  yield await service.isOnline();
  yield* service.onStatusChange();
});

final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return ImageUploadService();
});

// --- Auth ---

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Streams Supabase auth events. AuthGate uses this to route between
/// sign-in and the main shell.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  final state = ref.watch(authStateProvider);
  return state.maybeWhen(
    data: (s) => s.session?.user,
    orElse: () => ref.watch(authRepositoryProvider).currentUser,
  );
});

// --- Profile ---

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final profileProvider = FutureProvider<Profile?>((ref) async {
  // Re-fetch when auth changes so logout/login picks up the right profile.
  ref.watch(currentUserProvider);
  return ref.watch(profileRepositoryProvider).getCurrentProfile();
});

/// Daily calorie goal for the current user, falling back to 2000.
final dailyCalorieGoalProvider = Provider<int>((ref) {
  final profile = ref.watch(profileProvider);
  return profile.maybeWhen(
    data: (p) => p?.dailyCalorieGoal ?? 2000,
    orElse: () => 2000,
  );
});

// --- Meals (Supabase) ---

/// Default to the Supabase-backed implementation. Tests can override this
/// provider with an in-memory [MealRepository] without booting Supabase.
final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return SupabaseMealRepository();
});

// --- Gemini + capture flow ---

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

final selectedImagePathProvider = StateProvider<String?>((ref) => null);

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
      // Auto-confirm every item up front. The model already gives us the name,
      // quantity, and category, so the user only needs to correct mistakes
      // (via tap-to-edit) instead of confirming every correct row one-by-one.
      final autoConfirmed = DetectionResult(
        items: result.items.map((i) => i.copyWith(confirmed: true)).toList(),
        suggestedLabels: result.suggestedLabels,
        isFromApi: result.isFromApi,
      );
      state = DetectionState(
        status: DetectionStatus.success,
        result: autoConfirmed,
        isFromApi: result.isFromApi,
      );
    } on MealAnalysisException catch (e) {
      debugPrint('[Detection] Failed: $e');
      // Detection failure isn't fatal — the user can still add items manually
      // below. Show a neutral message; do not leak status codes or vendor.
      state = DetectionState(
        status: DetectionStatus.error,
        error:
            "We couldn't auto-detect items this time. You can add them manually below.",
      );
    } catch (e) {
      debugPrint('[Detection] Unexpected: $e');
      state = const DetectionState(
        status: DetectionStatus.error,
        error:
            "We couldn't auto-detect items this time. You can add them manually below.",
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
  final AnalysisFailureReason? failureReason;

  const AnalysisState({
    this.status = AnalysisStatus.idle,
    this.result,
    this.error,
    this.failureReason,
  });
}

class AnalysisNotifier extends StateNotifier<AnalysisState> {
  final GeminiService _geminiService;
  final MealRepository _mealRepository;

  // Remember last inputs so the UI can retry in place without re-navigating.
  String? _lastImagePath;
  DetectionResult? _lastDetectedItems;

  AnalysisNotifier(this._geminiService, this._mealRepository)
      : super(const AnalysisState());

  Future<void> analyzeImage({
    required String imagePath,
    DetectionResult? detectedItems,
  }) async {
    _lastImagePath = imagePath;
    _lastDetectedItems = detectedItems;
    state = const AnalysisState(status: AnalysisStatus.loading);

    try {
      final mealId = const Uuid().v4();
      final result = await _geminiService.analyzeThaliImage(
        imagePath: imagePath,
        mealId: mealId,
        detectedItems: detectedItems,
      );
      state = AnalysisState(
        status: AnalysisStatus.success,
        result: result,
      );
    } on MealAnalysisException catch (e) {
      debugPrint('[Analysis] Failed: $e');
      state = AnalysisState(
        status: AnalysisStatus.error,
        error: e.userMessage,
        failureReason: e.reason,
      );
    } catch (e) {
      debugPrint('[Analysis] Unexpected: $e');
      state = const AnalysisState(
        status: AnalysisStatus.error,
        error: "Couldn't analyze your meal right now. Please try again.",
        failureReason: AnalysisFailureReason.unknown,
      );
    }
  }

  /// Retry the last analysis with the same inputs. Safe to call only after
  /// a previous [analyzeImage] has been made in this session.
  Future<void> retry() async {
    final path = _lastImagePath;
    if (path == null) return;
    await analyzeImage(
      imagePath: path,
      detectedItems: _lastDetectedItems,
    );
  }

  Future<void> saveMeal() async {
    if (state.result != null) {
      await _mealRepository.saveMeal(state.result!);
    }
  }

  void reset() {
    _lastImagePath = null;
    _lastDetectedItems = null;
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
  ref.watch(currentUserProvider);
  final repo = ref.watch(mealRepositoryProvider);
  return repo.getAllMeals();
});

final todayCaloriesProvider = FutureProvider<double>((ref) async {
  ref.watch(currentUserProvider);
  final repo = ref.watch(mealRepositoryProvider);
  return repo.getTodayCalories();
});

final todayMealsProvider = FutureProvider<List<MealAnalysis>>((ref) async {
  ref.watch(currentUserProvider);
  final repo = ref.watch(mealRepositoryProvider);
  return repo.getTodayMeals();
});
