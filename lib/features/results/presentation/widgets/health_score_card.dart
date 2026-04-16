import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';

class HealthScoreCard extends StatefulWidget {
  final int score;
  final String? tip;

  const HealthScoreCard({super.key, required this.score, this.tip});

  @override
  State<HealthScoreCard> createState() => _HealthScoreCardState();
}

class _HealthScoreCardState extends State<HealthScoreCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _animation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _scoreColor(int score) {
    if (score >= 8) return AppColors.emerald;
    if (score >= 6) return AppColors.neonGreen;
    if (score >= 4) return AppColors.warning;
    return AppColors.error;
  }

  String _scoreLabel(int score) {
    if (score >= 9) return 'Excellent';
    if (score >= 7) return 'Good';
    if (score >= 5) return 'Average';
    if (score >= 3) return 'Below Average';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(widget.score);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: _AnimatedScoreArc(
                  animation: _animation,
                  score: widget.score,
                  color: color,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Health Score',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _scoreLabel(widget.score),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (widget.tip != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_rounded,
                              size: 14, color: AppColors.warning.withValues(alpha: 0.8)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.tip!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
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
}

class _AnimatedScoreArc extends AnimatedWidget {
  final int score;
  final Color color;

  const _AnimatedScoreArc({
    required Animation<double> animation,
    required this.score,
    required this.color,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final anim = listenable as Animation<double>;
    return CustomPaint(
      painter: _ScoreArcPainter(
        score: score,
        color: color,
        progress: anim.value,
      ),
      child: Center(
        child: Text(
          '${(score * anim.value).round()}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _ScoreArcPainter extends CustomPainter {
  final int score;
  final Color color;
  final double progress;

  _ScoreArcPainter({
    required this.score,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 6.0;

    final bgPaint = Paint()
      ..color = AppColors.surfaceLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const sweepRange = 1.5 * pi;
    const startAngle = 0.75 * pi;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepRange,
      false,
      bgPaint,
    );

    final scoreFraction = (score / 10.0).clamp(0.0, 1.0);
    final scoreSweep = sweepRange * scoreFraction * progress;

    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepRange,
      colors: [color.withValues(alpha: 0.5), color],
    );

    final scorePaint = Paint()
      ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      scoreSweep,
      false,
      scorePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.score != score;
}
