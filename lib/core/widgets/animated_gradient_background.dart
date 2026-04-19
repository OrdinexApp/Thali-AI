import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/theme_controller.dart';

class AnimatedGradientBackground extends ConsumerStatefulWidget {
  final Widget child;

  const AnimatedGradientBackground({super.key, required this.child});

  @override
  ConsumerState<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends ConsumerState<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final variant = ref.watch(themeControllerProvider);

    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: variant.backgroundGradient,
            ),
          ),
        ),
        AnimatedBuilder2(
          listenable: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _GlowPainter(_controller.value, variant.glowColors),
              size: Size.infinite,
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class AnimatedBuilder2 extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;

  const AnimatedBuilder2({
    super.key,
    required super.listenable,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) => builder(context, null);
}

class _GlowPainter extends CustomPainter {
  final double progress;
  final List<Color> glowColors;

  _GlowPainter(this.progress, this.glowColors);

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = glowColors[0].withValues(alpha: 0.055)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);

    final p2 = Paint()
      ..color = glowColors[1].withValues(alpha: 0.035)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 140);

    final p3 = Paint()
      ..color = glowColors[2].withValues(alpha: 0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 160);

    final x1 = size.width * (0.15 + 0.25 * sin(progress * 2 * pi));
    final y1 = size.height * (0.1 + 0.2 * cos(progress * 2 * pi));

    final x2 = size.width * (0.8 - 0.2 * cos(progress * 2 * pi));
    final y2 = size.height * (0.5 + 0.15 * sin(progress * 2 * pi));

    final x3 = size.width * (0.5 + 0.15 * sin(progress * 3 * pi));
    final y3 = size.height * (0.8 - 0.1 * cos(progress * 3 * pi));

    canvas.drawCircle(Offset(x1, y1), 220, p1);
    canvas.drawCircle(Offset(x2, y2), 200, p2);
    canvas.drawCircle(Offset(x3, y3), 240, p3);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.glowColors != glowColors;
}
