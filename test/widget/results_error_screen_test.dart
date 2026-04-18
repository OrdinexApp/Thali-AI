import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thali/features/history/data/models/meal_model.dart';
import 'package:thali/features/history/data/repositories/meal_repository.dart';
import 'package:thali/features/results/presentation/screens/results_screen.dart';
import 'package:thali/services/gemini_service.dart';
import 'package:thali/services/providers.dart';

/// A service that always fails, counting how many times analyze was called.
class _AlwaysFailsCounting extends GeminiService {
  int callCount = 0;

  @override
  Future<MealAnalysis> analyzeThaliImage({
    required String imagePath,
    required String mealId,
    DetectionResult? detectedItems,
  }) async {
    callCount++;
    throw MealAnalysisException(
        AnalysisFailureReason.serviceDown, 'simulated failure');
  }
}

class _InMemoryRepo extends MealRepository {
  @override
  Future<void> saveMeal(MealAnalysis meal) async {}
}

Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

Widget _wrapResultsScreen(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: ResultsScreen(),
    ),
  );
}

void main() {
  group('ResultsScreen error state', () {
    testWidgets(
      'after an analyze failure, shows neutral error copy (no vendor leak)',
      (tester) async {
        await _useTallSurface(tester);
        final service = _AlwaysFailsCounting();

        final container = ProviderContainer(overrides: [
          geminiServiceProvider.overrideWithValue(service),
          mealRepositoryProvider.overrideWithValue(_InMemoryRepo()),
        ]);
        addTearDown(container.dispose);

        await container.read(analysisProvider.notifier).analyzeImage(
              imagePath: '/fake/a.jpg',
            );

        await tester.pumpWidget(_wrapResultsScreen(container));
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.textContaining("Couldn't analyze your meal"), findsOneWidget);

        // Critical: no vendor name or HTTP status must appear on screen.
        expect(find.textContaining('Gemini'), findsNothing);
        expect(find.textContaining('gemini'), findsNothing);
        expect(find.textContaining('Google'), findsNothing);
        expect(find.textContaining('HTTP'), findsNothing);
        expect(find.textContaining('503'), findsNothing);
        expect(find.textContaining('429'), findsNothing);

        // Both actions must be offered.
        expect(find.text('Try Again'), findsOneWidget);
        expect(find.text('Go back'), findsOneWidget);
      },
    );

    testWidgets('tapping Try Again re-invokes analyze', (tester) async {
      await _useTallSurface(tester);
      final service = _AlwaysFailsCounting();

      final container = ProviderContainer(overrides: [
        geminiServiceProvider.overrideWithValue(service),
        mealRepositoryProvider.overrideWithValue(_InMemoryRepo()),
      ]);
      addTearDown(container.dispose);

      await container.read(analysisProvider.notifier).analyzeImage(
            imagePath: '/fake/a.jpg',
          );
      expect(service.callCount, 1);

      await tester.pumpWidget(_wrapResultsScreen(container));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(find.text('Try Again'));
      await tester.tap(find.text('Try Again'));
      // Retry is async — allow the notifier to resolve.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(service.callCount, 2,
          reason: 'Try Again must reinvoke analyze with the last inputs.');
    });
  });
}
