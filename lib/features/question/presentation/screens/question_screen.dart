import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/neon_button.dart';
import '../../../../services/providers.dart';

class QuestionScreen extends ConsumerStatefulWidget {
  const QuestionScreen({super.key});

  @override
  ConsumerState<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends ConsumerState<QuestionScreen> {
  @override
  Widget build(BuildContext context) {
    final imagePath = ref.watch(selectedImagePathProvider);
    final rotiCount = ref.watch(rotiCountProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildAppBar()
                    .animate()
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: 24),
                _buildImagePreview(imagePath, size)
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 100.ms)
                    .slideY(begin: 0.1, end: 0),
                const SizedBox(height: 32),
                _buildQuestion()
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 200.ms)
                    .slideY(begin: 0.1, end: 0),
                const SizedBox(height: 24),
                _buildRotiSelector(rotiCount)
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 300.ms)
                    .scale(begin: const Offset(0.9, 0.9)),
                const Spacer(),
                NeonButton(
                  text: 'Analyze Now',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: _onAnalyze,
                ).animate()
                    .fadeIn(duration: 600.ms, delay: 400.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: GlassCard(
            padding: const EdgeInsets.all(10),
            borderRadius: 12,
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
        ),
        const Spacer(),
        const Text(
          'Meal Details',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        const SizedBox(width: 42),
      ],
    );
  }

  Widget _buildImagePreview(String? imagePath, Size size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: size.height * 0.25,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: imagePath != null
                ? Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                  )
                : const Center(
                    child: Icon(
                      Icons.image_rounded,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                  ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.emerald,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Photo captured successfully',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: AppColors.emeraldGradient,
          ).createShader(bounds),
          child: const Text(
            'How many rotis\ndid you have?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This helps us calculate your total\ncalorie intake accurately',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textTertiary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRotiSelector(int rotiCount) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCountButton(
            icon: Icons.remove_rounded,
            onTap: () {
              HapticFeedback.selectionClick();
              if (rotiCount > 0) {
                ref.read(rotiCountProvider.notifier).state = rotiCount - 1;
              }
            },
            enabled: rotiCount > 0,
          ),
          Column(
            children: [
              Text(
                '$rotiCount',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: AppColors.emerald,
                  height: 1,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                rotiCount == 1 ? 'Roti' : 'Rotis',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          _buildCountButton(
            icon: Icons.add_rounded,
            onTap: () {
              HapticFeedback.selectionClick();
              if (rotiCount < 10) {
                ref.read(rotiCountProvider.notifier).state = rotiCount + 1;
              }
            },
            enabled: rotiCount < 10,
          ),
        ],
      ),
    );
  }

  Widget _buildCountButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.emerald.withValues(alpha: 0.15)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? AppColors.emerald.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.emerald : AppColors.textTertiary,
          size: 28,
        ),
      ),
    );
  }

  void _onAnalyze() {
    HapticFeedback.heavyImpact();
    final imagePath = ref.read(selectedImagePathProvider);
    final rotiCount = ref.read(rotiCountProvider);

    if (imagePath != null) {
      ref.read(analysisProvider.notifier).analyzeImage(
            imagePath: imagePath,
            rotiCount: rotiCount,
          );
      Navigator.pushNamed(context, '/results');
    }
  }
}
