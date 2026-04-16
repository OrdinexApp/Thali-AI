import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../services/gemini_service.dart';

class AnnotatedFoodImage extends StatelessWidget {
  final String imagePath;
  final List<DetectedItem> items;
  final void Function(int index) onItemTap;

  const AnnotatedFoodImage({
    super.key,
    required this.imagePath,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageHeight = MediaQuery.of(context).size.height * 0.38;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: imageHeight,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            // Resolve label positions to avoid overlaps
            final resolvedPositions = _resolvePositions(w, h);

            return Stack(
              children: [
                // Food image
                Positioned.fill(
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                  ),
                ),
                // Subtle darkening for readability
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
                // Pointer dots at food centers + lines to labels
                CustomPaint(
                  size: Size(w, h),
                  painter: _PointerPainter(
                    items: items,
                    resolvedPositions: resolvedPositions,
                    imageWidth: w,
                    imageHeight: h,
                  ),
                ),
                // Labels placed near their food
                for (int i = 0; i < items.length; i++)
                  _buildPositionedLabel(i, resolvedPositions[i], w, h),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Resolve positions so labels don't overlap, staying near their food
  List<Offset> _resolvePositions(double w, double h) {
    const labelW = 110.0;
    const labelH = 28.0;
    const margin = 4.0;

    // Start with ideal positions (food center, shifted to keep label inside)
    final positions = <Offset>[];
    for (final item in items) {
      double lx = (item.x * w - labelW / 2).clamp(margin, w - labelW - margin);
      double ly = (item.y * h - labelH / 2).clamp(margin, h - labelH - margin);
      positions.add(Offset(lx, ly));
    }

    // Push overlapping labels apart (iterative relaxation)
    for (int pass = 0; pass < 12; pass++) {
      bool moved = false;
      for (int i = 0; i < positions.length; i++) {
        for (int j = i + 1; j < positions.length; j++) {
          final dx = (positions[i].dx - positions[j].dx).abs();
          final dy = (positions[i].dy - positions[j].dy).abs();

          if (dx < labelW + 4 && dy < labelH + 4) {
            moved = true;
            // Push apart along the axis with less overlap
            if (dy <= dx) {
              // Push vertically
              final push = (labelH + 6 - dy) / 2;
              final iUp = positions[i].dy < positions[j].dy;
              positions[i] = Offset(
                positions[i].dx,
                (positions[i].dy + (iUp ? -push : push)).clamp(margin, h - labelH - margin),
              );
              positions[j] = Offset(
                positions[j].dx,
                (positions[j].dy + (iUp ? push : -push)).clamp(margin, h - labelH - margin),
              );
            } else {
              // Push horizontally
              final push = (labelW + 6 - dx) / 2;
              final iLeft = positions[i].dx < positions[j].dx;
              positions[i] = Offset(
                (positions[i].dx + (iLeft ? -push : push)).clamp(margin, w - labelW - margin),
                positions[i].dy,
              );
              positions[j] = Offset(
                (positions[j].dx + (iLeft ? push : -push)).clamp(margin, w - labelW - margin),
                positions[j].dy,
              );
            }
          }
        }
      }
      if (!moved) break;
    }

    return positions;
  }

  Widget _buildPositionedLabel(int index, Offset pos, double w, double h) {
    final item = items[index];
    final isConfirmed = item.confirmed;

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onItemTap(index);
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 130),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isConfirmed
                ? AppColors.emerald.withValues(alpha: 0.9)
                : Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isConfirmed
                  ? AppColors.emerald
                  : Colors.white.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isConfirmed)
                const Padding(
                  padding: EdgeInsets.only(right: 3),
                  child: Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 10),
                ),
              Flexible(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.edit_rounded,
                size: 8,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ],
          ),
        ).animate()
            .fadeIn(duration: 350.ms, delay: Duration(milliseconds: 150 + index * 80))
            .scale(begin: const Offset(0.8, 0.8), delay: Duration(milliseconds: 150 + index * 80)),
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  final List<DetectedItem> items;
  final List<Offset> resolvedPositions;
  final double imageWidth;
  final double imageHeight;

  _PointerPainter({
    required this.items,
    required this.resolvedPositions,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < items.length && i < resolvedPositions.length; i++) {
      final item = items[i];
      final foodCenter = Offset(item.x * imageWidth, item.y * imageHeight);
      final labelPos = resolvedPositions[i];
      final labelCenter = Offset(labelPos.dx + 55, labelPos.dy + 14);

      final color = item.confirmed
          ? AppColors.emerald
          : Colors.white.withValues(alpha: 0.8);

      // Only draw line if label moved significantly from food center
      final dist = (foodCenter - labelCenter).distance;
      if (dist > 30) {
        final linePaint = Paint()
          ..color = color.withValues(alpha: 0.5)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final path = Path();
        path.moveTo(labelCenter.dx, labelCenter.dy);
        path.lineTo(foodCenter.dx, foodCenter.dy);
        canvas.drawPath(path, linePaint);
      }

      // Dot at the actual food position
      final dotFill = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(foodCenter, 3.5, dotFill);

      final dotRing = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(foodCenter, 7, dotRing);
    }
  }

  @override
  bool shouldRepaint(covariant _PointerPainter old) => true;
}
