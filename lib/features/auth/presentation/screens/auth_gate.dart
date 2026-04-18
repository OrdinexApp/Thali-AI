import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/providers.dart';
import '../../../shell/main_shell.dart';
import '../../../splash/presentation/screens/splash_screen.dart';
import 'no_internet_screen.dart';
import 'sign_in_screen.dart';

/// Routes the user to the right top-level screen based on (1) network and
/// (2) auth state. Shows a branded splash for a brief minimum duration so
/// the launch never flickers straight into the auth screen.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  static const Duration splashMinDuration = Duration(milliseconds: 1800);

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _splashDone = false;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(AuthGate.splashMinDuration, () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) return const SplashScreen();

    final connectivity = ref.watch(connectivityStatusProvider);
    final authState = ref.watch(authStateProvider);

    return connectivity.when(
      loading: () => const SplashScreen(),
      error: (_, __) => const NoInternetScreen(),
      data: (online) {
        if (!online) return const NoInternetScreen();

        return authState.when(
          loading: () => const SplashScreen(),
          error: (_, __) => const SignInScreen(),
          data: (state) {
            final session = state.session;
            if (session == null) return const SignInScreen();
            return const MainShell();
          },
        );
      },
    );
  }
}
