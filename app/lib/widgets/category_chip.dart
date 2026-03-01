import 'package:flutter/material.dart';

import '../config/theme.dart';

/// A selectable category chip (filter or picker).
class CategoryChip extends StatelessWidget {
  final String icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const CategoryChip({
    super.key,
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? BudgetlyTheme.primary.withValues(alpha: 0.2)
              : BudgetlyTheme.surfaceHighlight,
          borderRadius: BorderRadius.circular(BudgetlyTheme.radiusPill),
          border: Border.all(
            color: isSelected
                ? BudgetlyTheme.primary
                : BudgetlyTheme.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? BudgetlyTheme.primaryLight
                    : BudgetlyTheme.textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
