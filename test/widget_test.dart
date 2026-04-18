import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thali/main.dart';

void main() {
  testWidgets('App launches and shows Thali title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ThaliApp()),
    );
    // Use pump with a duration instead of pumpAndSettle because
    // AnimatedGradientBackground uses a repeat() animation that never settles.
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Thali'), findsWidgets);
  });
}
