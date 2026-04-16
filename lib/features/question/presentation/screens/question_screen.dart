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
import '../../../../services/gemini_service.dart';
import '../../../../services/indian_food_db.dart';
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
                    const SizedBox(height: 12),
                    _buildApiStatusBanner(detectionState),
                    const SizedBox(height: 8),
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
                    _buildAnalyzeButton(detectionState).animate()
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
                        const Expanded(
                          child: Text(
                            'AI is detecting food items...',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ] else if (state.status == DetectionStatus.error) ...[
                        const Icon(Icons.cloud_off_rounded,
                            color: AppColors.warning, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'AI unavailable — add items manually',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w500,
                            ),
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

  /// Shows API status: success from Gemini, error with reason, or retry option
  Widget _buildApiStatusBanner(DetectionState state) {
    if (state.status == DetectionStatus.loading) {
      return const SizedBox.shrink();
    }

    if (state.status == DetectionStatus.error && state.error != null) {
      return GlassCard(
        padding: const EdgeInsets.all(14),
        borderRadius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final imagePath = ref.read(selectedImagePathProvider);
                      if (imagePath != null) {
                        ref.read(detectionProvider.notifier).detectItems(imagePath);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.cyan.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh_rounded,
                              color: AppColors.cyan, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Retry AI',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.cyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _showAddItemDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.emerald.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              color: AppColors.emerald, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Add Items',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
    }

    if (state.status == DetectionStatus.success && state.isFromApi) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.emerald.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.emerald.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: AppColors.emerald, size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Detected by Gemini AI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.emerald,
                ),
              ),
            ),
            GestureDetector(
              onTap: _showAddItemDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded,
                        color: AppColors.textSecondary, size: 14),
                    SizedBox(width: 3),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms);
    }

    return const SizedBox.shrink();
  }

  /// List of detected items below the image — tappable to edit
  Widget _buildDetectedItemsList(DetectionState state) {
    if (state.result == null || state.result!.items.isEmpty) {
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
                onLongPress: () => _confirmRemoveItem(i, item.name),
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

  void _confirmRemoveItem(int index, String name) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove $name?',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(detectionProvider.notifier).removeItem(index);
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    HapticFeedback.mediumImpact();
    final commonItems = IndianFoodDB.database.values.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AddItemSheet(
        commonItems: commonItems,
        onAdd: (name, quantity) {
          ref.read(detectionProvider.notifier).addItem(
            DetectedItem(
              name: name,
              estimatedQuantity: quantity,
              confirmed: true,
            ),
          );
        },
      ),
    );
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

  Widget _buildAnalyzeButton(DetectionState state) {
    final items = state.result?.items ?? [];
    final confirmedCount = items.where((i) => i.confirmed).length;
    final allConfirmed = items.isEmpty || confirmedCount == items.length;

    return Column(
      children: [
        NeonButton(
          text: allConfirmed ? 'Analyze Now' : 'Analyze Now ($confirmedCount/${items.length} confirmed)',
          icon: Icons.auto_awesome_rounded,
          onPressed: _onAnalyze,
        ),
        if (!allConfirmed && items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Tap items above to confirm cooking style',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }

  void _onAnalyze() {
    final detectionState = ref.read(detectionProvider);
    final items = detectionState.result?.items ?? [];
    final allConfirmed = items.isEmpty || items.every((i) => i.confirmed);

    if (!allConfirmed) {
      _showConfirmDialog();
      return;
    }

    _startAnalysis();
  }

  void _showConfirmDialog() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Unconfirmed Items',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Some items haven\'t been confirmed yet. Unconfirmed items will use default "Home" cooking style. Proceed anyway?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Go Back', style: TextStyle(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startAnalysis();
            },
            child: const Text(
              'Analyze Anyway',
              style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _startAnalysis() {
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

/// Bottom sheet for manually adding food items from the Indian food database
class _AddItemSheet extends StatefulWidget {
  final List<FoodNutrition> commonItems;
  final void Function(String name, String quantity) onAdd;

  const _AddItemSheet({required this.commonItems, required this.onAdd});

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  String _searchQuery = '';

  List<FoodNutrition> get _filtered {
    if (_searchQuery.isEmpty) return widget.commonItems;
    final q = _searchQuery.toLowerCase();
    return widget.commonItems
        .where((f) => f.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add Food Item',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search Indian dishes...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final food = _filtered[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.restaurant_rounded,
                        color: AppColors.emerald, size: 18),
                  ),
                  title: Text(
                    food.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '${food.calories.toInt()} kcal • ${food.portion}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  trailing: const Icon(Icons.add_circle_rounded,
                      color: AppColors.emerald, size: 24),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onAdd(food.name, food.portion);
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
