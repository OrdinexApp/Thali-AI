import 'package:flutter_test/flutter_test.dart';
import 'package:thali/services/gemini_service.dart';
import 'package:thali/services/quantity_parser.dart';

void main() {
  group('DetectedItem model', () {
    // ── Constructor defaults ─────────────────────────────────────────────────
    test('has sensible defaults', () {
      final item = DetectedItem(name: 'Idli', estimatedQuantity: '3 pieces');
      expect(item.cookingStyle, 'Home');
      expect(item.confirmed, false);
      expect(item.x, 0.5);
      expect(item.y, 0.5);
      expect(item.category, 'main_dish');
    });

    // ── fromJson ─────────────────────────────────────────────────────────────
    test('fromJson parses all fields correctly', () {
      final json = {
        'name': 'Sambar',
        'estimated_quantity': '1 bowl',
        'category': 'main_dish',
        'x': 0.3,
        'y': 0.4,
      };
      final item = DetectedItem.fromJson(json);
      expect(item.name, 'Sambar');
      expect(item.estimatedQuantity, '1 bowl');
      expect(item.category, 'main_dish');
      expect(item.x, 0.3);
      expect(item.y, 0.4);
      expect(item.confirmed, false);
    });

    test('fromJson falls back to "main_dish" when category missing', () {
      final item = DetectedItem.fromJson({'name': 'Unknown', 'estimated_quantity': '1 serving'});
      expect(item.category, 'main_dish');
    });

    test('fromJson clamps x/y to [0.05, 0.95]', () {
      final item = DetectedItem.fromJson({'name': 'A', 'estimated_quantity': '1', 'x': -0.5, 'y': 2.0});
      expect(item.x, 0.05);
      expect(item.y, 0.95);
    });

    test('fromJson uses defaults for missing name and quantity', () {
      final item = DetectedItem.fromJson({});
      expect(item.name, 'Unknown');
      expect(item.estimatedQuantity, '1 serving');
    });

    // ── toJson ───────────────────────────────────────────────────────────────
    test('toJson includes all fields including category', () {
      final item = DetectedItem(
        name: 'Coconut Chutney',
        estimatedQuantity: '2 tbsp',
        category: 'condiment',
        x: 0.7,
        y: 0.2,
      );
      final json = item.toJson();
      expect(json['name'], 'Coconut Chutney');
      expect(json['estimated_quantity'], '2 tbsp');
      expect(json['category'], 'condiment');
      expect(json['x'], 0.7);
      expect(json['y'], 0.2);
    });

    // ── copyWith ─────────────────────────────────────────────────────────────
    test('copyWith preserves unchanged fields', () {
      final original = DetectedItem(
        name: 'Roti',
        estimatedQuantity: '2 pieces',
        category: 'bread',
        cookingStyle: 'Home',
      );
      final updated = original.copyWith(estimatedQuantity: '4 pieces', confirmed: true);
      expect(updated.name, 'Roti');
      expect(updated.estimatedQuantity, '4 pieces');
      expect(updated.category, 'bread');
      expect(updated.cookingStyle, 'Home');
      expect(updated.confirmed, true);
    });

    test('copyWith can change name (user correction)', () {
      final item = DetectedItem(name: 'Tomato Chutney', estimatedQuantity: '1 tbsp');
      final corrected = item.copyWith(name: 'Green Garlic Chutney');
      expect(corrected.name, 'Green Garlic Chutney');
      expect(corrected.estimatedQuantity, '1 tbsp');
    });

    test('copyWith can change category', () {
      final item = DetectedItem(name: 'Lassi', estimatedQuantity: '1 glass', category: 'main_dish');
      final fixed = item.copyWith(category: 'beverage');
      expect(fixed.category, 'beverage');
    });

    // ── needsCookingStyle ─────────────────────────────────────────────────────
    test('needsCookingStyle is true for main_dish', () {
      final item = DetectedItem(name: 'Dal Tadka', estimatedQuantity: '1 bowl', category: 'main_dish');
      expect(item.needsCookingStyle, true);
    });

    test('needsCookingStyle is false for condiment', () {
      final item = DetectedItem(name: 'Pickle', estimatedQuantity: '1 tsp', category: 'condiment');
      expect(item.needsCookingStyle, false);
    });

    test('needsCookingStyle is false for beverage', () {
      final item = DetectedItem(name: 'Chai', estimatedQuantity: '1 cup', category: 'beverage');
      expect(item.needsCookingStyle, false);
    });

    test('needsCookingStyle is false for dessert', () {
      final item = DetectedItem(name: 'Gulab Jamun', estimatedQuantity: '2 pieces', category: 'dessert');
      expect(item.needsCookingStyle, false);
    });

    test('needsCookingStyle is false for snack', () {
      final item = DetectedItem(name: 'Bhujia', estimatedQuantity: '1 handful', category: 'snack');
      expect(item.needsCookingStyle, false);
    });

    test('needsCookingStyle is true for bread', () {
      final item = DetectedItem(name: 'Roti', estimatedQuantity: '3 pieces', category: 'bread');
      expect(item.needsCookingStyle, true);
    });

    // ── Structured unit/count (v1) ────────────────────────────────────────────
    test('fromJson reads Gemini\'s structured unit + count', () {
      final item = DetectedItem.fromJson({
        'name': 'Idli',
        'estimated_quantity': '3 pieces',
        'category': 'main_dish',
        'unit': 'piece',
        'count': 3,
        'typical_unit_grams': 40,
      });
      expect(item.unit, QuantityUnit.piece);
      expect(item.count, 3);
      expect(item.typicalUnitGrams, 40);
      expect(item.isCountable, true);
    });

    test('fromJson falls back to parsing estimatedQuantity when unit missing', () {
      final item = DetectedItem.fromJson({
        'name': 'Sambar',
        'estimated_quantity': '1 bowl',
        'category': 'main_dish',
      });
      expect(item.unit, QuantityUnit.bowl);
      expect(item.count, 1);
      expect(item.isCountable, false);
    });

    test('fromJson: unknown unit string falls through to parser', () {
      final item = DetectedItem.fromJson({
        'name': 'Namkeen',
        'estimated_quantity': '1 handful',
        'unit': 'gibberish',
      });
      expect(item.unit, QuantityUnit.serving); // parser matches "handful" → serving
    });

    test('fromJson: gibberish estimatedQuantity falls back to multiplier', () {
      final item = DetectedItem.fromJson({
        'name': 'Mystery dish',
        'estimated_quantity': 'idk',
      });
      expect(item.unit, QuantityUnit.multiplier);
    });

    test('toJson round-trips unit, count, typical_unit_grams', () {
      final item = DetectedItem(
        name: 'Dosa',
        estimatedQuantity: '2 pieces',
        unit: QuantityUnit.piece,
        count: 2,
        typicalUnitGrams: 120,
      );
      final json = item.toJson();
      expect(json['unit'], 'piece');
      expect(json['count'], 2);
      expect(json['typical_unit_grams'], 120);
    });

    test('isCountable true only for piece unit', () {
      expect(
        DetectedItem(name: 'x', estimatedQuantity: '1', unit: QuantityUnit.piece).isCountable,
        true,
      );
      expect(
        DetectedItem(name: 'x', estimatedQuantity: '1', unit: QuantityUnit.bowl).isCountable,
        false,
      );
      expect(
        DetectedItem(name: 'x', estimatedQuantity: '1', unit: QuantityUnit.multiplier).isCountable,
        false,
      );
    });

    test('copyWith preserves unit/count when not overridden', () {
      final original = DetectedItem(
        name: 'Vada',
        estimatedQuantity: '3 pieces',
        unit: QuantityUnit.piece,
        count: 3,
      );
      final updated = original.copyWith(confirmed: true);
      expect(updated.unit, QuantityUnit.piece);
      expect(updated.count, 3);
    });

    test('copyWith can change count (decrement via long-press)', () {
      final original = DetectedItem(
        name: 'Idli',
        estimatedQuantity: '3 pieces',
        unit: QuantityUnit.piece,
        count: 3,
      );
      final decremented = original.copyWith(count: 2, estimatedQuantity: '2 pieces');
      expect(decremented.count, 2);
      expect(decremented.estimatedQuantity, '2 pieces');
      expect(decremented.unit, QuantityUnit.piece); // preserved
    });
  });

  group('DetectionResult', () {
    test('copyWithItem replaces only the specified index', () {
      final items = [
        DetectedItem(name: 'Idli', estimatedQuantity: '3 pieces'),
        DetectedItem(name: 'Sambar', estimatedQuantity: '1 bowl'),
      ];
      final result = DetectionResult(items: items, suggestedLabels: ['Idli', 'Sambar']);

      final updated = DetectedItem(name: 'Idli', estimatedQuantity: '5 pieces', confirmed: true);
      final newResult = result.copyWithItem(0, updated);

      expect(newResult.items[0].estimatedQuantity, '5 pieces');
      expect(newResult.items[0].confirmed, true);
      expect(newResult.items[1].name, 'Sambar'); // unchanged
    });

    test('copyWithItem does not mutate the original', () {
      final items = [DetectedItem(name: 'A', estimatedQuantity: '1 bowl')];
      final result = DetectionResult(items: items, suggestedLabels: []);
      result.copyWithItem(0, DetectedItem(name: 'B', estimatedQuantity: '1 bowl'));
      expect(result.items[0].name, 'A');
    });

    test('isFromApi defaults to false', () {
      final r = DetectionResult(items: [], suggestedLabels: []);
      expect(r.isFromApi, false);
    });
  });
}
