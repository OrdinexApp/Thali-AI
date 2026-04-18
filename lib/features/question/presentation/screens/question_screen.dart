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
import '../../../../services/quantity_parser.dart';
import '../widgets/annotated_food_image.dart';
import '../widgets/item_edit_sheet.dart';

// ─── Meal grouping ──────────────────────────────────────────────────────────

enum _MealCategory {
  mainDish('Main Dishes', Icons.dinner_dining_rounded),
  bread('Breads', Icons.grain_rounded),
  rice('Rice & Grains', Icons.rice_bowl_rounded),
  dairy('Raita & Dairy', Icons.local_drink_rounded),
  saladSide('Salads & Sides', Icons.eco_rounded),
  condiment('Chutneys & Condiments', Icons.water_drop_outlined),
  beverage('Beverages', Icons.local_cafe_rounded),
  dessert('Desserts', Icons.icecream_rounded),
  snack('Snacks', Icons.fastfood_rounded),
  other('Other Items', Icons.restaurant_rounded);

  final String label;
  final IconData icon;
  const _MealCategory(this.label, this.icon);
}

/// Maps an AI-returned category string to a display enum.
/// Falls back to [_MealCategory.mainDish] for unknown values.
_MealCategory _categoryFromAI(String aiCategory) {
  switch (aiCategory.toLowerCase().trim()) {
    case 'main_dish':
      return _MealCategory.mainDish;
    case 'bread':
      return _MealCategory.bread;
    case 'rice':
      return _MealCategory.rice;
    case 'dairy':
      return _MealCategory.dairy;
    case 'salad_side':
      return _MealCategory.saladSide;
    case 'condiment':
      return _MealCategory.condiment;
    case 'beverage':
      return _MealCategory.beverage;
    case 'dessert':
      return _MealCategory.dessert;
    case 'snack':
      return _MealCategory.snack;
    default:
      return _MealCategory.mainDish;
  }
}

/// Returns items indexed by their original flat-list position, grouped by
/// the AI-assigned [DetectedItem.category].  Category order follows enum order.
Map<_MealCategory, List<(int, DetectedItem)>> _groupItems(List<DetectedItem> items) {
  final result = {for (final c in _MealCategory.values) c: <(int, DetectedItem)>[]};
  for (var i = 0; i < items.length; i++) {
    result[_categoryFromAI(items[i].category)]!.add((i, items[i]));
  }
  return result;
}

class QuestionScreen extends ConsumerStatefulWidget {
  const QuestionScreen({super.key});

