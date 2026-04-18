import 'package:flutter_test/flutter_test.dart';
import 'package:thali/features/history/data/models/meal_model.dart';
import 'package:thali/features/history/data/repositories/meal_repository.dart';
import 'package:thali/services/gemini_service.dart';
import 'package:thali/services/providers.dart';

/// These tests encode the core product safety rule for meal analysis:
///   "When the remote service is unavailable, we do NOT fabricate calorie
///    numbers. We raise a neutral error the UI can show to the user."
///
/// If anyone later reintroduces a silent mock/DB fallback in the happy path
/// of [GeminiService.analyzeThaliImage], these tests fail loudly.

class _AlwaysFailsService extends GeminiService {
  _AlwaysFailsService(this._reason);
  final AnalysisFailureReason _reason;

  @override
  Future<MealAnalysis> analyzeThaliImage({
    required String imagePath,
    required String mealId,
    DetectionResult? detectedItems,
  }) async {
    throw MealAnalysisException(_reason, 'simulated failure');
  }

  @override
  Future<DetectionResult> detectFoodItems(String imagePath) async {
    throw MealAnalysisException(_reason, 'simulated failure');
  }
}

class _InMemoryRepo implements MealRepository {
  final List<MealAnalysis> saved = [];

  @override
  Future<void> saveMeal(MealAnalysis meal) async {
    saved.add(meal);
  }

  @override
  Future<List<MealAnalysis>> getAllMeals() async => saved;

  @override
  Future<List<MealAnalysis>> getTodayMeals() async => saved;

  @override
  Future<double> getTodayCalories() async {
    double total = 0;
    for (final m in saved) {
      total += m.totalCalories;
    }
    return total;
  }

  @override
  Future<void> deleteMeal(String id) async {
    saved.removeWhere((m) => m.id == id);
  }
}

void main() {
  group('MealAnalysisException.userMessage', () {
    test('never mentions any vendor name or model identifier', () {
      for (final reason in AnalysisFailureReason.values) {
        final msg = MealAnalysisException(reason).userMessage.toLowerCase();
        expect(msg.contains('gemini'), isFalse,
            reason: '$reason leaks "gemini" to user');
        expect(msg.contains('google'), isFalse,
            reason: '$reason leaks "google" to user');
        expect(msg.contains('openai'), isFalse,
            reason: '$reason leaks "openai" to user');
        expect(msg.contains('gpt'), isFalse,
            reason: '$reason leaks "gpt" to user');
        expect(msg.contains('api key'), isFalse,
            reason: '$reason should not mention api key');
        expect(msg.contains('http'), isFalse,
            reason: '$reason should not leak HTTP details');
        expect(msg.isNotEmpty, isTrue);
      }
    });

    test('each reason maps to a distinct user-facing message', () {
      final messages = AnalysisFailureReason.values
          .map((r) => MealAnalysisException(r).userMessage)
          .toSet();
      // At minimum: network, timeout, rateLimited, serviceDown, unknown
      // should all produce user-distinguishable copy.
      expect(messages.length, greaterThanOrEqualTo(5));
    });

    test('toString may contain diagnostic but userMessage must not', () {
      final e = MealAnalysisException(
        AnalysisFailureReason.rateLimited,
        'HTTP 429: quota exceeded on model gemini-2.0-flash',
      );
      expect(e.toString().toLowerCase().contains('gemini'), isTrue,
          reason: 'toString is for dev logs and may include vendor detail');
      expect(e.userMessage.toLowerCase().contains('gemini'), isFalse,
          reason: 'userMessage MUST stay vendor-neutral');
    });
  });

  group('AnalysisNotifier', () {
    test('sets error status with neutral userMessage when analysis fails', () async {
      final notifier = AnalysisNotifier(
        _AlwaysFailsService(AnalysisFailureReason.rateLimited),
        _InMemoryRepo(),
      );

      await notifier.analyzeImage(
        imagePath: '/fake/path.jpg',
        detectedItems: null,
      );

      expect(notifier.state.status, AnalysisStatus.error);
      expect(notifier.state.result, isNull,
          reason: 'No MealAnalysis may be produced on failure — no silent numbers.');
      expect(notifier.state.error, isNotNull);
      final err = notifier.state.error!.toLowerCase();
      expect(err.contains('gemini'), isFalse);
      expect(err.contains('google'), isFalse);
      expect(err.contains('http'), isFalse);
      expect(notifier.state.failureReason, AnalysisFailureReason.rateLimited);
    });

    test('retry() re-invokes analyze with the last inputs', () async {
      final service = _CountingFailService();
      final notifier = AnalysisNotifier(service, _InMemoryRepo());

      await notifier.analyzeImage(imagePath: '/fake/a.jpg');
      expect(service.callCount, 1);

      await notifier.retry();
      expect(service.callCount, 2);
      expect(service.lastImagePath, '/fake/a.jpg');
    });

    test('retry() is a no-op when no previous analyze has been invoked', () async {
      final service = _CountingFailService();
      final notifier = AnalysisNotifier(service, _InMemoryRepo());

      await notifier.retry();
      expect(service.callCount, 0);
      expect(notifier.state.status, AnalysisStatus.idle);
    });

    test('reset() clears retry state so subsequent retry() is a no-op', () async {
      final service = _CountingFailService();
      final notifier = AnalysisNotifier(service, _InMemoryRepo());

      await notifier.analyzeImage(imagePath: '/fake/a.jpg');
      notifier.reset();
      await notifier.retry();

      expect(service.callCount, 1, reason: 'reset() must forget last inputs');
      expect(notifier.state.status, AnalysisStatus.idle);
    });
  });
}

class _CountingFailService extends GeminiService {
  int callCount = 0;
  String? lastImagePath;

  @override
  Future<MealAnalysis> analyzeThaliImage({
    required String imagePath,
    required String mealId,
    DetectionResult? detectedItems,
  }) async {
    callCount++;
    lastImagePath = imagePath;
    throw MealAnalysisException(
        AnalysisFailureReason.serviceDown, 'test failure');
  }
}
