import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Swipeable triage card for SMS-parsed messages in the inbox.
class MessageCard extends StatelessWidget {
  final String merchantIcon;
  final String merchantName;
  final double amount;
  final String date;
  final String categoryName;
  final String rawSmsText;
  final VoidCallback? onConfirm;
  final VoidCallback? onEdit;
  final VoidCallback? onReject;

  const MessageCard({
    super.key,
    required this.merchantIcon,
    required this.merchantName,
    required this.amount,
    required this.date,
    required this.categoryName,
    required this.rawSmsText,
    this.onConfirm,
    this.onEdit,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BudgetlyTheme.cardSurface,
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCardLg),
        border: Border.all(color: BudgetlyTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(merchantIcon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchantName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(date, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Category tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: BudgetlyTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(BudgetlyTheme.radiusPill),
            ),
            child: Text(
              categoryName,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: BudgetlyTheme.primaryLight,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Raw SMS text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BudgetlyTheme.backgroundAlt,
              borderRadius: BorderRadius.circular(BudgetlyTheme.radiusSmall),
            ),
            child: Text(
              rawSmsText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              // Reject
              OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BudgetlyTheme.accentCoral,
                  side: const BorderSide(color: BudgetlyTheme.accentCoral),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      BudgetlyTheme.radiusPill,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Edit
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BudgetlyTheme.textMuted,
                  side: const BorderSide(color: BudgetlyTheme.borderLight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      BudgetlyTheme.radiusPill,
                    ),
                  ),
                ),
              ),
              const Spacer(),

              // Confirm (primary)
              FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check, size: 20),
                label: const Text('Confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: BudgetlyTheme.accentMint,
                  foregroundColor: BudgetlyTheme.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      BudgetlyTheme.radiusPill,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
