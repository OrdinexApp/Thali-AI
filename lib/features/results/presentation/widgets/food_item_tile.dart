import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../features/history/data/models/meal_model.dart';

class FoodItemTile extends StatelessWidget {
  final FoodItem item;

  const FoodItemTile({super.key, required this.item});

  IconData _getFoodIcon() {
    final name = item.name.toLowerCase();
    if (name.contains('roti') || name.contains('chapati') || name.contains('naan')) {
      return Icons.bakery_dining_rounded;
    }
    if (name.contains('rice') || name.contains('biryani') || name.contains('pulao')) {
      return Icons.rice_bowl_rounded;
    }
    if (name.contains('dal') || name.contains('sambar') || name.contains('soup')) {
      return Icons.soup_kitchen_rounded;
    }
    if (name.contains('raita') || name.contains('curd') || name.contains('yogurt')) {
      return Icons.water_drop_rounded;
    }
    if (name.contains('pickle') || name.contains('chutney') || name.contains('papad')) {
      return Icons.emoji_food_beverage_rounded;
    }
    if (name.contains('salad') || name.contains('vegetable')) {
      return Icons.eco_rounded;
    }
    if (name.contains('chicken') || name.contains('mutton') || name.contains('fish') ||
        name.contains('egg') || name.contains('keema')) {
      return Icons.set_meal_rounded;
    }
    if (name.contains('paneer')) {
      return Icons.lunch_dining_rounded;
    }
    return Icons.restaurant_rounded;
  }

  Color _getStyleColor(String? style) {
    switch (style) {
      case 'Restaurant':
        return AppColors.warning;
      case 'Less Oil':
        return AppColors.neonGreen;
      case 'Diet':
        return AppColors.cyan;
      default:
        return AppColors.emerald;
    }
  }

  IconData _getStyleIcon(String? style) {
    switch (style) {
      case 'Restaurant':
        return Icons.storefront_rounded;
      case 'Less Oil':
        return Icons.water_drop_outlined;
      case 'Diet':
        return Icons.spa_rounded;
      default:
        return Icons.home_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final styleColor = _getStyleColor(item.cookingStyle);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        borderRadius: 20,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.emerald.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(
                    _getFoodIcon(),
                    color: AppColors.emerald.withValues(alpha: 0.95),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (item.portion != null) ...[
                            Text(
                              item.portion!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                          if (item.cookingStyle != null) ...[
                            if (item.portion != null)
                              const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: styleColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getStyleIcon(item.cookingStyle),
                                      size: 10, color: styleColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    item.cookingStyle!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: styleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.calories.toInt()}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: AppColors.emerald.withValues(alpha: 0.98),
                      ),
                    ),
                    Text(
                      'kcal',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMicroMacro('P', item.protein, AppColors.cyan),
                const SizedBox(width: 8),
                _buildMicroMacro('C', item.carbs, AppColors.warning),
                const SizedBox(width: 8),
                _buildMicroMacro('F', item.fat, AppColors.error),
                const SizedBox(width: 8),
                _buildMicroMacro('Fb', item.fiber, AppColors.neonGreen),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicroMacro(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '${value.toStringAsFixed(1)}g',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
