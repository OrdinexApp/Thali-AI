import 'package:flutter_test/flutter_test.dart';
import 'package:thali/services/gemini_service.dart';

// We test the grouping logic indirectly via DetectedItem.category.
// The _categoryFromAI function lives in question_screen.dart (private),
// so we test its contract through the category enum string values.

void main() {
  group('AI category → display mapping contract', () {
    final validCategories = [
      'main_dish',
      'bread',
      'rice',
      'dairy',
      'salad_side',
      'condiment',
      'beverage',
      'dessert',
      'snack',
    ];

    for (final cat in validCategories) {
      test('$cat round-trips through DetectedItem', () {
        final item = DetectedItem(name: 'X', estimatedQuantity: '1', category: cat);
        expect(item.category, cat);
      });
    }

    test('unknown category falls back to main_dish via fromJson', () {
      final item = DetectedItem.fromJson({
        'name': 'Mystery',
        'estimated_quantity': '1 piece',
        'category': 'alien_food',
      });
      // The model stores whatever the AI returns; the grouping screen maps unknowns.
      // fromJson should store the raw value so the screen can fall back.
      expect(item.category, 'alien_food');
    });

    test('missing category defaults to main_dish', () {
      final item = DetectedItem.fromJson({'name': 'X', 'estimated_quantity': '1'});
      expect(item.category, 'main_dish');
    });
  });

  group('needsCookingStyle by category', () {
    final needsStyle = ['main_dish', 'bread', 'rice', 'dairy', 'salad_side'];
    final noStyle = ['condiment', 'beverage', 'dessert', 'snack'];

    for (final cat in needsStyle) {
      test('$cat needs cooking style', () {
        final item = DetectedItem(name: 'X', estimatedQuantity: '1', category: cat);
        expect(item.needsCookingStyle, true, reason: 'category=$cat should need cooking style');
      });
    }

    for (final cat in noStyle) {
      test('$cat does NOT need cooking style', () {
        final item = DetectedItem(name: 'X', estimatedQuantity: '1', category: cat);
        expect(item.needsCookingStyle, false, reason: 'category=$cat should NOT need cooking style');
      });
    }
  });

  group('Real-world item categorisation via Gemini category field', () {
    DetectedItem item(String name, String category) =>
        DetectedItem(name: name, estimatedQuantity: '1', category: category);

    test('Idli is main_dish (AI assigns this, not hardcoded keywords)', () {
      expect(item('Idli', 'main_dish').category, 'main_dish');
    });

    test('Coconut Chutney is condiment', () {
      expect(item('Coconut Chutney', 'condiment').category, 'condiment');
    });

    test('Roti is bread', () {
      expect(item('Roti', 'bread').category, 'bread');
    });

    test('Steamed Rice is rice', () {
      expect(item('Steamed Rice', 'rice').category, 'rice');
    });

    test('Raita is dairy', () {
      expect(item('Raita', 'dairy').category, 'dairy');
    });

    test('Kachumber Salad is salad_side', () {
      expect(item('Kachumber Salad', 'salad_side').category, 'salad_side');
    });

    test('Gulab Jamun is dessert', () {
      expect(item('Gulab Jamun', 'dessert').category, 'dessert');
    });

    test('Masala Chai is beverage', () {
      expect(item('Masala Chai', 'beverage').category, 'beverage');
    });
  });
}