  @override
  ConsumerState<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends ConsumerState<QuestionScreen> {
  @override
  Widget build(BuildContext context) {
    final imagePath = ref.watch(selectedImagePathProvider);
    final detectionState = ref.watch(detectionProvider);

    return Scaffold(
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 16),
                          _buildAppBar().animate().fadeIn(duration: 400.ms),
                          const SizedBox(height: 20),
                          _buildImageSection(imagePath, detectionState),
                          const SizedBox(height: 12),
                          _buildApiStatusBanner(detectionState),
                          const SizedBox(height: 8),
                          _buildDetectedItemsList(detectionState),
                          // Bottom spacer so the sticky CTA never overlaps content
                          const SizedBox(height: 140),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: _buildStickyAnalyzeBar(detectionState),
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
        onItemLongPress: (index) => _decrementCount(index, detectionState),
        onEmptySpaceTap: (x, y) => _showAddItemDialog(x: x, y: y),
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
                            'Detecting food items...',
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
                            'Detection unavailable — add manually',
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

  /// Shows detection status banner
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
                            'Retry',
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
                'Items detected',
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

  /// Grouped detected items — each meal category as its own section
  Widget _buildDetectedItemsList(DetectionState state) {
    if (state.result == null || state.result!.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = state.result!.items;
    final confirmedCount = items.where((i) => i.confirmed).length;
    final allConfirmed = confirmedCount == items.length;
    final groups = _groupItems(items);
    final nonEmpty = groups.entries.where((e) => e.value.isNotEmpty).toList();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dinner_dining_rounded,
                    color: AppColors.emerald, size: 17),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meal Components',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'AI auto-filled — tap any item to correct',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: allConfirmed
                      ? AppColors.emerald.withValues(alpha: 0.15)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$confirmedCount/${items.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: allConfirmed ? AppColors.emerald : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Category sections ──────────────────────────────────────
          ...nonEmpty.map((entry) =>
              _buildGroupSection(entry.key, entry.value, state)),

          // ── Add item button ────────────────────────────────────────
          GestureDetector(
            onTap: _showAddItemDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.glassBorder.withValues(alpha: 0.5),
                    width: 0.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded,
                      color: AppColors.textTertiary, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Add Item',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 150.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildGroupSection(
    _MealCategory category,
    List<(int, DetectedItem)> indexedItems,
    DetectionState state,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Row(
              children: [
                Icon(category.icon,
                    size: 11, color: AppColors.textTertiary),
                const SizedBox(width: 5),
                Text(
                  category.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '(${indexedItems.length})',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          // Items container
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.glassBorder.withValues(alpha: 0.3),
                  width: 0.5),
            ),
            child: Column(
              children: indexedItems.asMap().entries.map((e) {
                final isLast = e.key == indexedItems.length - 1;
                final (origIdx, item) = e.value;
                return _buildItemRow(origIdx, item, isLast, state);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    int index,
    DetectedItem item,
    bool isLast,
    DetectionState state,
  ) {
    return GestureDetector(
      onTap: () => _showEditSheet(index, state),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: item.confirmed
              ? AppColors.emerald.withValues(alpha: 0.04)
              : Colors.transparent,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : BorderRadius.zero,
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: AppColors.glassBorder.withValues(alpha: 0.25),
                    width: 0.5,
                  ),
                ),
        ),
        child: Row(
          children: [
            // Confirmed indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: item.confirmed
                    ? AppColors.emerald.withValues(alpha: 0.15)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: item.confirmed
                      ? AppColors.emerald.withValues(alpha: 0.4)
                      : AppColors.glassBorder.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Icon(
                item.confirmed
                    ? Icons.check_rounded
                    : Icons.touch_app_rounded,
                size: 14,
                color: item.confirmed
                    ? AppColors.emerald
                    : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 10),

            // Name + cooking style
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: item.confirmed
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (item.confirmed) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.cookingStyle,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.cyan.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Quantity badge (tap = same edit sheet)
            GestureDetector(
              onTap: () => _showEditSheet(index, state),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.glassBorder.withValues(alpha: 0.5),
                      width: 0.5),
                ),
                child: Text(
                  item.estimatedQuantity,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Remove button
            GestureDetector(
              onTap: () => _removeWithUndo(index, item),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog({double? x, double? y}) {
    HapticFeedback.mediumImpact();
    final commonItems = IndianFoodDB.database.values.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AddItemSheet(
        commonItems: commonItems,
        onAdd: (name, quantity) {
          // Parse free-form qty → structured (count, unit) so the adaptive
          // edit sheet and calorie engine stay consistent with AI-detected
          // items. When a tap position was supplied (tap-to-add on image),
          // pin the new pill at that coordinate.
          final parsed = QuantityParser.parse(quantity);
          ref.read(detectionProvider.notifier).addItem(
                DetectedItem(
                  name: name,
                  estimatedQuantity: quantity,
                  confirmed: true,
                  count: parsed.count,
                  unit: parsed.unit,
                  x: x ?? 0.5,
                  y: y ?? 0.5,
                ),
              );
        },
      ),
    );
  }

  /// Long-press on a piece-unit pill decrements its count by one.
  /// When the count hits zero we remove the item entirely (with Undo).
  void _decrementCount(int index, DetectionState state) {
    if (state.result == null) return;
    final item = state.result!.items[index];
    if (item.unit != QuantityUnit.piece) return;

    final newCount = item.count - 1;
    if (newCount <= 0) {
      _removeWithUndo(index, item);
      return;
    }

    ref.read(detectionProvider.notifier).updateItem(
          index,
          item.copyWith(
            count: newCount,
            estimatedQuantity: QuantityParser.format(newCount, item.unit),
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

  void _removeWithUndo(int index, DetectedItem item) {
    HapticFeedback.mediumImpact();
    ref.read(detectionProvider.notifier).removeItem(index);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${item.name} removed',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        backgroundColor: AppColors.surfaceLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.emerald,
          onPressed: () {
            ref.read(detectionProvider.notifier).addItem(item);
          },
        ),
      ),
    );
  }

  /// Sticky bottom bar with contextual CTA that reflects detection state.
  /// - Loading:       "Detecting items…" (disabled)
  /// - No items:      "Add items to continue" (disabled)
  /// - All confirmed: gradient "Analyze Now" (active, with item count)
  /// - Some pending:  "Confirm X more items" (disabled, amber)
  Widget _buildStickyAnalyzeBar(DetectionState state) {
    final items = state.result?.items ?? [];
    final confirmedCount = items.where((i) => i.confirmed).length;
    final pendingCount = items.length - confirmedCount;
    final isLoading = state.status == DetectionStatus.loading;
    final hasItems = items.isNotEmpty;
    final allConfirmed = hasItems && pendingCount == 0;

    String label;
    String? subtitle;
    bool enabled;

    if (isLoading) {
      label = 'Detecting items…';
      subtitle = null;
      enabled = false;
    } else if (!hasItems) {
      label = 'Add items to continue';
      subtitle = 'No items detected yet';
      enabled = false;
    } else if (!allConfirmed) {
      label = pendingCount == 1
          ? 'Confirm 1 more item'
          : 'Confirm $pendingCount more items';
      subtitle = 'Tap items above to review';
      enabled = false;
    } else {
      label = 'Analyze Now';
      subtitle = '${items.length} ${items.length == 1 ? 'item' : 'items'} ready';
      enabled = true;
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: AppColors.glassBorder.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subtitle != null) ...[
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: enabled
                          ? AppColors.emerald
                          : AppColors.textTertiary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                enabled
                    ? NeonButton(
                        text: label,
                        icon: Icons.auto_awesome_rounded,
                        onPressed: _startAnalysis,
                      )
                    : _buildDisabledCta(label, isLoading),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisabledCta(String label, bool isLoading) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textTertiary.withValues(alpha: 0.8),
              ),
            )
          else
            const Icon(Icons.touch_app_rounded,
                color: AppColors.textTertiary, size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  void _startAnalysis() {
    HapticFeedback.heavyImpact();
    final imagePath = ref.read(selectedImagePathProvider);
    final detectionState = ref.read(detectionProvider);

    if (imagePath != null) {
      ref.read(analysisProvider.notifier).analyzeImage(
            imagePath: imagePath,
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
