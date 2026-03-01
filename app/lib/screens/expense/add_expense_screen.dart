import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/transaction.dart';

import '../../providers/transaction_provider.dart';
import '../../data/mock/sample_data.dart';

/// Add Expense screen — Amount input, payer, category.
class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  String _selectedCategoryId = 'cat_001';
  String _selectedPayerId = 'user_001';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  String get _selectedCategoryName {
    final cat = SampleData.categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => SampleData.categories.first,
    );
    return cat.name;
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    setState(() => _isSaving = true);

    final txn = Transaction(
      id: 'txn_new_${DateTime.now().millisecondsSinceEpoch}',
      familyGroupId: 'family_001',
      createdByUserId: _selectedPayerId,
      categoryId: _selectedCategoryId,
      amount: amount,
      merchant: _merchantController.text.isNotEmpty
          ? _merchantController.text
          : 'Unknown',
      type: TransactionType.expense,

      transactionDate: _selectedDate,
      createdAt: DateTime.now(),
    );

    await ref.read(transactionProvider.notifier).addTransaction(txn);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
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
                    icon: Icon(Icons.close, color: context.colors.textMuted),
                  ),
                  Text(
                    'Add Expense',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textMain,
                    ),
                  ),
                  TextButton(
                    onPressed: _isSaving ? null : _save,
                    child: Text(
                      'Save',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ──
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Amount input
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            '₹',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: context.colors.primary,
                            ),
                          ),
                        ),
                        SizedBox(width: 4),
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _amountController,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.]'),
                              ),
                            ],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 52,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textMain,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '0',
                              hintStyle: GoogleFonts.jetBrainsMono(
                                fontSize: 52,
                                fontWeight: FontWeight.w700,
                                color: context.colors.surfaceHighlight,
                              ),
                              filled: false,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Category label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.label_outline,
                        size: 14,
                        color: context.colors.textMuted,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Categorized as ',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: context.colors.textMuted,
                        ),
                      ),
                      Text(
                        _selectedCategoryName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textMain,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 28),

                  // ── Paid By ──
                  _FieldLabel('PAID BY'),
                  Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: context.colors.cardSurface,
                      borderRadius: BorderRadius.circular(
                        BudgetlyTheme.radiusPill,
                      ),
                      border: Border.all(
                        color: context.colors.surfaceHighlight.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: SampleData.members.map((member) {
                        final isSelected = _selectedPayerId == member.userId;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _selectedPayerId = member.userId,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? context.colors.surfaceHighlight
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  BudgetlyTheme.radiusPill,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 20,
                                    color: isSelected
                                        ? context.colors.textMain
                                        : context.colors.textMuted,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    member.user?.displayName.split(' ').first ??
                                        'User',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? context.colors.textMain
                                          : context.colors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  SizedBox(height: 28),

                  // ── Merchant ──
                  _FieldLabel('MERCHANT / DESCRIPTION'),
                  Container(
                    decoration: BoxDecoration(
                      color: context.colors.cardSurface,
                      borderRadius: BorderRadius.circular(
                        BudgetlyTheme.radiusMedium,
                      ),
                      border: Border.all(
                        color: context.colors.surfaceHighlight.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.store,
                          color: context.colors.textDim,
                          size: 22,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _merchantController,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: context.colors.textMain,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: 'e.g. Starbucks, Amazon',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 16,
                                color: context.colors.textDim.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              filled: false,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // ── Category Picker ──
                  _FieldLabel('SELECT CATEGORY'),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: SampleData.categories.length,
                      separatorBuilder: (_, _) => SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final cat = SampleData.categories[index];
                        final isSelected = cat.id == _selectedCategoryId;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategoryId = cat.id),
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? context.colors.primary
                                      : context.colors.cardSurface,
                                  borderRadius: BorderRadius.circular(
                                    BudgetlyTheme.radiusCard,
                                  ),
                                  border: isSelected
                                      ? null
                                      : Border.all(
                                          color:
                                              context.colors.surfaceHighlight,
                                        ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: context.colors.primary
                                                .withValues(alpha: 0.2),
                                            blurRadius: 12,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    cat.icon,
                                    style: TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                cat.name,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? context.colors.textMain
                                      : context.colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 24),

                  // ── Date ──
                  _FieldLabel('DATE'),
                  _SelectorButton(
                    label: _selectedDate.day == DateTime.now().day
                        ? 'Today'
                        : DateFormat('MMM d').format(_selectedDate),
                    icon: Icons.calendar_today,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _selectedDate = date);
                      }
                    },
                  ),

                  SizedBox(height: 32),

                  // ── CTA ──
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            BudgetlyTheme.radiusMedium,
                          ),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'Add Expense',
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Small helpers ───
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: context.colors.textMuted,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SelectorButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SelectorButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.cardSurface,
          borderRadius: BorderRadius.circular(BudgetlyTheme.radiusMedium),
          border: Border.all(
            color: context.colors.surfaceHighlight.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textMain,
              ),
            ),
            Icon(icon, size: 18, color: context.colors.textDim),
          ],
        ),
      ),
    );
  }
}
