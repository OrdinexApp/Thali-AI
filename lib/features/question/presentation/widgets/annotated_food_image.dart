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
    final size = MediaQuery.of(context).size;
    final imageHeight = size.height * 0.35;

    return SizedBox(
      height: imageHeight + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Food image
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Dark overlay for label readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
          // Labels with arrows
          ..._buildLabels(imageHeight),
        ],
      ),
    );
  }

  List<Widget> _buildLabels(double imageHeight) {
    final labels = <Widget>[];
    final positions = _getPositions(items.length, imageHeight);

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final pos = positions[i];

      labels.add(
        Positioned(
          left: pos.labelLeft,
          top: pos.labelTop,
          child: _FoodLabel(
            item: item,
            index: i,
            onTap: () => onItemTap(i),
            arrowDirection: pos.arrowDir,
            delay: Duration(milliseconds: 300 + i * 120),
          ),
        ),
      );
    }
    return labels;
  }

  List<_LabelPosition> _getPositions(int count, double height) {
    // Distribute labels around the image edges
    final positions = <_LabelPosition>[];
    final usedRegions = <int>{};

    for (int i = 0; i < count; i++) {
      int region = i % 6;
      while (usedRegions.contains(region) && usedRegions.length < 6) {
        region = (region + 1) % 6;
      }
      usedRegions.add(region);

      switch (region) {
        case 0: // Top-left
          positions.add(_LabelPosition(8, 8, _ArrowDir.bottomRight));
          break;
        case 1: // Top-right
          positions.add(_LabelPosition(120, 8, _ArrowDir.bottomLeft));
          break;
        case 2: // Mid-left
          positions.add(
              _LabelPosition(8, height * 0.35, _ArrowDir.right));
          break;
        case 3: // Mid-right
          positions.add(
              _LabelPosition(140, height * 0.38, _ArrowDir.left));
          break;
        case 4: // Bottom-left
          positions.add(_LabelPosition(
              8, height * 0.65, _ArrowDir.topRight));
          break;
        case 5: // Bottom-right
          positions.add(_LabelPosition(
              100, height * 0.68, _ArrowDir.topLeft));
          break;
      }
    }
    return positions;
  }
}

enum _ArrowDir { left, right, topLeft, topRight, bottomLeft, bottomRight }

class _LabelPosition {
  final double labelLeft;
  final double labelTop;
  final _ArrowDir arrowDir;

  _LabelPosition(this.labelLeft, this.labelTop, this.arrowDir);
}

class _FoodLabel extends StatelessWidget {
  final DetectedItem item;
  final int index;
  final VoidCallback onTap;
  final _ArrowDir arrowDirection;
  final Duration delay;

  const _FoodLabel({
    required this.item,
    required this.index,
    required this.onTap,
    required this.arrowDirection,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showArrowBefore) _buildArrow(),
          _buildLabelChip(),
          if (!_showArrowBefore) _buildArrow(),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: delay)
        .scale(begin: const Offset(0.8, 0.8), delay: delay);
  }

  bool get _showArrowBefore =>
      arrowDirection == _ArrowDir.left ||
      arrowDirection == _ArrowDir.topLeft ||
      arrowDirection == _ArrowDir.bottomLeft;

  Widget _buildArrow() {
    return CustomPaint(
      size: const Size(28, 20),
      painter: _ArrowPainter(
        direction: arrowDirection,
        color: item.confirmed ? AppColors.emerald : AppColors.cyan,
      ),
    );
  }

  Widget _buildLabelChip() {
    final isConfirmed = item.confirmed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isConfirmed
            ? AppColors.emerald.withValues(alpha: 0.85)
            : Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isConfirmed
              ? AppColors.emerald
              : AppColors.cyan.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isConfirmed ? AppColors.emerald : AppColors.cyan)
                .withValues(alpha: 0.25),
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
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 12),
            ),
          Flexible(
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            Icons.edit_rounded,
            size: 10,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final _ArrowDir direction;
  final Color color;

  _ArrowPainter({required this.direction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final w = size.width;
    final h = size.height;

    switch (direction) {
      case _ArrowDir.right:
        path.moveTo(0, h / 2);
        path.quadraticBezierTo(w * 0.6, h / 2, w, h * 0.8);
        break;
      case _ArrowDir.left:
        path.moveTo(w, h / 2);
        path.quadraticBezierTo(w * 0.4, h / 2, 0, h * 0.8);
        break;
      case _ArrowDir.topRight:
        path.moveTo(0, h);
        path.quadraticBezierTo(w * 0.5, h * 0.3, w, 0);
        break;
      case _ArrowDir.topLeft:
        path.moveTo(w, h);
        path.quadraticBezierTo(w * 0.5, h * 0.3, 0, 0);
        break;
      case _ArrowDir.bottomRight:
        path.moveTo(0, 0);
        path.quadraticBezierTo(w * 0.5, h * 0.7, w, h);
        break;
      case _ArrowDir.bottomLeft:
        path.moveTo(w, 0);
        path.quadraticBezierTo(w * 0.5, h * 0.7, 0, h);
        break;
    }

    canvas.drawPath(path, paint);

    // Small dot at the end
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    Offset dotPos;
    switch (direction) {
      case _ArrowDir.right:
        dotPos = Offset(w, h * 0.8);
        break;
      case _ArrowDir.left:
        dotPos = Offset(0, h * 0.8);
        break;
      case _ArrowDir.topRight:
        dotPos = Offset(w, 0);
        break;
      case _ArrowDir.topLeft:
        dotPos = const Offset(0, 0);
        break;
      case _ArrowDir.bottomRight:
        dotPos = Offset(w, h);
        break;
      case _ArrowDir.bottomLeft:
        dotPos = Offset(0, h);
        break;
    }
    canvas.drawCircle(dotPos, 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.direction != direction;
}
