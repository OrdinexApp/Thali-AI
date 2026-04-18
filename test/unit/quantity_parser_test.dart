import 'package:flutter_test/flutter_test.dart';
import 'package:thali/services/quantity_parser.dart';

void main() {
  group('QuantityParser.parse — piece (countable)', () {
    test('"3 pieces" → 3, piece', () {
      final r = QuantityParser.parse('3 pieces');
      expect(r.count, 3);
      expect(r.unit, QuantityUnit.piece);
    });

    test('"1 piece" (singular) → 1, piece', () {
      final r = QuantityParser.parse('1 piece');
      expect(r.count, 1);
      expect(r.unit, QuantityUnit.piece);
    });

    test('"2 pcs" → 2, piece', () {
      final r = QuantityParser.parse('2 pcs');
      expect(r.count, 2);
      expect(r.unit, QuantityUnit.piece);
    });
  });

  group('QuantityParser.parse — volumetric', () {
    test('"1 bowl" → 1, bowl', () {
      final r = QuantityParser.parse('1 bowl');
      expect(r.count, 1);
      expect(r.unit, QuantityUnit.bowl);
    });

    test('"1 katori" → 1, bowl', () {
      final r = QuantityParser.parse('1 katori');
      expect(r.count, 1);
      expect(r.unit, QuantityUnit.bowl);
    });

    test('"½ plate" → 0.5, plate', () {
      final r = QuantityParser.parse('½ plate');
      expect(r.count, 0.5);
      expect(r.unit, QuantityUnit.plate);
    });

    test('"1 cup" → 1, cup', () {
      final r = QuantityParser.parse('1 cup');
      expect(r.unit, QuantityUnit.cup);
    });

    test('"1 glass" → 1, cup', () {
      final r = QuantityParser.parse('1 glass');
      expect(r.unit, QuantityUnit.cup);
    });

    test('"2 servings" → 2, serving', () {
      final r = QuantityParser.parse('2 servings');
      expect(r.count, 2);
      expect(r.unit, QuantityUnit.serving);
    });
  });

  group('QuantityParser.parse — small units', () {
    test('"2 tbsp" → 2, tbsp', () {
      final r = QuantityParser.parse('2 tbsp');
      expect(r.count, 2);
      expect(r.unit, QuantityUnit.tbsp);
    });

    test('"1 teaspoon" → 1, tsp', () {
      final r = QuantityParser.parse('1 teaspoon');
      expect(r.unit, QuantityUnit.tsp);
    });

    test('"200ml" → 200, ml', () {
      final r = QuantityParser.parse('200ml');
      expect(r.count, 200);
      expect(r.unit, QuantityUnit.ml);
    });

    test('"150 g" → 150, gram', () {
      final r = QuantityParser.parse('150 g');
      expect(r.count, 150);
      expect(r.unit, QuantityUnit.gram);
    });
  });

  group('QuantityParser.parse — fallback multiplier', () {
    test('empty string → 1, multiplier', () {
      final r = QuantityParser.parse('');
      expect(r.count, 1);
      expect(r.unit, QuantityUnit.multiplier);
    });

    test('unknown unit ("handful of namkeen") → still extracts count', () {
      final r = QuantityParser.parse('a big portion');
      expect(r.unit, QuantityUnit.serving);
    });

    test('gibberish → multiplier fallback', () {
      final r = QuantityParser.parse('xyz');
      expect(r.unit, QuantityUnit.multiplier);
      expect(r.count, 1);
    });
  });

  group('QuantityParser.unitFromString', () {
    test('recognizes canonical unit names (case-insensitive)', () {
      expect(QuantityParser.unitFromString('piece'), QuantityUnit.piece);
      expect(QuantityParser.unitFromString('PIECES'), QuantityUnit.piece);
      expect(QuantityParser.unitFromString('bowl'), QuantityUnit.bowl);
      expect(QuantityParser.unitFromString('katori'), QuantityUnit.bowl);
      expect(QuantityParser.unitFromString('tbsp'), QuantityUnit.tbsp);
      expect(QuantityParser.unitFromString('ml'), QuantityUnit.ml);
    });

    test('returns null for unknown/empty', () {
      expect(QuantityParser.unitFromString(null), isNull);
      expect(QuantityParser.unitFromString(''), isNull);
      expect(QuantityParser.unitFromString('handful'), isNull);
    });
  });

  group('QuantityParser.format', () {
    test('pieces pluralize', () {
      expect(QuantityParser.format(1, QuantityUnit.piece), '1 piece');
      expect(QuantityParser.format(3, QuantityUnit.piece), '3 pieces');
    });

    test('fractional pieces', () {
      expect(QuantityParser.format(0.5, QuantityUnit.piece), '0.5 pieces');
    });

    test('bowls / plates / cups pluralize', () {
      expect(QuantityParser.format(1, QuantityUnit.bowl), '1 bowl');
      expect(QuantityParser.format(2, QuantityUnit.bowl), '2 bowls');
      expect(QuantityParser.format(1, QuantityUnit.plate), '1 plate');
    });

    test('ml/g are compact', () {
      expect(QuantityParser.format(200, QuantityUnit.ml), '200ml');
      expect(QuantityParser.format(100, QuantityUnit.gram), '100g');
    });

    test('tbsp/tsp do not pluralize', () {
      expect(QuantityParser.format(1, QuantityUnit.tbsp), '1 tbsp');
      expect(QuantityParser.format(2, QuantityUnit.tbsp), '2 tbsp');
    });

    test('multiplier mode', () {
      expect(QuantityParser.format(1.5, QuantityUnit.multiplier), '1.5× portion');
    });
  });
}
