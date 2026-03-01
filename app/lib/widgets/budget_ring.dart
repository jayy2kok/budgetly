import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Circular budget usage ring showing "Left to Spend" or "Over Budget".
///
/// Displays a ring chart with the spent percentage filled in,
/// the remaining amount in the center, and a label below.
class BudgetRing extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;
  final double size;

  const BudgetRing({
    super.key,
    required this.totalBudget,
    required this.totalSpent,
    this.size = 200,
  });

  double get _spentPercent =>
      totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.5) : 0.0;

  bool get _isOverBudget => totalSpent > totalBudget;

  double get _leftToSpend => totalBudget - totalSpent;

  @override
  Widget build(BuildContext context) {
    final ringColor = _isOverBudget
        ? BudgetlyTheme.accentCoral
        : BudgetlyTheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BudgetRingPainter(
          percent: _spentPercent.clamp(0.0, 1.0),
          ringColor: ringColor,
          trackColor: BudgetlyTheme.surfaceHighlight,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isOverBudget ? 'Over Budget' : 'Left to Spend',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                '₹${_leftToSpend.abs().toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: _isOverBudget
                      ? BudgetlyTheme.accentCoral
                      : BudgetlyTheme.textMain,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(_spentPercent * 100).toStringAsFixed(0)}% used',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetRingPainter extends CustomPainter {
  final double percent;
  final Color ringColor;
  final Color trackColor;

  _BudgetRingPainter({
    required this.percent,
    required this.ringColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    const strokeWidth = 12.0;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress
    final progressPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * percent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BudgetRingPainter oldDelegate) =>
      percent != oldDelegate.percent || ringColor != oldDelegate.ringColor;
}
