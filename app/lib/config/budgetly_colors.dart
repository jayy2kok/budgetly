import 'package:flutter/material.dart';

class BudgetlyColors extends ThemeExtension<BudgetlyColors> {
  final Color background;
  final Color backgroundAlt;
  final Color cardSurface;
  final Color surfaceHighlight;

  final Color primary;
  final Color primaryDark;
  final Color primaryLight;

  final Color accentMint;
  final Color accentMintDark;
  final Color accentCoral;
  final Color accentCoralDark;

  final Color textMain;
  final Color textMuted;
  final Color textDim;

  final Color borderSubtle;
  final Color borderLight;

  final Color categoryGroceries;
  final Color categoryDining;
  final Color categoryTransport;
  final Color categoryHousing;
  final Color categoryBills;
  final Color categoryHealth;
  final Color categoryEntertainment;
  final Color categoryShopping;

  const BudgetlyColors({
    required this.background,
    required this.backgroundAlt,
    required this.cardSurface,
    required this.surfaceHighlight,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accentMint,
    required this.accentMintDark,
    required this.accentCoral,
    required this.accentCoralDark,
    required this.textMain,
    required this.textMuted,
    required this.textDim,
    required this.borderSubtle,
    required this.borderLight,
    required this.categoryGroceries,
    required this.categoryDining,
    required this.categoryTransport,
    required this.categoryHousing,
    required this.categoryBills,
    required this.categoryHealth,
    required this.categoryEntertainment,
    required this.categoryShopping,
  });

  @override
  BudgetlyColors copyWith({
    Color? background,
    Color? backgroundAlt,
    Color? cardSurface,
    Color? surfaceHighlight,
    Color? primary,
    Color? primaryDark,
    Color? primaryLight,
    Color? accentMint,
    Color? accentMintDark,
    Color? accentCoral,
    Color? accentCoralDark,
    Color? textMain,
    Color? textMuted,
    Color? textDim,
    Color? borderSubtle,
    Color? borderLight,
    Color? categoryGroceries,
    Color? categoryDining,
    Color? categoryTransport,
    Color? categoryHousing,
    Color? categoryBills,
    Color? categoryHealth,
    Color? categoryEntertainment,
    Color? categoryShopping,
  }) {
    return BudgetlyColors(
      background: background ?? this.background,
      backgroundAlt: backgroundAlt ?? this.backgroundAlt,
      cardSurface: cardSurface ?? this.cardSurface,
      surfaceHighlight: surfaceHighlight ?? this.surfaceHighlight,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      accentMint: accentMint ?? this.accentMint,
      accentMintDark: accentMintDark ?? this.accentMintDark,
      accentCoral: accentCoral ?? this.accentCoral,
      accentCoralDark: accentCoralDark ?? this.accentCoralDark,
      textMain: textMain ?? this.textMain,
      textMuted: textMuted ?? this.textMuted,
      textDim: textDim ?? this.textDim,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderLight: borderLight ?? this.borderLight,
      categoryGroceries: categoryGroceries ?? this.categoryGroceries,
      categoryDining: categoryDining ?? this.categoryDining,
      categoryTransport: categoryTransport ?? this.categoryTransport,
      categoryHousing: categoryHousing ?? this.categoryHousing,
      categoryBills: categoryBills ?? this.categoryBills,
      categoryHealth: categoryHealth ?? this.categoryHealth,
      categoryEntertainment:
          categoryEntertainment ?? this.categoryEntertainment,
      categoryShopping: categoryShopping ?? this.categoryShopping,
    );
  }

