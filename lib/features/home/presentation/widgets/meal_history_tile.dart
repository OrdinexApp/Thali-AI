import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../features/history/data/models/meal_model.dart';

class MealHistoryTile extends StatelessWidget {
  final MealAnalysis meal;

  const MealHistoryTile({super.key, required this.meal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        borderRadius: 20,
        child: Row(
          children: [
            _buildImage(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getMealLabel(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        DateFormat('h:mm a').format(meal.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${meal.items.length} ${meal.items.length == 1 ? 'item' : 'items'}',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMiniStat(
                        '${meal.totalCalories.toInt()}',
                        'kcal',
                        AppColors.emerald,
                      ),
                      const SizedBox(width: 16),
                      _buildMiniStat(
                        '${meal.totalProtein.toInt()}g',
                        'protein',
                        AppColors.cyan,
                      ),
                      const SizedBox(width: 16),
                      _buildMiniStat(
                        '${meal.totalCarbs.toInt()}g',
                        'carbs',
                        AppColors.warning,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMealLabel() {
    final hour = meal.timestamp.hour;
    if (hour < 11) return 'Breakfast';
    if (hour < 15) return 'Lunch';
    if (hour < 18) return 'Snack';
    return 'Dinner';
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.glassBorder.withValues(alpha: 0.5),
          ),
        ),
        child: _buildImageContent(),
      ),
    );
  }

  Widget _buildImageContent() {
    final path = meal.imagePath;
    if (path == null || path.isEmpty) return _placeholder();

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    final file = File(path);
    if (!file.existsSync()) return _placeholder();
    return Image.file(file, fit: BoxFit.cover);
  }

  Widget _placeholder() => const Icon(
        Icons.restaurant_rounded,
        color: AppColors.emerald,
        size: 28,
      );

  Widget _buildMiniStat(String value, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
