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
    return Icons.restaurant_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getFoodIcon(),
                color: AppColors.emerald,
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (item.portion != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.portion!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.calories.toInt()}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emerald,
                  ),
                ),
                const Text(
                  'kcal',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
