import 'package:flutter_test/flutter_test.dart';
import 'package:thali/services/gemini_service.dart';
import 'package:thali/services/quantity_parser.dart';

DetectedItem _item(String name, String category) {
  return DetectedItem(
    name: name,
    estimatedQuantity: '1 serving',
    category: category,
    unit: QuantityUnit.serving,
  );
}

void main() {
  group('VerificationGate.shouldVerify', () {
    test('returns false when the first-pass list is empty', () {
      expect(VerificationGate.shouldVerify(const []), isFalse,
          reason: 'Nothing to verify against — the verification pass needs '
              'an initial list to compare.');
    });

    test(
        'returns false on a dense plate (>= 8 items) regardless of category mix',
        () {
      final items = [
        _item('Paneer Curry', 'main_dish'),
        _item('Mutton Curry', 'main_dish'),
        _item('Dal Makhani', 'main_dish'),
        _item('Palak Paneer', 'main_dish'),
        _item('Chicken Curry', 'main_dish'),
        _item('Naan', 'bread'),
        _item('Steamed Rice', 'rice'),
        _item('Raita', 'dairy'),
      ];
      expect(VerificationGate.shouldVerify(items), isFalse,
          reason: 'Dense plates have diminishing returns vs. hallucination '
              'risk — we trust the first pass above 8 items.');
    });

    test(
        'returns false for a complete thali: mains + bread + condiment/side',
        () {
      final items = [
        _item('Dal Tadka', 'main_dish'),
        _item('Naan', 'bread'),
        _item('Pickle', 'condiment'),
      ];
      expect(VerificationGate.shouldVerify(items), isFalse,
          reason: 'Structurally diverse plate — mains + carb + small side '
              'is unlikely to hide another item worth hallucinating over.');
    });

    test('returns false for main + rice + salad_side', () {
      final items = [
        _item('Rajma', 'main_dish'),
        _item('Steamed Rice', 'rice'),
        _item('Kachumber', 'salad_side'),
      ];
      expect(VerificationGate.shouldVerify(items), isFalse);
    });

    test('returns false for main + bread + dairy', () {
      final items = [
        _item('Paneer Butter Masala', 'main_dish'),
        _item('Roti', 'bread'),
        _item('Raita', 'dairy'),
      ];
      expect(VerificationGate.shouldVerify(items), isFalse);
    });

    test(
        'returns false when 4+ mains and bread are present (classic full thali)',
        () {
      final items = [
        _item('Paneer Curry', 'main_dish'),
        _item('Mutton Curry', 'main_dish'),
        _item('Dal Makhani', 'main_dish'),
        _item('Palak Paneer', 'main_dish'),
        _item('Naan', 'bread'),
      ];
      expect(VerificationGate.shouldVerify(items), isFalse,
          reason: 'Reproduces the screenshot case — 5 mains + naan — where '
              'verification previously hallucinated rice and onion.');
    });

    test('returns false when 4+ mains and rice are present', () {
      final items = [
        _item('Paneer Curry', 'main_dish'),
        _item('Mutton Curry', 'main_dish'),
        _item('Dal Makhani', 'main_dish'),
        _item('Palak Paneer', 'main_dish'),
        _item('Steamed Rice', 'rice'),
      ];
      expect(VerificationGate.shouldVerify(items), isFalse);
    });

    test('returns TRUE when mains present but no bread, rice, or small side',
        () {
      final items = [
        _item('Paneer Curry', 'main_dish'),
        _item('Dal Tadka', 'main_dish'),
      ];
      expect(VerificationGate.shouldVerify(items), isTrue,
          reason: 'Classic miss pattern — mains detected but no condiment/'
              'papad/pickle. Genuinely worth a second look.');
    });

    test('returns TRUE for a sparse plate of just mains + bread (no side)',
        () {
      final items = [
        _item('Dal Tadka', 'main_dish'),
        _item('Roti', 'bread'),
      ];
      expect(VerificationGate.shouldVerify(items), isTrue,
          reason: 'Missing condiment/side is a common real miss (papad, '
              'pickle, lemon wedge).');
    });

    test('returns TRUE for a plate of just 3 mains (no carb, no side)', () {
      final items = [
        _item('Paneer Curry', 'main_dish'),
        _item('Chicken Curry', 'main_dish'),
        _item('Dal Makhani', 'main_dish'),
      ];
      expect(VerificationGate.shouldVerify(items), isTrue);
    });

    test('returns TRUE for a single-item result', () {
      final items = [_item('Idli', 'main_dish')];
      expect(VerificationGate.shouldVerify(items), isTrue,
          reason: 'Tiny first-pass result — most likely the model undershot.');
    });

    test('is case-insensitive about category strings from the model', () {
      final items = [
        _item('Dal', 'MAIN_DISH'),
        _item('Roti', 'Bread'),
        _item('Pickle', 'Condiment'),
      ];
      expect(VerificationGate.shouldVerify(items), isFalse,
          reason: 'Gate should tolerate upstream case variation in category.');
    });

    test('tolerates whitespace around category strings', () {
      final items = [
        _item('Dal', '  main_dish  '),
        _item('Roti', ' bread '),
        _item('Pickle', 'condiment'),
      ];
      expect(VerificationGate.shouldVerify(items), isFalse);
    });

    test('does NOT treat beverage/dessert/snack as a "small side" for the '
        'diversity check', () {
      final items = [
        _item('Paneer Curry', 'main_dish'),
        _item('Naan', 'bread'),
        _item('Gulab Jamun', 'dessert'),
      ];
      expect(VerificationGate.shouldVerify(items), isTrue,
          reason: 'A dessert does not substitute for the papad/pickle/raita '
              'that is the usual miss. Still worth verifying.');
    });

    test('fires when 3 mains exist but bread/rice is missing', () {
      final items = [
        _item('Paneer Curry', 'main_dish'),
        _item('Dal Makhani', 'main_dish'),
        _item('Mutton Curry', 'main_dish'),
        _item('Pickle', 'condiment'),
      ];
      expect(VerificationGate.shouldVerify(items), isTrue,
          reason: 'Has a small side but no carb — a roti/rice could easily '
              'be in the frame yet missed by the first pass.');
    });
  });
}
