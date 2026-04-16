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
import '../widgets/annotated_food_image.dart';
import '../widgets/item_edit_sheet.dart';

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
    final detectionState = ref.watch(detectionProvider);

    return Scaffold(
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 16),
                    _buildAppBar()
                        .animate()
                        .fadeIn(duration: 400.ms),
                    const SizedBox(height: 20),
                    _buildImageSection(imagePath, detectionState),
                    const SizedBox(height: 20),
                    _buildDetectedItemsList(detectionState),
                    const SizedBox(height: 28),
                    _buildQuestion()
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 200.ms)
                        .slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 20),
                    _buildRotiSelector(rotiCount)
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 300.ms)
                        .scale(begin: const Offset(0.9, 0.9)),
                    const SizedBox(height: 36),
                    NeonButton(
                      text: 'Analyze Now',
                      icon: Icons.auto_awesome_rounded,
                      onPressed: _onAnalyze,
                    ).animate()
                        .fadeIn(duration: 600.ms, delay: 400.ms)
                        .slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
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

  /// Shows annotated image with labels when detection is done, plain image otherwise
  Widget _buildImageSection(String? imagePath, DetectionState detectionState) {
    if (imagePath == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: Icon(Icons.image_rounded, size: 48, color: AppColors.textTertiary),
        ),
      );
    }

    // Show annotated image when items are detected
    if (detectionState.status == DetectionStatus.success &&
        detectionState.result != null &&
        detectionState.result!.items.isNotEmpty) {
      return AnnotatedFoodImage(
        imagePath: imagePath,
        items: detectionState.result!.items,
        onItemTap: (index) => _showEditSheet(index, detectionState),
      ).animate()
          .fadeIn(duration: 600.ms, delay: 100.ms)
          .slideY(begin: 0.1, end: 0);
    }

    // Plain image with loading/status overlay
    return _buildPlainImagePreview(imagePath, detectionState)
        .animate()
        .fadeIn(duration: 600.ms, delay: 100.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildPlainImagePreview(String imagePath, DetectionState state) {
    final size = MediaQuery.of(context).size;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: size.height * 0.28,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Image.file(File(imagePath), fit: BoxFit.cover),
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
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  child: Row(
                    children: [
                      if (state.status == DetectionStatus.loading) ...[
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.emerald.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'AI is detecting food items...',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.emerald, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Photo captured successfully',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

  /// List of detected items below the image — tappable to edit
  Widget _buildDetectedItemsList(DetectionState state) {
    if (state.status != DetectionStatus.success ||
        state.result == null ||
        state.result!.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = state.result!.items;
    final confirmedCount = items.where((i) => i.confirmed).length;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.touch_app_rounded,
                    color: AppColors.emerald, size: 15),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Tap items to confirm details',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: confirmedCount == items.length
                      ? AppColors.emerald.withValues(alpha: 0.15)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$confirmedCount/${items.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: confirmedCount == items.length
                        ? AppColors.emerald
                        : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(items.length, (i) {
              final item = items[i];
              return GestureDetector(
                onTap: () => _showEditSheet(i, state),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: item.confirmed
                        ? AppColors.emerald.withValues(alpha: 0.12)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: item.confirmed
                          ? AppColors.emerald.withValues(alpha: 0.5)
                          : AppColors.glassBorder,
                      width: item.confirmed ? 1.2 : 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.confirmed
                            ? Icons.check_circle_rounded
                            : Icons.restaurant_rounded,
                        color: item.confirmed
                            ? AppColors.emerald
                            : AppColors.textTertiary,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: item.confirmed
                              ? AppColors.emerald
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (item.confirmed) ...[
                        const SizedBox(width: 6),
                        Text(
                          item.cookingStyle,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.cyan.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    ).animate()
        .fadeIn(duration: 500.ms, delay: 150.ms)
        .slideY(begin: 0.05, end: 0);
  }

  void _showEditSheet(int index, DetectionState state) {
    if (state.result == null) return;
    final item = state.result!.items[index];

    ItemEditSheet.show(
      context,
      item: item,
      onConfirm: (updated) {
        ref.read(detectionProvider.notifier).updateItem(index, updated);
      },
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
    final detectionState = ref.read(detectionProvider);

    if (imagePath != null) {
      ref.read(analysisProvider.notifier).analyzeImage(
            imagePath: imagePath,
            rotiCount: rotiCount,
            detectedItems: detectionState.result,
          );
      Navigator.pushNamed(context, '/results');
    }
  }
}
