import 'package:flutter_test/flutter_test.dart';
import 'package:thali/services/indian_food_db.dart';

void main() {
  group('IndianFoodDB.lookup()', () {
    test('finds roti by exact key', () {
      final r = IndianFoodDB.lookup('roti');
      expect(r, isNotNull);
      expect(r!.calories, greaterThan(0));
    });

    test('lookup is case-insensitive', () {
      final lower = IndianFoodDB.lookup('dal tadka');
      final upper = IndianFoodDB.lookup('Dal Tadka');
      expect(lower?.name, upper?.name);
    });

    test('returns null for completely unknown food', () {
      final r = IndianFoodDB.lookup('zxqfood99');
      expect(r, isNull);
    });

    test('all DB entries have positive calories', () {
      for (final entry in IndianFoodDB.database.values) {
        expect(entry.calories, greaterThan(0),
            reason: '${entry.name} must have positive calories');
      }
    });

    test('all DB entries have a non-empty portion string', () {
      for (final entry in IndianFoodDB.database.values) {
        expect(entry.portion.isNotEmpty, true,
            reason: '${entry.name} missing portion string');
      }
    });
  });

  group('IndianFoodDB.applyStyle()', () {
    test('Restaurant style increases calories vs Home', () {
      final base = IndianFoodDB.lookup('paneer butter masala') ??
          IndianFoodDB.lookup('dal tadka')!;
      final home = IndianFoodDB.applyStyle(base, 'Home');
      final restaurant = IndianFoodDB.applyStyle(base, 'Restaurant');
      expect(restaurant.calories, greaterThanOrEqualTo(home.calories));
    });

    test('Diet style is lighter than Home', () {
      final base = IndianFoodDB.lookup('dal tadka')!;
      final home = IndianFoodDB.applyStyle(base, 'Home');
      final diet = IndianFoodDB.applyStyle(base, 'Diet');
      expect(diet.calories, lessThanOrEqualTo(home.calories));
    });

    test('Less Oil style is lighter than Restaurant', () {
      final base = IndianFoodDB.lookup('roti')!;
      final restaurant = IndianFoodDB.applyStyle(base, 'Restaurant');
      final lessOil = IndianFoodDB.applyStyle(base, 'Less Oil');
      expect(lessOil.calories, lessThanOrEqualTo(restaurant.calories));
    });

    test('unknown style returns unchanged calories', () {
      final base = IndianFoodDB.lookup('roti')!;
      final custom = IndianFoodDB.applyStyle(base, 'SuperHome');
      expect(custom.calories, base.calories);
    });
  });
}
