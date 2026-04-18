import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../services/providers.dart';

class NoInternetScreen extends ConsumerWidget {
  const NoInternetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GlassCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 56,
                      color: AppColors.cyan,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No internet connection',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Thali needs the internet to analyse meals and sync your '
                      'history. Please connect to Wi-Fi or mobile data and try '
                      'again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    NeonButton(
                      text: 'Try again',
                      icon: Icons.refresh_rounded,
                      onPressed: () =>
                          ref.invalidate(connectivityStatusProvider),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
