import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/animated_gradient_background.dart';

/// Pure visual splash. AuthGate displays this for [duration] before
/// running its connectivity + auth routing logic.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LogoMark()
                    .animate()
                    .scaleXY(
                      begin: 0.6,
                      end: 1,
                      duration: 600.ms,
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(duration: 500.ms),
                const SizedBox(height: 28),
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: AppColors.emeraldGradient,
                  ).createShader(rect),
                  child: const Text(
                    'Thali',
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1.8,
                      height: 1,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 700.ms, delay: 200.ms)
                    .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 12),
                Text(
                  'Indian food, smarter calories.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                    letterSpacing: 0.4,
                  ),
                ).animate().fadeIn(duration: 700.ms, delay: 450.ms),
                const SizedBox(height: 56),
                const _LoadingDots()
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 700.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.emeraldGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withValues(alpha: 0.45),
            blurRadius: 36,
            offset: const Offset(0, 14),
            spreadRadius: -6,
          ),
          BoxShadow(
            color: AppColors.cyan.withValues(alpha: 0.18),
            blurRadius: 48,
            offset: const Offset(0, 28),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: const Center(
        child: Text(
          '🍽️',
          style: TextStyle(fontSize: 56),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .fadeIn(duration: 400.ms, delay: (i * 150).ms)
              .then()
              .fadeOut(duration: 400.ms, delay: 200.ms),
        );
      }),
    );
  }
}
