import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thali/main.dart';

void main() {
  testWidgets('App launches and shows Thali title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ThaliApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thali'), findsWidgets);
  });
}
