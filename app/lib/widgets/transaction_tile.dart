import 'package:flutter/material.dart';

import '../config/theme.dart';

/// A single transaction row in a list — shows category icon, merchant,
/// payer avatar, category tag, and amount.
class TransactionTile extends StatelessWidget {
  final String categoryIcon;
  final String merchant;
  final String payerName;
  final String categoryName;
  final double amount;
  final bool isIncome;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.categoryIcon,
    required this.merchant,
    required this.payerName,
    required this.categoryName,
    required this.amount,
    this.isIncome = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final amountColor = isIncome
        ? BudgetlyTheme.accentMint
        : BudgetlyTheme.textMain;
    final prefix = isIncome ? '+' : '-';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BudgetlyTheme.radiusMedium),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: BudgetlyTheme.surfaceHighlight,
                borderRadius: BorderRadius.circular(BudgetlyTheme.radiusMedium),
              ),
              alignment: Alignment.center,
              child: Text(categoryIcon, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),

            // Merchant & payer
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // Payer avatar circle
                      CircleAvatar(
                        radius: 8,
                        backgroundColor: BudgetlyTheme.primary,
                        child: Text(
                          payerName.isNotEmpty ? payerName[0] : '?',
                          style: const TextStyle(
                            fontSize: 9,
                            color: BudgetlyTheme.textMain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        payerName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      // Category tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: BudgetlyTheme.surfaceHighlight.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(
                            BudgetlyTheme.radiusPill,
                          ),
                        ),
                        child: Text(
                          categoryName,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              '$prefix₹${amount.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
