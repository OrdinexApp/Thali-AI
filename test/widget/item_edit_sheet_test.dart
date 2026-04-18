import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thali/core/constants/app_colors.dart';
import 'package:thali/features/question/presentation/widgets/item_edit_sheet.dart';
import 'package:thali/services/gemini_service.dart';
import 'package:thali/services/quantity_parser.dart';

// Helper to wrap the sheet in a material app so tests can pump it.
Widget _wrapSheet(DetectedItem item, {void Function(DetectedItem)? onConfirm}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      backgroundColor: AppColors.background,
      body: Builder(
        builder: (ctx) => Center(
          child: ElevatedButton(
            onPressed: () => ItemEditSheet.show(ctx, item: item, onConfirm: onConfirm ?? (_) {}),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

/// The adaptive sheet is taller than the default 800×600 test surface.
/// Set a phone-sized surface so Confirm Item + PORTION row stay on-screen.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 1000));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

void main() {
  group('ItemEditSheet — basic rendering', () {
    testWidgets('shows item name in header', (tester) async {
      final item = DetectedItem(name: 'Idli', estimatedQuantity: '3 pieces', category: 'main_dish');
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Idli'), findsWidgets);
    });

    testWidgets('shows "Tap to edit name" hint', (tester) async {
      final item = DetectedItem(name: 'Sambar', estimatedQuantity: '1 bowl', category: 'main_dish');
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Tap to edit name'), findsOneWidget);
    });

    testWidgets('shows Confirm Item button', (tester) async {
      final item = DetectedItem(name: 'Roti', estimatedQuantity: '2 pieces', category: 'bread');
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Item'), findsOneWidget);
    });

    testWidgets('shows QUANTITY section label', (tester) async {
      final item = DetectedItem(name: 'Rice', estimatedQuantity: '1 plate', category: 'rice');
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('QUANTITY'), findsOneWidget);
    });
  });

  group('ItemEditSheet — cooking style visibility', () {
    testWidgets('shows COOKING STYLE for main_dish', (tester) async {
      final item = DetectedItem(name: 'Dal Tadka', estimatedQuantity: '1 bowl', category: 'main_dish');
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('COOKING STYLE'), findsOneWidget);
    });

    testWidgets('hides COOKING STYLE for condiment', (tester) async {
      final item = DetectedItem(name: 'Mint Chutney', estimatedQuantity: '1 tbsp', category: 'condiment');
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('COOKING STYLE'), findsNothing);
    });

    testWidgets('hides COOKING STYLE for beverage', (tester) async {
      final item = DetectedItem(name: 'Chai', estimatedQuantity: '1 cup', category: 'beverage');
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('COOKING STYLE'), findsNothing);
    });

    testWidgets('hides COOKING STYLE for dessert', (tester) async {
      final item = DetectedItem(name: 'Gulab Jamun', estimatedQuantity: '2 pieces', category: 'dessert');
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('COOKING STYLE'), findsNothing);
    });
  });

  group('ItemEditSheet — adaptive primary control', () {
    testWidgets('piece unit renders big stepper with current count', (tester) async {
      final item = DetectedItem(
        name: 'Idli',
        estimatedQuantity: '3 pieces',
        category: 'main_dish',
        unit: QuantityUnit.piece,
        count: 3,
      );
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Stepper shows "3" and "pieces"
      expect(find.text('3'), findsWidgets);
      expect(find.text('pieces'), findsOneWidget);
      // Plus and minus stepper icons are rendered
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
    });

    testWidgets('piece stepper shows AI-count hint when count > 1', (tester) async {
      final item = DetectedItem(
        name: 'Vada',
        estimatedQuantity: '3 pieces',
        category: 'main_dish',
        unit: QuantityUnit.piece,
        count: 3,
      );
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('AI saw 3'), findsOneWidget);
    });

    testWidgets('tapping + on the stepper increments and confirms new count', (tester) async {
      await _useTallSurface(tester);
      DetectedItem? result;
      final item = DetectedItem(
        name: 'Idli',
        estimatedQuantity: '3 pieces',
        unit: QuantityUnit.piece,
        count: 3,
      );
      await tester.pumpWidget(_wrapSheet(item, onConfirm: (u) => result = u));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      await tester.ensureVisible(find.text('Confirm Item'));
      await tester.tap(find.text('Confirm Item'));
      await tester.pumpAndSettle();

      expect(result?.count, 4);
      expect(result?.unit, QuantityUnit.piece);
      expect(result?.estimatedQuantity, '4 pieces');
    });

    testWidgets('tapping − at count=1 is disabled (count stays at 1)', (tester) async {
      await _useTallSurface(tester);
      DetectedItem? result;
      final item = DetectedItem(
        name: 'Idli',
        estimatedQuantity: '1 piece',
        unit: QuantityUnit.piece,
        count: 1,
      );
      await tester.pumpWidget(_wrapSheet(item, onConfirm: (u) => result = u));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      await tester.ensureVisible(find.text('Confirm Item'));
      await tester.tap(find.text('Confirm Item'));
      await tester.pumpAndSettle();

      expect(result?.count, 1);
    });

    testWidgets('bowl unit shows bowl preset chips (not pieces)', (tester) async {
      final item = DetectedItem(
        name: 'Sambar',
        estimatedQuantity: '1 bowl',
        category: 'main_dish',
        unit: QuantityUnit.bowl,
        count: 1,
      );
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('1 bowl'), findsWidgets);
      expect(find.text('1 big bowl'), findsOneWidget);
      expect(find.text('pieces'), findsNothing);
    });

    testWidgets('tbsp unit shows tbsp preset chips', (tester) async {
      final item = DetectedItem(
        name: 'Chutney',
        estimatedQuantity: '1 tbsp',
        category: 'condiment',
        unit: QuantityUnit.tbsp,
        count: 1,
      );
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('1 tbsp'), findsWidgets);
      expect(find.text('2 tbsp'), findsOneWidget);
    });

    testWidgets('plate unit shows plate fraction chips', (tester) async {
      final item = DetectedItem(
        name: 'Rice',
        estimatedQuantity: '1 plate',
        category: 'rice',
        unit: QuantityUnit.plate,
        count: 1,
      );
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('¼ plate'), findsOneWidget);
      expect(find.text('½ plate'), findsOneWidget);
    });

    testWidgets('multiplier unit shows fallback copy (no preset chips)', (tester) async {
      final item = DetectedItem(
        name: 'Mystery dish',
        estimatedQuantity: 'some portion',
        unit: QuantityUnit.multiplier,
        count: 1,
      );
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining("couldn't figure out"), findsOneWidget);
    });
  });

  group('ItemEditSheet — universal portion multiplier', () {
    testWidgets('PORTION section is always visible', (tester) async {
      final item = DetectedItem(
        name: 'Idli',
        estimatedQuantity: '2 pieces',
        unit: QuantityUnit.piece,
        count: 2,
      );
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('PORTION'), findsOneWidget);
      expect(find.text('0.5×'), findsOneWidget);
      expect(find.text('1×'), findsOneWidget);
      expect(find.text('2×'), findsOneWidget);
    });

    testWidgets('selecting 2× multiplier doubles the confirmed count', (tester) async {
      await _useTallSurface(tester);
      DetectedItem? result;
      final item = DetectedItem(
        name: 'Idli',
        estimatedQuantity: '2 pieces',
        unit: QuantityUnit.piece,
        count: 2,
      );
      await tester.pumpWidget(_wrapSheet(item, onConfirm: (u) => result = u));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('2×'));
      await tester.pump();
      await tester.ensureVisible(find.text('Confirm Item'));
      await tester.tap(find.text('Confirm Item'));
      await tester.pumpAndSettle();

      expect(result?.count, 4);
      expect(result?.estimatedQuantity, contains('2×'));
    });
  });

  group('ItemEditSheet — name editing', () {
    testWidgets('tapping "Tap to edit name" shows a text field', (tester) async {
      final item = DetectedItem(name: 'Tomato Chutney', estimatedQuantity: '1 tbsp', category: 'condiment');
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tap to edit name'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('editing name and confirming passes updated name to callback', (tester) async {
      String? confirmedName;
      final item = DetectedItem(name: 'Tomato Chutney', estimatedQuantity: '1 tbsp', category: 'condiment');

      await tester.pumpWidget(_wrapSheet(item, onConfirm: (updated) {
        confirmedName = updated.name;
      }));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.text('Tap to edit name'));
      await tester.pumpAndSettle();

      // Clear and type new name
      final nameField = find.byType(TextField).first;
      await tester.tap(nameField);
      await tester.pump();
      await tester.enterText(nameField, 'Green Garlic Chutney');
      await tester.pump();

      // Tap the checkmark to finish editing
      await tester.tap(find.byIcon(Icons.check_rounded).first);
      await tester.pumpAndSettle();

      // Confirm item
      await tester.tap(find.text('Confirm Item'));
      await tester.pumpAndSettle();

      expect(confirmedName, 'Green Garlic Chutney');
    });
  });

  group('ItemEditSheet — custom quantity input', () {
    testWidgets('custom quantity field exists', (tester) async {
      final item = DetectedItem(name: 'Idli', estimatedQuantity: '3 pieces', category: 'main_dish');
      await tester.pumpWidget(_wrapSheet(item));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is TextField && (w.decoration?.hintText?.contains('custom') ?? false)),
        findsOneWidget,
      );
    });

    testWidgets('typing a custom quantity passes it to callback', (tester) async {
      String? confirmedQty;
      final item = DetectedItem(name: 'Idli', estimatedQuantity: '3 pieces', category: 'main_dish');

      await tester.pumpWidget(_wrapSheet(item, onConfirm: (u) => confirmedQty = u.estimatedQuantity));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Find the custom quantity hint field
      final customField = find.byWidgetPredicate(
        (w) => w is TextField && (w.decoration?.hintText?.contains('custom') ?? false),
      );
      await tester.enterText(customField, '8 pieces');
      await tester.pump();

      await tester.tap(find.text('Confirm Item'));
      await tester.pumpAndSettle();

      expect(confirmedQty, '8 pieces');
    });
  });

  group('ItemEditSheet — confirm passes correct data', () {
    testWidgets('confirms with original values if nothing changed', (tester) async {
      DetectedItem? result;
      final item = DetectedItem(
        name: 'Dal Makhani',
        estimatedQuantity: '1 bowl',
        category: 'main_dish',
        cookingStyle: 'Restaurant',
      );

      await tester.pumpWidget(_wrapSheet(item, onConfirm: (u) => result = u));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Item'));
      await tester.pumpAndSettle();

      expect(result?.name, 'Dal Makhani');
      expect(result?.confirmed, true);
    });

    testWidgets('confirms as confirmed=true', (tester) async {
      bool? wasConfirmed;
      final item = DetectedItem(name: 'Roti', estimatedQuantity: '2 pieces', category: 'bread');

      await tester.pumpWidget(_wrapSheet(item, onConfirm: (u) => wasConfirmed = u.confirmed));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Item'));
      await tester.pumpAndSettle();

      expect(wasConfirmed, true);
    });
  });
}
