import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction.dart';

/// Transaction Feed — Date-grouped list with filter chips.
class TransactionFeedScreen extends ConsumerStatefulWidget {
  const TransactionFeedScreen({super.key});

  @override
  ConsumerState<TransactionFeedScreen> createState() =>
      _TransactionFeedScreenState();
}

class _TransactionFeedScreenState extends ConsumerState<TransactionFeedScreen> {
  int _selectedFilter = 0;
  bool _showSearch = false;
  final _searchController = TextEditingController();

  static const _filters = ['All', 'Expenses', 'Income', 'Subscriptions'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionProvider.notifier).loadTransactions();
    });
  }

  void _onFilterTap(int index) {
    setState(() => _selectedFilter = index);
    final notifier = ref.read(transactionProvider.notifier);
    switch (index) {
      case 0:
        notifier.setFilter(null);
      case 1:
        notifier.setFilter(TransactionType.expense);
      case 2:
        notifier.setFilter(TransactionType.income);
      case 3:
        notifier.setFilter(TransactionType.subscription);
    }
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        ref.read(transactionProvider.notifier).setSearch('');
      }
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Filter by Type',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.textMain,
              ),
            ),
            SizedBox(height: 16),
            ...List.generate(_filters.length, (i) {
              final active = _selectedFilter == i;
              return ListTile(
                leading: Icon(
                  active ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: active
                      ? context.colors.primary
                      : context.colors.textDim,
                ),
                title: Text(
                  _filters[i],
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: context.colors.textMain,
                  ),
                ),
                onTap: () {
                  _onFilterTap(i);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Group transactions by date label.
  Map<String, List<Transaction>> _groupByDate(List<Transaction> txns) {
    final groups = <String, List<Transaction>>{};
    for (final txn in txns) {
      final label = _dateLabel(txn.transactionDate);
      groups.putIfAbsent(label, () => []).add(txn);
    }
    return groups;
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txnDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(txnDay).inDays;

    if (diff == 0) return 'Today, ${DateFormat('MMM d').format(date)}';
    if (diff == 1) return 'Yesterday, ${DateFormat('MMM d').format(date)}';
    return DateFormat('EEEE, MMM d').format(date);
  }

  List<Widget> _buildGroupedSlivers(
    List<String> sortedKeys,
    Map<String, List<Transaction>> grouped,
  ) {
    final slivers = <Widget>[];
    for (final dateLabel in sortedKeys) {
      final txns = grouped[dateLabel]!;
      // Date header as simple sliver (avoids SliverGeometry conflicts)
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            color: context.colors.background,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              dateLabel.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: context.colors.textMuted,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final txn = txns[index];
              return _FeedTile(
                transaction: txn,
                onTap: () =>
                    context.push('${AppRoutes.transactionDetail}/${txn.id}'),
              );
            }, childCount: txns.length),
          ),
        ),
      );
    }
    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    final txnState = ref.watch(transactionProvider);
    final filtered = txnState.filteredTransactions;
    final grouped = _groupByDate(filtered);
    final sortedKeys = grouped.keys.toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ──
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + icons
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Feed',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textMain,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Row(
                          children: [
                            _HeaderIconButton(
                              icon: _showSearch ? Icons.close : Icons.search,
                              onTap: _toggleSearch,
                            ),
                            SizedBox(width: 8),
                            _HeaderIconButton(
                              icon: Icons.tune,
                              onTap: _showFilterSheet,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Search bar
                  if (_showSearch)
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: context.colors.textMain,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search by merchant...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: context.colors.textDim,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: context.colors.textDim,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: context.colors.cardSurface,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              BudgetlyTheme.radiusPill,
                            ),
                            borderSide: BorderSide(
                              color: context.colors.borderSubtle,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              BudgetlyTheme.radiusPill,
                            ),
                            borderSide: BorderSide(
                              color: context.colors.borderSubtle,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              BudgetlyTheme.radiusPill,
                            ),
                            borderSide: BorderSide(
                              color: context.colors.primary,
                            ),
                          ),
                        ),
                        onChanged: (q) =>
                            ref.read(transactionProvider.notifier).setSearch(q),
                      ),
                    ),

                  // Filter chips
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _filters.length,
                      separatorBuilder: (_, _) => SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final isActive = _selectedFilter == index;
                        return GestureDetector(
                          onTap: () => _onFilterTap(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? context.colors.primary
                                  : context.colors.cardSurface,
                              borderRadius: BorderRadius.circular(
                                BudgetlyTheme.radiusPill,
                              ),
                              border: isActive
                                  ? null
                                  : Border.all(
                                      color: context.colors.borderSubtle,
                                    ),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: context.colors.primary
                                            .withValues(alpha: 0.2),
                                        blurRadius: 15,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              _filters[index],
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isActive
                                    ? Colors.white
                                    : context.colors.textMuted,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: context.colors.borderSubtle.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),

          // ── Loading ──
          if (txnState.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          // ── Empty ──
          else if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: context.colors.textDim.withValues(alpha: 0.5),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No transactions yet',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: context.colors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            )
          // ── Grouped List ──
          else
            ..._buildGroupedSlivers(sortedKeys, grouped),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ─── Header Icon Button ───
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.colors.cardSurface,
          shape: BoxShape.circle,
          border: Border.all(color: context.colors.borderSubtle),
        ),
        child: Icon(icon, color: context.colors.textMuted, size: 22),
      ),
    );
  }
}