  @override
  BudgetlyColors lerp(ThemeExtension<BudgetlyColors>? other, double t) {
    if (other is! BudgetlyColors) return this;
    return BudgetlyColors(
      background: Color.lerp(background, other.background, t)!,
      backgroundAlt: Color.lerp(backgroundAlt, other.backgroundAlt, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      surfaceHighlight: Color.lerp(
        surfaceHighlight,
        other.surfaceHighlight,
        t,
      )!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      accentMint: Color.lerp(accentMint, other.accentMint, t)!,
      accentMintDark: Color.lerp(accentMintDark, other.accentMintDark, t)!,
      accentCoral: Color.lerp(accentCoral, other.accentCoral, t)!,
      accentCoralDark: Color.lerp(accentCoralDark, other.accentCoralDark, t)!,
      textMain: Color.lerp(textMain, other.textMain, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
      categoryGroceries: Color.lerp(
        categoryGroceries,
        other.categoryGroceries,
        t,
      )!,
      categoryDining: Color.lerp(categoryDining, other.categoryDining, t)!,
      categoryTransport: Color.lerp(
        categoryTransport,
        other.categoryTransport,
        t,
      )!,
      categoryHousing: Color.lerp(categoryHousing, other.categoryHousing, t)!,
      categoryBills: Color.lerp(categoryBills, other.categoryBills, t)!,
      categoryHealth: Color.lerp(categoryHealth, other.categoryHealth, t)!,
      categoryEntertainment: Color.lerp(
        categoryEntertainment,
        other.categoryEntertainment,
        t,
      )!,
      categoryShopping: Color.lerp(
        categoryShopping,
        other.categoryShopping,
        t,
      )!,
    );
  }

  static const dark = BudgetlyColors(
    background: Color(0xFF020617),
    backgroundAlt: Color(0xFF0F172A),
    cardSurface: Color(0xFF1E293B),
    surfaceHighlight: Color(0xFF334155),
    primary: Color(0xFF6366F1),
    primaryDark: Color(0xFF4F46E5),
    primaryLight: Color(0xFF818CF8),
    accentMint: Color(0xFF34D399),
    accentMintDark: Color(0xFF10B981),
    accentCoral: Color(0xFFFB7185),
    accentCoralDark: Color(0xFFF43F5E),
    textMain: Color(0xFFF8FAFC),
    textMuted: Color(0xFF94A3B8),
    textDim: Color(0xFF64748B),
    borderSubtle: Color(0x0FFFFFFF),
    borderLight: Color(0x1AFFFFFF),
    categoryGroceries: Color(0xFF34D399),
    categoryDining: Color(0xFFFB7185),
    categoryTransport: Color(0xFF60A5FA),
    categoryHousing: Color(0xFFFBBF24),
    categoryBills: Color(0xFFA78BFA),
    categoryHealth: Color(0xFF2DD4BF),
    categoryEntertainment: Color(0xFFF472B6),
    categoryShopping: Color(0xFFFB923C),
  );

  static const light = BudgetlyColors(
    background: Color(0xFFF8FAFC),
    backgroundAlt: Color(0xFFF1F5F9),
    cardSurface: Color(0xFFFFFFFF),
    surfaceHighlight: Color(0xFFE2E8F0),
    primary: Color(0xFF4F46E5),
    primaryDark: Color(0xFF4338CA),
    primaryLight: Color(0xFF6366F1),
    accentMint: Color(0xFF10B981),
    accentMintDark: Color(0xFF059669),
    accentCoral: Color(0xFFF43F5E),
    accentCoralDark: Color(0xFFE11D48),
    textMain: Color(0xFF0F172A),
    textMuted: Color(0xFF475569),
    textDim: Color(0xFF64748B),
    borderSubtle: Color(0x0F000000),
    borderLight: Color(0x1A000000),
    categoryGroceries: Color(0xFF10B981),
    categoryDining: Color(0xFFF43F5E),
    categoryTransport: Color(0xFF3B82F6),
    categoryHousing: Color(0xFFF59E0B),
    categoryBills: Color(0xFF8B5CF6),
    categoryHealth: Color(0xFF14B8A6),
    categoryEntertainment: Color(0xFFEC4899),
    categoryShopping: Color(0xFFF97316),
  );
}

extension BuildContextThemeExtension on BuildContext {
  BudgetlyColors get colors => Theme.of(this).extension<BudgetlyColors>()!;
}
