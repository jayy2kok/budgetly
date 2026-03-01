import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'budgetly_colors.dart';

// ─── Re-export colors to keep old imports working where possible ───
export 'budgetly_colors.dart';

/// Budgetly Design System — Dark theme based on Stitch screen designs.
///
/// Color palette: Slate (backgrounds), Indigo (primary), Emerald (positive),
/// Rose (negative/alerts). Typography: Inter (body), IBM Plex Sans (display).
class BudgetlyTheme {
  BudgetlyTheme._();

  // ─── Background & Surface ───
  static const Color background = Color(0xFF020617); // Slate 950
  static const Color backgroundAlt = Color(0xFF0F172A); // Slate 900
  static const Color cardSurface = Color(0xFF1E293B); // Slate 800
  static const Color surfaceHighlight = Color(0xFF334155); // Slate 700

  // ─── Primary ───
  static const Color primary = Color(0xFF6366F1); // Indigo 500
  static const Color primaryDark = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryLight = Color(0xFF818CF8); // Indigo 400

  // ─── Accents ───
  static const Color accentMint = Color(0xFF34D399); // Emerald 400
  static const Color accentMintDark = Color(0xFF10B981); // Emerald 500
  static const Color accentCoral = Color(0xFFFB7185); // Rose 400
  static const Color accentCoralDark = Color(0xFFF43F5E); // Rose 500

  // ─── Text ───
  static const Color textMain = Color(0xFFF8FAFC); // Slate 50
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color textDim = Color(0xFF64748B); // Slate 500

  // ─── Borders ───
  static const Color borderSubtle = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const Color borderLight = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)

  // ─── Radius ───
  static const double radiusCard = 16.0;
  static const double radiusCardLg = 20.0;
  static const double radiusPill = 100.0;
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;

  // ─── Category Colors ───
  static const Color categoryGroceries = Color(0xFF34D399);
  static const Color categoryDining = Color(0xFFFB7185);
  static const Color categoryTransport = Color(0xFF60A5FA);
  static const Color categoryHousing = Color(0xFFFBBF24);
  static const Color categoryBills = Color(0xFFA78BFA);
  static const Color categoryHealth = Color(0xFF2DD4BF);
  static const Color categoryEntertainment = Color(0xFFF472B6);
  static const Color categoryShopping = Color(0xFFFB923C);

  /// Build the full dark [ThemeData] for the app.
  static ThemeData darkTheme() =>
      _buildTheme(Brightness.dark, BudgetlyColors.dark);

  /// Build the full light [ThemeData] for the app.
  static ThemeData lightTheme() =>
      _buildTheme(Brightness.light, BudgetlyColors.light);

  static ThemeData _buildTheme(Brightness brightness, BudgetlyColors colors) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.primary,
        onPrimary: colors.textMain,
        secondary: colors.accentMint,
        onSecondary: colors.background,
        surface: colors.cardSurface,
        onSurface: colors.textMain,
        error: colors.accentCoral,
        onError: colors.textMain,
      ),
      extensions: [colors],
      textTheme: _buildTextTheme(colors),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textMain,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.textMain),
      ),
      iconTheme: IconThemeData(color: colors.textMain, size: 24),
      cardTheme: CardThemeData(
        color: colors.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: colors.borderSubtle),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.backgroundAlt,
        indicatorColor: colors.primary.withValues(alpha: 0.15),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: colors.textMuted),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.textMain,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceHighlight,
        selectedColor: colors.primary.withValues(alpha: 0.2),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colors.textMain,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        side: BorderSide(color: colors.borderSubtle),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceHighlight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colors.primary),
        ),
        labelStyle: GoogleFonts.inter(color: colors.textMuted),
        hintStyle: GoogleFonts.inter(color: colors.textDim),
      ),
      dividerTheme: DividerThemeData(color: colors.borderSubtle, thickness: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  static TextTheme _buildTextTheme(BudgetlyColors colors) {
    return TextTheme(
      // Display — IBM Plex Sans
      displayLarge: GoogleFonts.ibmPlexSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: colors.textMain,
      ),
      displayMedium: GoogleFonts.ibmPlexSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: colors.textMain,
      ),
      displaySmall: GoogleFonts.ibmPlexSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: colors.textMain,
      ),
      // Headlines — IBM Plex Sans
      headlineLarge: GoogleFonts.ibmPlexSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: colors.textMain,
      ),
      headlineMedium: GoogleFonts.ibmPlexSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colors.textMain,
      ),
      headlineSmall: GoogleFonts.ibmPlexSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colors.textMain,
      ),
      // Titles — Inter
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colors.textMain,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors.textMain,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colors.textMain,
      ),
      // Body — Inter
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: colors.textMain,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.textMain,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.textMuted,
      ),
      // Labels — Inter
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.textMain,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: colors.textMuted,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: colors.textMuted,
      ),
    );
  }
}
