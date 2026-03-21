import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/budget_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction.dart';
import '../../models/family_member.dart';

/// Dashboard — Budget ring, stat cards, activity list.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final familyId = ref.read(familyProvider).currentFamily?.id;
      if (familyId != null) {
        ref.read(budgetProvider.notifier).loadDashboard(familyId);
        ref.read(categoryProvider.notifier).loadCategories(familyId);
      }
      ref.read(transactionProvider.notifier).loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final budget = ref.watch(budgetProvider);
    final txnState = ref.watch(transactionProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ──
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'MMMM yyyy',
                          ).format(DateTime.now()).toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textDim,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Budget Overview',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textMain,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.expand_more,
                              color: context.colors.primary,
                              size: 22,
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Family avatars
                    _FamilyAvatars(
                      members: ref.watch(familyProvider).members,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Budget Ring ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: _BudgetRingSection(
                totalBudget: budget.monthlyLimit,
                totalSpent: budget.totalSpent,
                isLoading: budget.isLoading,
              ),
            ),
          ),

          // ── Stat Cards ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: _StatCardsRow(
                dailyAverage: budget.dailyAverage,
                projectedSpend: budget.projectedSpend,
                estimatedSavings: budget.estimatedSavings,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Activity Header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Activity',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textMain,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.feed),
                    child: Text(
                      'See All',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Activity List ──
          if (txnState.isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final txn = txnState.transactions[index];
                  return _ActivityTile(
                    transaction: txn,
                    onTap: () => context.push(
                      '${AppRoutes.transactionDetail}/${txn.id}',
                    ),
                  );
                }, childCount: math.min(5, txnState.transactions.length)),
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ─── Family Avatars ───
class _FamilyAvatars extends StatelessWidget {
  final List<FamilyMember> members;
  const _FamilyAvatars({required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox();

    final displayMembers = members.take(3).toList();
    final width = 44.0 + ((displayMembers.length - 1) * 26.0);

    return SizedBox(
      width: width,
      height: 44,
      child: Stack(
        children: List.generate(displayMembers.length, (index) {
          final member = displayMembers[index];
          final initial = member.user?.displayName.isNotEmpty == true 
              ? member.user!.displayName[0].toUpperCase() 
              : 'U';
          
          final colors = [
            context.colors.primary,
            context.colors.accentMint,
            context.colors.accentCoral,
          ];

          return Positioned(
            left: index * 26.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.background, width: 3),
              ),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: colors[index % colors.length],
                child: Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}


// ─── Budget Ring Section ───
class _BudgetRingSection extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;
  final bool isLoading;

  const _BudgetRingSection({
    required this.totalBudget,
    required this.totalSpent,
    required this.isLoading,
  });

  double get _spentPercent =>
      totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;

  bool get _isOverBudget => totalSpent > totalBudget;

  double get _leftToSpend => totalBudget - totalSpent;

  String get _formattedLeft {
    final abs = _leftToSpend.abs();
    if (abs >= 100000) return '₹${(abs / 100000).toStringAsFixed(1)}L';
    if (abs >= 1000) return '₹${NumberFormat('#,##,###').format(abs.toInt())}';
    return '₹${abs.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: 256,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return SizedBox(
      height: 256,
      child: Center(
        child: SizedBox(
          width: 256,
          height: 256,
          child: CustomPaint(
            painter: _GradientRingPainter(
              percent: _spentPercent,
              isOverBudget: _isOverBudget,
              trackColor: context.colors.cardSurface,
              startColor: _isOverBudget
                  ? context.colors.accentCoral
                  : context.colors.primaryDark,
              endColor: _isOverBudget
                  ? context.colors.accentCoralDark
                  : context.colors.primaryLight,
              glowColor: _isOverBudget
                  ? context.colors.accentCoral
                  : context.colors.primary,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LEFT TO SPEND',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textDim,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '₹',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 30,
                            fontWeight: FontWeight.w400,
                            color: context.colors.textMain,
                            letterSpacing: -1,
                          ),
                        ),
                        TextSpan(
                          text: _formattedLeft.replaceAll('₹', ''),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textMain,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  // On Track badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color:
                          (_isOverBudget
                                  ? context.colors.accentCoral
                                  : context.colors.accentMint)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        BudgetlyTheme.radiusPill,
                      ),
                      border: Border.all(
                        color:
                            (_isOverBudget
                                    ? context.colors.accentCoral
                                    : context.colors.accentMint)
                                .withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isOverBudget
                              ? Icons.warning_rounded
                              : Icons.check_circle,
                          size: 14,
                          color: _isOverBudget
                              ? context.colors.accentCoral
                              : context.colors.accentMint,
                        ),
                        SizedBox(width: 4),
                        Text(
                          _isOverBudget ? 'OVER BUDGET' : 'ON TRACK',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _isOverBudget
                                ? context.colors.accentCoral
                                : context.colors.accentMint,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Gradient Ring Painter ───
class _GradientRingPainter extends CustomPainter {
  final double percent;
  final bool isOverBudget;
  final Color trackColor;
  final Color startColor;
  final Color endColor;
  final Color glowColor;

  _GradientRingPainter({
    required this.percent,
    required this.isOverBudget,
    required this.trackColor,
    required this.startColor,
    required this.endColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    const strokeWidth = 10.0;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Gradient arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + 2 * math.pi,
      colors: [startColor, endColor],
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * percent;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);

    // Glow effect at the tip
    if (percent > 0.02) {
      final tipAngle = -math.pi / 2 + sweepAngle;
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(tipX, tipY), 6, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradientRingPainter oldDelegate) =>
      percent != oldDelegate.percent ||
      isOverBudget != oldDelegate.isOverBudget;
}

// ─── Stat Cards Row ───
class _StatCardsRow extends StatelessWidget {
  final double dailyAverage;
  final double projectedSpend;
  final double estimatedSavings;

  const _StatCardsRow({
    required this.dailyAverage,
    required this.projectedSpend,
    required this.estimatedSavings,
  });

  String _formatCompact(double v) {
    final abs = v.abs();
    if (abs >= 100000) return '₹${(abs / 100000).toStringAsFixed(1)}L';
    if (abs >= 1000) return '₹${(abs / 1000).toStringAsFixed(0)}k';
    return '₹${abs.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            label: 'DAILY AVG',
            value: _formatCompact(dailyAverage),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            label: 'PROJECTED',
            value: _formatCompact(projectedSpend),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            label: 'SAVED',
            value: _formatCompact(estimatedSavings),
            valueColor: estimatedSavings >= 0
                ? context.colors.accentMint
                : context.colors.accentCoral,
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MiniStatCard({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.backgroundAlt,
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: context.colors.textDim,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '₹',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: valueColor ?? context.colors.textMain,
                  ),
                ),
                TextSpan(
                  text: value.replaceAll('₹', ''),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? context.colors.textMain,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Activity Tile ───
class _ActivityTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const _ActivityTile({required this.transaction, this.onTap});

  static const _categoryIcons = {
    'cat_001': Icons.shopping_bag,
    'cat_002': Icons.restaurant,
    'cat_003': Icons.directions_car,
    'cat_004': Icons.payments,
    'cat_005': Icons.receipt_long,
    'cat_006': Icons.medical_services,
    'cat_007': Icons.movie,
    'cat_008': Icons.shopping_cart,
  };

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMM d').format(date);
  }

  String _categoryLabel(String? categoryId) {
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
    return labels[categoryId] ?? 'Other';
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final icon = _categoryIcons[transaction.categoryId] ?? Icons.receipt;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.backgroundAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
          border: Border.all(
            color: isIncome
                ? context.colors.primary.withValues(alpha: 0.2)
                : context.colors.borderSubtle.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Category icon with user avatar overlay
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isIncome
                          ? context.colors.accentMint.withValues(alpha: 0.1)
                          : context.colors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(
                        BudgetlyTheme.radiusCard,
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
                  // Small avatar badge
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.colors.backgroundAlt,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'A',
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

            // Title & subtitle
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
                    '${_categoryLabel(transaction.categoryId)} • ${_timeAgo(transaction.transactionDate)}',
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
