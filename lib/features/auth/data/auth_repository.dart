import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_service.dart';

class AuthRepository {
  AuthRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: displayName != null && displayName.isNotEmpty
          ? {'display_name': displayName}
          : null,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Sends a password-reset email. The user clicks the link in the email
  /// and is taken to Supabase's hosted reset flow.
  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(email.trim());
  }
}
