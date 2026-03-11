import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/transaction.dart';

import '../../providers/transaction_provider.dart';

/// Transaction Detail — Full info, source SMS.
class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnState = ref.watch(transactionProvider);
    final txn = txnState.transactions.cast<Transaction?>().firstWhere(
      (t) => t?.id == transactionId,
      orElse: () => null,
    );

    if (txn == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('Transaction not found')),
      );
    }

    final isIncome = txn.type == TransactionType.income;

    return Scaffold(
      body: Column(
        children: [
          // ── Header ──
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: context.colors.textMuted,
                    ),
                  ),
                  Text(
                    'Transaction Detail',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textMain,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.more_horiz,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 24),

                  // ── Amount ──
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '₹',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 40,
                            fontWeight: FontWeight.w400,
                            color: isIncome
                                ? context.colors.accentMint
                                : context.colors.textMain,
                          ),
                        ),
                        TextSpan(
                          text: NumberFormat(
                            '#,##,###',
                          ).format(txn.amount.toInt()),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            color: isIncome
                                ? context.colors.accentMint
                                : context.colors.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 6),

                  // Type badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          (isIncome
                                  ? context.colors.accentMint
                                  : context.colors.primary)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        BudgetlyTheme.radiusPill,
                      ),
                    ),
                    child: Text(
                      txn.type.name.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isIncome
                            ? context.colors.accentMint
                            : context.colors.primaryLight,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  SizedBox(height: 32),

                  // ── Detail Fields ──
                  _DetailCard(
                    children: [
                      _DetailRow(
                        label: 'Merchant',
                        value: txn.merchant,
                        icon: Icons.storefront,
                      ),
                      _DetailRow(
                        label: 'Category',
                        value: _categoryName(txn.categoryId),
                        icon: Icons.label_outline,
                      ),
                      _DetailRow(
                        label: 'Date',
                        value: DateFormat(
                          'EEE, MMM d, yyyy',
                        ).format(txn.transactionDate),
                        icon: Icons.calendar_today,
                      ),
                      _DetailRow(
                        label: 'Added by',
                        value: _payerName(txn.createdByUserId),
                        icon: Icons.person_outline,
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // ── Source SMS ──
                  if (txn.sourceRawText != null) ...[
                    _DetailCard(
                      title: 'SOURCE SMS',
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.colors.background,
                            borderRadius: BorderRadius.circular(
                              BudgetlyTheme.radiusSmall,
                            ),
                          ),
                          child: Text(
                            txn.sourceRawText!,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              color: context.colors.textMuted,
                              height: 1.6,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 14,
                              color: context.colors.primary.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              txn.sourceType == SourceType.regexLocal
                                  ? 'Regex parsed ✓'
                                  : 'LLM parsed ✓',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: context.colors.textDim,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                  ],

                  // ── Notes ──
                  if (txn.notes != null && txn.notes!.isNotEmpty)
                    _DetailCard(
                      title: 'NOTES',
                      children: [
                        Text(
                          txn.notes!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: context.colors.textMuted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),

                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _categoryName(String id) {
    if (id == 'uncategorized') return 'Uncategorized';
    const labels = {
      'cat_001': 'Groceries',
      'cat_002': 'Dining',
      'cat_003': 'Transport',
      'cat_004': 'Housing',
      'cat_005': 'Bills',
      'cat_006': 'Health',
      'cat_007': 'Entertainment',
      'cat_008': 'Shopping',
    };
    return labels[id] ?? 'Uncategorized';
  }

  String _payerName(String userId) {
    const names = {
      'user_001': 'Arjun Sharma',
      'user_002': 'Priya Sharma',
      'user_003': 'Rohan Sharma',
    };
    return names[userId] ?? 'Unknown';
  }
}

// ─── Detail Card ───
class _DetailCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _DetailCard({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title!,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.colors.textMuted,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.cardSurface,
            borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
            border: Border.all(color: context.colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

// ─── Detail Row ───
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.colors.textDim),
          SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: context.colors.textDim,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textMain,
              ),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
