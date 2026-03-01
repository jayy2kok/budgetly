import 'package:flutter/material.dart';

import '../config/theme.dart';

/// N-member payer toggle selector — shows family member chips
/// that can be selected as the payer of a transaction.
class PayerSelector extends StatelessWidget {
  final List<String> memberNames;
  final List<String> memberIds;
  final String? selectedMemberId;
  final ValueChanged<String>? onSelected;

  const PayerSelector({
    super.key,
    required this.memberNames,
    required this.memberIds,
    this.selectedMemberId,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: memberNames.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = memberIds[index] == selectedMemberId;
          return GestureDetector(
            onTap: () => onSelected?.call(memberIds[index]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? BudgetlyTheme.primary
                    : BudgetlyTheme.surfaceHighlight,
                borderRadius: BorderRadius.circular(BudgetlyTheme.radiusPill),
                border: Border.all(
                  color: isSelected
                      ? BudgetlyTheme.primary
                      : BudgetlyTheme.borderSubtle,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: isSelected
                        ? BudgetlyTheme.primaryDark
                        : BudgetlyTheme.cardSurface,
                    child: Text(
                      memberNames[index].isNotEmpty
                          ? memberNames[index][0]
                          : '?',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? BudgetlyTheme.textMain
                            : BudgetlyTheme.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    memberNames[index],
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isSelected
                          ? BudgetlyTheme.textMain
                          : BudgetlyTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
