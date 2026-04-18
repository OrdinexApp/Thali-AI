import 'package:flutter_test/flutter_test.dart';
import 'package:thali/services/gemini_service.dart';
import 'package:thali/services/providers.dart';

/// Minimal stub that returns a prebuilt [DetectionResult]
/// without touching any network or file I/O.
class _FakeGeminiService extends GeminiService {
  _FakeGeminiService(this._result);
  final DetectionResult _result;

  @override
  Future<DetectionResult> detectFoodItems(String imagePath) async => _result;
}

void main() {
  group('DetectionNotifier.detectItems', () {
    test('auto-confirms every detected item on success', () async {
      final fake = _FakeGeminiService(
        DetectionResult(
          items: [
            DetectedItem(
              name: 'Idli',
              estimatedQuantity: '4 pieces',
              category: 'main_dish',
            ),
            DetectedItem(
              name: 'Sambar',
              estimatedQuantity: '1 bowl',
              category: 'main_dish',
            ),
            DetectedItem(
              name: 'Coconut Chutney',
              estimatedQuantity: '1 tbsp',
              category: 'condiment',
            ),
          ],
          suggestedLabels: const ['Idli', 'Sambar', 'Coconut Chutney'],
          isFromApi: true,
        ),
      );

      final notifier = DetectionNotifier(fake);
      await notifier.detectItems('/fake/path.jpg');

      expect(notifier.state.status, DetectionStatus.success);
      final items = notifier.state.result!.items;
      expect(items.length, 3);
      expect(items.every((i) => i.confirmed), isTrue,
          reason: 'Every item should be auto-confirmed after detection.');
      // Original field preserved through copyWith
      expect(items[0].name, 'Idli');
      expect(items[0].estimatedQuantity, '4 pieces');
      expect(items[2].category, 'condiment');
    });

    test('addItem after detection keeps its own confirmed flag', () async {
      final fake = _FakeGeminiService(DetectionResult(
        items: [
          DetectedItem(name: 'Rice', estimatedQuantity: '1 cup'),
        ],
        suggestedLabels: const ['Rice'],
        isFromApi: true,
      ));

      final notifier = DetectionNotifier(fake);
      await notifier.detectItems('/fake/path.jpg');

      // Manually added item — caller decides confirmed state
      notifier.addItem(DetectedItem(
        name: 'Pickle',
        estimatedQuantity: '1 tsp',
        confirmed: false,
      ));

      final items = notifier.state.result!.items;
      expect(items.length, 2);
      expect(items.first.confirmed, isTrue); // auto-confirmed on detect
      expect(items.last.confirmed, isFalse); // manually added, as specified
    });
  });
}