// ─── Feed Transaction Tile ───
class _FeedTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const _FeedTile({required this.transaction, this.onTap});

  static const _categoryIcons = {
    'cat_001': Icons.shopping_bag,
    'cat_002': Icons.restaurant,
    'cat_003': Icons.directions_car,
    'cat_004': Icons.payments,
    'cat_005': Icons.receipt_long,
    'cat_006': Icons.medical_services,
    'cat_007': Icons.sports_esports,
    'cat_008': Icons.shopping_cart,
  };

  static const _categoryLabels = {
    'cat_001': 'Household',
    'cat_002': 'Dining',
    'cat_003': 'Transport',
    'cat_004': 'Home',
    'cat_005': 'Bills',
    'cat_006': 'Health',
    'cat_007': 'Leisure',
    'cat_008': 'Shopping',
  };

  static const _payerNames = {
    'user_001': 'Arjun',
    'user_002': 'Priya',
    'user_003': 'Rohan',
  };

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final icon = _categoryIcons[transaction.categoryId] ?? Icons.receipt;
    final payer = _payerNames[transaction.createdByUserId] ?? 'Unknown';
    final category = _categoryLabels[transaction.categoryId] ?? 'Other';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.cardSurface,
          borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
          border: Border.all(
            color: isIncome
                ? context.colors.primary.withValues(alpha: 0.2)
                : context.colors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            // Icon + avatar
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isIncome
                          ? context.colors.accentMint.withValues(alpha: 0.1)
                          : context.colors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(
                        BudgetlyTheme.radiusMedium,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: isIncome
                          ? context.colors.accentMint
                          : context.colors.primaryLight,
                      size: 22,
                    ),
                  ),
                  Positioned(
                    bottom: -3,
                    right: -3,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.colors.cardSurface,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          payer[0],
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: 14),

            // Name + subtext
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.merchant,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textMain,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3),
                  Text(
                    '$payer • $category',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.colors.textDim,
                    ),
                  ),
                ],
              ),
            ),

            // Amount
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '₹',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: isIncome
                          ? context.colors.accentMint
                          : context.colors.textMain,
                    ),
                  ),
                  TextSpan(
                    text: NumberFormat(
                      '#,##,###',
                    ).format(transaction.amount.toInt()),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isIncome
                          ? context.colors.accentMint
                          : context.colors.textMain,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
