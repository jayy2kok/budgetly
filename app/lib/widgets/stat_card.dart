import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Dashboard summary card (e.g., Daily Average, Projected Spend, Savings).
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BudgetlyTheme.cardSurface,
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
        border: Border.all(color: BudgetlyTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: BudgetlyTheme.textMuted),
              const SizedBox(width: 6),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: valueColor ?? BudgetlyTheme.textMain,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
