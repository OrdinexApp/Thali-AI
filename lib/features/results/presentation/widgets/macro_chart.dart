import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../features/history/data/models/meal_model.dart';

class MacroChart extends StatefulWidget {
  final MealAnalysis meal;

  const MacroChart({super.key, required this.meal});

  @override
  State<MacroChart> createState() => _MacroChartState();
}

class _MacroChartState extends State<MacroChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.meal.totalProtein +
        widget.meal.totalCarbs +
        widget.meal.totalFat;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Macro Split',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: _MacroChartAnimated(
                  animation: _animation,
                  protein: widget.meal.totalProtein,
                  carbs: widget.meal.totalCarbs,
                  fat: widget.meal.totalFat,
                  total: total,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildMacroRow(
                      'Protein',
                      widget.meal.totalProtein,
                      total,
                      AppColors.cyan,
                    ),
                    const SizedBox(height: 14),
                    _buildMacroRow(
                      'Carbs',
                      widget.meal.totalCarbs,
                      total,
                      AppColors.warning,
                    ),
                    const SizedBox(height: 14),
                    _buildMacroRow(
                      'Fat',
                      widget.meal.totalFat,
                      total,
                      AppColors.error,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRow(String label, double value, double total, Color color) {
    final percent = total > 0 ? (value / total * 100) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              '${value.toInt()}g (${percent.toInt()}%)',
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: _AnimatedProgressBar(
            animation: _animation,
            progress: total > 0 ? value / total : 0,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AnimatedProgressBar extends AnimatedWidget {
  final double progress;
  final Color color;

  const _AnimatedProgressBar({
    required Animation<double> animation,
    required this.progress,
    required this.color,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final anim = listenable as Animation<double>;
    return SizedBox(
      height: 4,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          FractionallySizedBox(
            widthFactor: progress * anim.value,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroChartAnimated extends AnimatedWidget {
  final double protein;
  final double carbs;
  final double fat;
  final double total;

  const _MacroChartAnimated({
    required Animation<double> animation,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.total,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final anim = listenable as Animation<double>;
    return CustomPaint(
      painter: _DonutPainter(
        protein: protein,
        carbs: carbs,
        fat: fat,
        total: total,
        progress: anim.value,
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double protein, carbs, fat, total, progress;

  _DonutPainter({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.total,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 12.0;

    final bgPaint = Paint()
      ..color = AppColors.surfaceLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    if (total <= 0) return;

    final proteinAngle = (protein / total) * 2 * pi * progress;
    final carbsAngle = (carbs / total) * 2 * pi * progress;
    final fatAngle = (fat / total) * 2 * pi * progress;

    void drawArc(double startAngle, double sweepAngle, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle - pi / 2,
        sweepAngle,
        false,
        paint,
      );
    }

    drawArc(0, proteinAngle, AppColors.cyan);
    drawArc(proteinAngle, carbsAngle, AppColors.warning);
    drawArc(proteinAngle + carbsAngle, fatAngle, AppColors.error);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
