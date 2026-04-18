import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thali/features/auth/presentation/screens/sign_in_screen.dart';

/// Lightweight smoke test that doesn't depend on a live Supabase client.
/// The full AuthGate flow (connectivity + auth state) is covered by
/// integration tests; this just makes sure the brand surfaces correctly.
void main() {
  testWidgets('SignInScreen renders the Thali brand', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SignInScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Thali'), findsWidgets);
    expect(find.text('Sign in'), findsWidgets);
  });
}
