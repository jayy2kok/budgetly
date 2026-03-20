import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../data/mock/sample_data.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/budget_provider.dart';

/// Monthly Budget — Overall progress + per-category breakdown.
class MonthlyBudgetScreen extends ConsumerWidget {
  const MonthlyBudgetScreen({super.key});

  static const _emojis = [
    '🛒',
    '🍽️',
    '🚗',
    '🏠',
    '📱',
    '💊',
    '🎮',
    '🛍️',
    '📚',
    '✈️',
    '💼',
    '⚽',
  ];

  void _showEditBudgetSheet(
    BuildContext context,
    WidgetRef ref,
    double currentBudget,
  ) {
    final budgetCtrl = TextEditingController(
      text: currentBudget.toInt().toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
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
              'Edit Budget Limit',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.colors.textMain,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Limit (₹)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.colors.textDim,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: budgetCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: context.colors.textMain,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 50000',
                hintStyle: GoogleFonts.inter(color: context.colors.textMuted),
                prefixIcon: Icon(
                  Icons.currency_rupee,
                  color: context.colors.textDim,
                  size: 18,
                ),
                filled: true,
                fillColor: context.colors.surfaceHighlight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  final val = double.tryParse(budgetCtrl.text);
                  if (val != null) {
                    ref.read(budgetProvider.notifier).updateBudgetLimit('family_001', val);
                  }
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      BudgetlyTheme.radiusMedium,
                    ),
                  ),
                ),
                child: Text(
                  'Save Budget',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCategorySheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    var selectedEmoji = _emojis[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
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
                'Add Category',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textMain,
                ),
              ),
              SizedBox(height: 20),

              // Emoji picker
              Text(
                'Icon',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textDim,
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _emojis.map((e) {
                  final isSelected = e == selectedEmoji;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedEmoji = e),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.colors.primary.withValues(alpha: 0.15)
                            : context.colors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: context.colors.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Center(
                        child: Text(e, style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 16),

              // Name field
              Text(
                'Name',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textDim,
                ),
              ),
              SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: context.colors.textMain,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Travel',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.textDim,
                  ),
                  filled: true,
                  fillColor: context.colors.background,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.primary),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Budget limit field
              Text(
                'Monthly Budget (₹)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textDim,
                ),
              ),
              SizedBox(height: 6),
              TextField(
                controller: budgetCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: context.colors.textMain,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. 10000',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.textDim,
                  ),
                  prefixText: '₹ ',
                  prefixStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.textMain,
                  ),
                  filled: true,
                  fillColor: context.colors.background,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.primary),
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final budget = double.tryParse(budgetCtrl.text.trim()) ?? 0;
                    if (name.isEmpty || budget <= 0) return;

                    SampleData.categories.add(
                      Category(
                        id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
                        familyGroupId: 'family_001',
                        name: name,
                        icon: selectedEmoji,
                        budgetLimit: budget,
                        color: '#5B5EF4',
                        sortOrder: SampleData.categories.length,
                      ),
                    );
                    Navigator.pop(ctx);
                    // Trigger rebuild by using a snackbar as feedback
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$name category added!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save Category',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditCategorySheet(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) {
    final nameCtrl = TextEditingController(text: category.name);
    final budgetCtrl = TextEditingController(
      text: category.budgetLimit.toInt().toString(),
    );
    var selectedEmoji = category.icon;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
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
                'Edit Category',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textMain,
                ),
              ),
              SizedBox(height: 20),

              // Emoji picker
              Text(
                'Icon',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textDim,
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _emojis.map((e) {
                  final isSelected = e == selectedEmoji;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedEmoji = e),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.colors.primary.withValues(alpha: 0.15)
                            : context.colors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: context.colors.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Center(
                        child: Text(e, style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 16),

              // Name field
              Text(
                'Name',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textDim,
                ),
              ),
              SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: context.colors.textMain,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Groceries',
                  hintStyle: GoogleFonts.inter(color: context.colors.textMuted),
                  filled: true,
                  fillColor: context.colors.background,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.borderSubtle),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Limit field
              Text(
                'Monthly Limit',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textDim,
                ),
              ),
              SizedBox(height: 6),
              TextField(
                controller: budgetCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: context.colors.textMain,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. 15000',
                  hintStyle: GoogleFonts.inter(color: context.colors.textMuted),
                  prefixStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.textDim,
                  ),
                  prefixText: '₹ ',
                  filled: true,
                  fillColor: context.colors.background,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.borderSubtle),
                  ),
                ),
              ),
              SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final index = SampleData.categories.indexWhere(
                      (c) => c.id == category.id,
                    );
                    if (index != -1) {
                      SampleData.categories[index] = Category(
                        id: category.id,
                        familyGroupId: category.familyGroupId,
                        name: nameCtrl.text.trim().isEmpty
                            ? category.name
                            : nameCtrl.text.trim(),
                        icon: selectedEmoji,
                        budgetLimit:
                            double.tryParse(budgetCtrl.text) ??
                            category.budgetLimit,
                        color: category.color,
                        sortOrder: category.sortOrder,
                      );
                      ref
                          .read(budgetProvider.notifier)
                          .loadDashboard(SampleData.familyGroup.id);
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Category updated!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save Changes',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteCategoryDialog(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.cardSurface,
        title: Text(
          'Delete Category?',
          style: GoogleFonts.inter(
            color: context.colors.textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Transactions associated with this category will be marked as "Uncategorized".',
          style: GoogleFonts.inter(color: context.colors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: context.colors.textDim),
            ),
          ),
          TextButton(
            onPressed: () {
              // Update transactions to uncategorized
              for (int i = 0; i < SampleData.transactions.length; i++) {
                if (SampleData.transactions[i].categoryId == category.id) {
                  SampleData.transactions[i] = Transaction(
                    id: SampleData.transactions[i].id,
                    familyGroupId: SampleData.transactions[i].familyGroupId,
                    createdByUserId: SampleData.transactions[i].createdByUserId,
                    categoryId: 'uncategorized',
                    amount: SampleData.transactions[i].amount,
                    currency: SampleData.transactions[i].currency,
                    merchant: SampleData.transactions[i].merchant,
                    description: SampleData.transactions[i].description,
                    type: SampleData.transactions[i].type,
                    sourceType: SampleData.transactions[i].sourceType,
                    sourceRawText: SampleData.transactions[i].sourceRawText,
                    matchedPatternId: SampleData.transactions[i].matchedPatternId,
                    notes: SampleData.transactions[i].notes,
                    transactionDate: SampleData.transactions[i].transactionDate,
                    createdAt: SampleData.transactions[i].createdAt,
                  );
                }
              }
              SampleData.categories.removeWhere((c) => c.id == category.id);

              Navigator.pop(ctx);
              ref
                  .read(budgetProvider.notifier)
                  .loadDashboard(SampleData.familyGroup.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${category.name} deleted')),
              );
            },
            child: Text(
              'Delete',
              style: GoogleFonts.inter(
                color: context.colors.accentCoral,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBudget = SampleData.monthlyBudgetLimit;
    final totalSpent = SampleData.totalSpent;
    final spentPercent = (totalSpent / totalBudget).clamp(0.0, 1.0);
    final isOver = totalSpent > totalBudget;

    final authState = ref.watch(authProvider);
    final user = authState.user;

    final currentMember = SampleData.members.firstWhere(
      (m) => m.userId == user?.id,
      orElse: () => SampleData.members.first,
    );
    final isAdmin = currentMember.isAdmin;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ──
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Budget Planning',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textMain,
                          ),
                        ),
                        if (isAdmin)
                          IconButton(
                            icon: Icon(
                              Icons.edit,
                              size: 20,
                              color: context.colors.textDim,
                            ),
                            onPressed: () =>
                                _showEditBudgetSheet(context, ref, totalBudget),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Overall Budget Card ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.colors.primary.withValues(alpha: 0.12),
                      context.colors.cardSurface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(
                    BudgetlyTheme.radiusCardLg,
                  ),
                  border: Border.all(
                    color: context.colors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    // Top row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OVERALL BUDGET',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textDim,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '₹${NumberFormat('#,##,###').format(totalBudget.toInt())}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textMain,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isOver
                                        ? context.colors.accentCoral
                                        : context.colors.accentMint)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              BudgetlyTheme.radiusPill,
                            ),
                          ),
                          child: Text(
                            '${(spentPercent * 100).toStringAsFixed(0)}% used',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isOver
                                  ? context.colors.accentCoral
                                  : context.colors.accentMint,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Progress bar
                    Stack(
                      children: [
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: context.colors.surfaceHighlight.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(
                              BudgetlyTheme.radiusPill,
                            ),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: spentPercent,
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isOver
                                    ? [
                                        context.colors.accentCoral,
                                        context.colors.accentCoralDark,
                                      ]
                                    : [
                                        context.colors.primary,
                                        context.colors.primaryLight,
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(
                                BudgetlyTheme.radiusPill,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isOver
                                              ? context.colors.accentCoral
                                              : context.colors.primary)
                                          .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12),

                    // Bottom row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${NumberFormat('#,##,###').format(totalSpent.toInt())} spent',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: context.colors.textMuted,
                          ),
                        ),
                        Text(
                          '₹${NumberFormat('#,##,###').format((totalBudget - totalSpent).abs().toInt())} ${isOver ? "over" : "remaining"}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isOver
                                ? context.colors.accentCoral
                                : context.colors.accentMint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Category Header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 12),
              child: Text(
                'BY CATEGORY',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textMuted,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          // ── Category Cards ──
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final cat = SampleData.categories[index];
                // Simulate spent amounts (decreasing proportion)
                final spent = [
                  22000.0,
                  13500.0,
                  9800.0,
                  95000.0,
                  16200.0,
                  4500.0,
                  9200.0,
                  11800.0,
                ][index];
                return _CategoryBudgetCard(
                  category: cat,
                  spent: spent,
                  isAdmin: isAdmin,
                  onEdit: () => _showEditCategorySheet(context, ref, cat),
                  onDelete: () => _showDeleteCategoryDialog(context, ref, cat),
                );
              }, childCount: SampleData.categories.length),
            ),
          ),

          // ── Add Category Button ──
          if (isAdmin)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: GestureDetector(
                  onTap: () => _showAddCategorySheet(context),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        BudgetlyTheme.radiusCard,
                      ),
                      border: Border.all(
                        color: context.colors.primary.withValues(alpha: 0.3),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 20,
                          color: context.colors.primary.withValues(alpha: 0.7),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Add Category',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.colors.primary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ─── Category Budget Card ───
class _CategoryBudgetCard extends StatelessWidget {
  final Category category;
  final double spent;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CategoryBudgetCard({
    required this.category,
    required this.spent,
    this.isAdmin = false,
    this.onEdit,
    this.onDelete,
  });

  double get budgetLimit => category.budgetLimit.toDouble();
  double get _percent =>
      budgetLimit > 0 ? (spent / budgetLimit).clamp(0.0, 1.0) : 0;
  bool get _isOver => spent > budgetLimit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
        border: Border.all(
          color: _isOver
              ? context.colors.accentCoral.withValues(alpha: 0.3)
              : context.colors.borderSubtle,
        ),
      ),
      child: Column(
        children: [
          // Top row
          Row(
            children: [
              Text(category.icon, style: TextStyle(fontSize: 22)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.name,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textMain,
                  ),
                ),
              ),
              if (isAdmin) ...[
                IconButton(
                  icon: Icon(
                    Icons.edit,
                    size: 16,
                    color: context.colors.textDim,
                  ),
                  onPressed: onEdit,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: context.colors.textDim,
                  ),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
                SizedBox(width: 12),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${NumberFormat('#,##,###').format(spent.toInt())}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _isOver
                          ? context.colors.accentCoral
                          : context.colors.textMain,
                    ),
                  ),
                  Text(
                    'of ₹${NumberFormat('#,##,###').format(budgetLimit.toInt())}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: context.colors.textDim,
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 12),

          // Progress bar
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: context.colors.surfaceHighlight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(BudgetlyTheme.radiusPill),
                ),
              ),
              FractionallySizedBox(
                widthFactor: _percent,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: _isOver
                        ? context.colors.accentCoral
                        : context.colors.primary,
                    borderRadius: BorderRadius.circular(
                      BudgetlyTheme.radiusPill,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_isOver) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 13,
                  color: context.colors.accentCoral,
                ),
                SizedBox(width: 4),
                Text(
                  'Over by ₹${NumberFormat('#,##,###').format((spent - budgetLimit).toInt())}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.colors.accentCoral,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
