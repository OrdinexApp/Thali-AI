import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../services/gemini_service.dart';

class ItemEditSheet extends StatefulWidget {
  final DetectedItem item;
  final void Function(DetectedItem updated) onConfirm;

  const ItemEditSheet({
    super.key,
    required this.item,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required DetectedItem item,
    required void Function(DetectedItem updated) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemEditSheet(item: item, onConfirm: onConfirm),
    );
  }

  @override
  State<ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends State<ItemEditSheet> {
  late String _quantity;
  late String _cookingStyle;

  static const _cookingStyles = [
    _StyleOption('Home', Icons.home_rounded, 'Normal homemade'),
    _StyleOption('Restaurant', Icons.restaurant_rounded, 'Rich, more butter/oil'),
    _StyleOption('Less Oil', Icons.water_drop_outlined, 'Light preparation'),
    _StyleOption('Diet', Icons.eco_rounded, 'Minimal oil, steamed'),
  ];

  static const _commonQuantities = [
    '1 small bowl',
    '1 bowl',
    '1 big bowl',
    '1 cup',
    '1 serving',
    '1 piece',
    '2 pieces',
    '3 pieces',
    '1 plate',
    '1 tbsp',
  ];

  @override
  void initState() {
    super.initState();
    _quantity = widget.item.estimatedQuantity;
    _cookingStyle = widget.item.cookingStyle;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPad),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.95),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: const Border(
              top: BorderSide(color: AppColors.glassBorder, width: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Item name header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: AppColors.emeraldGradient),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.restaurant_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Confirm quantity & cooking style',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quantity section
              const Text(
                'QUANTITY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonQuantities.map((q) {
                  final selected = _quantity == q;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _quantity = q);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.emerald.withValues(alpha: 0.15)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.emerald
                              : AppColors.glassBorder,
                          width: selected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Text(
                        q,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? AppColors.emerald
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Cooking style section
              const Text(
                'COOKING STYLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: _cookingStyles.map((style) {
                  final selected = _cookingStyle == style.label;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _cookingStyle = style.label);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(
                          right:
                              style.label != _cookingStyles.last.label ? 8 : 0,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.emerald.withValues(alpha: 0.12)
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.emerald
                                : AppColors.glassBorder,
                            width: selected ? 1.5 : 0.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              style.icon,
                              size: 22,
                              color: selected
                                  ? AppColors.emerald
                                  : AppColors.textTertiary,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              style.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? AppColors.emerald
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              // Subtitle for selected style
              Center(
                child: Text(
                  _cookingStyles
                      .firstWhere((s) => s.label == _cookingStyle)
                      .description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Confirm button
              GestureDetector(
                onTap: _onConfirm,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: AppColors.emeraldGradient),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emerald.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_rounded, color: Colors.black, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Confirm Item',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onConfirm() {
    HapticFeedback.heavyImpact();
    widget.onConfirm(
      widget.item.copyWith(
        estimatedQuantity: _quantity,
        cookingStyle: _cookingStyle,
        confirmed: true,
      ),
    );
    Navigator.pop(context);
  }
}

class _StyleOption {
  final String label;
  final IconData icon;
  final String description;

  const _StyleOption(this.label, this.icon, this.description);
}
