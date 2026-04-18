import 'package:flutter_test/flutter_test.dart';
import 'package:thali/services/gemini_service.dart';
import 'package:thali/services/quantity_parser.dart';

DetectedItem _item(String name, {String qty = '1 serving'}) {
  return DetectedItem(
    name: name,
    estimatedQuantity: qty,
    unit: QuantityUnit.serving,
  );
}

void main() {
  group('DetectionMerge.dedupeByName', () {
    test('returns the original list when additions is empty', () {
      final original = [_item('Idli'), _item('Sambar')];
      final merged = DetectionMerge.dedupeByName(original, const []);
      expect(merged.length, 2);
      expect(merged[0].name, 'Idli');
      expect(merged[1].name, 'Sambar');
    });

    test('returns a NEW list (does not mutate the original)', () {
      final original = [_item('Idli')];
      final merged =
          DetectionMerge.dedupeByName(original, [_item('Papad')]);
      expect(identical(merged, original), isFalse);
      expect(original.length, 1,
          reason: 'Original must not gain items from merge.');
      expect(merged.length, 2);
    });

    test('appends net-new items after the original, preserving order', () {
      final original = [_item('Idli'), _item('Sambar')];
      final additions = [_item('Papad'), _item('Lemon Wedge')];
      final merged = DetectionMerge.dedupeByName(original, additions);
      expect(merged.map((i) => i.name).toList(),
          ['Idli', 'Sambar', 'Papad', 'Lemon Wedge']);
    });

    test('drops additions whose name matches an original, case-insensitive', () {
      final original = [_item('Idli'), _item('Coconut Chutney')];
      final additions = [_item('IDLI'), _item('coconut chutney'), _item('Papad')];
      final merged = DetectionMerge.dedupeByName(original, additions);
      expect(merged.length, 3);
      expect(merged.map((i) => i.name).toList(),
          ['Idli', 'Coconut Chutney', 'Papad']);
    });

    test('drops additions whose name matches an original, ignoring whitespace', () {
      final original = [_item('Idli')];
      final additions = [_item('  idli  '), _item('Vada')];
      final merged = DetectionMerge.dedupeByName(original, additions);
      expect(merged.map((i) => i.name).toList(), ['Idli', 'Vada']);
    });

    test('drops duplicates WITHIN additions themselves', () {
      final original = [_item('Idli')];
      final additions = [_item('Papad'), _item('papad'), _item('PAPAD')];
      final merged = DetectionMerge.dedupeByName(original, additions);
      expect(merged.length, 2,
          reason: 'Papad should appear only once even if verification '
              'returned it multiple times.');
      expect(merged.map((i) => i.name).toList(), ['Idli', 'Papad']);
    });

    test('skips additions with empty or whitespace-only names', () {
      final original = [_item('Idli')];
      final additions = [_item(''), _item('   '), _item('Papad')];
      final merged = DetectionMerge.dedupeByName(original, additions);
      expect(merged.map((i) => i.name).toList(), ['Idli', 'Papad']);
    });

    test('returns an empty list when both inputs are empty', () {
      final merged = DetectionMerge.dedupeByName(const [], const []);
      expect(merged, isEmpty);
    });

    test('preserves fields of appended items (not just the name)', () {
      final original = [_item('Idli')];
      final papad = DetectedItem(
        name: 'Papad',
        estimatedQuantity: '1 piece',
        category: 'condiment',
        unit: QuantityUnit.piece,
        count: 1,
        typicalUnitGrams: 10,
        x: 0.9,
        y: 0.1,
      );
      final merged = DetectionMerge.dedupeByName(original, [papad]);
      expect(merged.last.name, 'Papad');
      expect(merged.last.category, 'condiment');
      expect(merged.last.unit, QuantityUnit.piece);
      expect(merged.last.typicalUnitGrams, 10);
      expect(merged.last.x, closeTo(0.9, 0.001));
    });
  });

  group('DetectionMerge.dedupeLabels', () {
    test('returns original when additions is empty', () {
      final merged = DetectionMerge.dedupeLabels(['Idli', 'Sambar'], const []);
      expect(merged, ['Idli', 'Sambar']);
    });

    test('appends new item names that are not already in labels', () {
      final merged = DetectionMerge.dedupeLabels(
        ['Idli', 'Sambar'],
        [_item('Papad'), _item('Coconut Chutney')],
      );
      expect(merged, ['Idli', 'Sambar', 'Papad', 'Coconut Chutney']);
    });

    test('drops additions whose name matches an existing label, case-insensitive', () {
      final merged = DetectionMerge.dedupeLabels(
        ['Idli', 'Sambar'],
        [_item('IDLI'), _item('Papad')],
      );
      expect(merged, ['Idli', 'Sambar', 'Papad']);
    });

    test('drops additions with empty names', () {
      final merged = DetectionMerge.dedupeLabels(
        ['Idli'],
        [_item(''), _item('Papad')],
      );
      expect(merged, ['Idli', 'Papad']);
    });

    test('returns a NEW list (does not mutate original)', () {
      final original = ['Idli'];
      final merged = DetectionMerge.dedupeLabels(original, [_item('Papad')]);
      expect(identical(merged, original), isFalse);
      expect(original.length, 1);
      expect(merged.length, 2);
    });
  });
}
