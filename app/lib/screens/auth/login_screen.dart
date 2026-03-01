import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';

/// Login screen — Google OAuth 2.0 sign-in with premium dark branding.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Navigate to dashboard when authenticated
    ref.listen(authProvider, (prev, next) {
      if (next.isAuthenticated) {
        context.go(AppRoutes.dashboard);
      }
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E1B4B), // Deep indigo
              context.colors.background,
              context.colors.background,
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // ── Logo & Branding ──
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.colors.primary,
                        context.colors.primaryLight,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.primary.withValues(alpha: 0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                SizedBox(height: 24),

                Text(
                  'Budgetly',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textMain,
                    letterSpacing: -1,
                  ),
                ),
                SizedBox(height: 8),

                Text(
                  'Family Harmony Budget',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: context.colors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),

                const Spacer(flex: 1),

                // ── Feature Highlights ──
                _FeatureRow(
                  icon: Icons.people_outline,
                  text: 'Track shared family expenses',
                ),
                SizedBox(height: 16),
                _FeatureRow(
                  icon: Icons.sms_outlined,
                  text: 'AI-powered SMS parsing',
                ),
                SizedBox(height: 16),
                _FeatureRow(
                  icon: Icons.pie_chart_outline,
                  text: 'Monthly budget planning',
                ),

                const Spacer(flex: 2),

                // ── Google Sign-In Button ──
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: authState.status == AuthStatus.loading
                        ? null
                        : () => ref
                              .read(authProvider.notifier)
                              .signInWithGoogle(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1F1F1F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          BudgetlyTheme.radiusPill,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: authState.status == AuthStatus.loading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Google "G" icon
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'G',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4285F4),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Continue with Google',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1F1F1F),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                SizedBox(height: 16),

                // ── Error State ──
                if (authState.status == AuthStatus.error)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.colors.accentCoral.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        BudgetlyTheme.radiusMedium,
                      ),
                      border: Border.all(
                        color: context.colors.accentCoral.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: context.colors.accentCoral,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authState.errorMessage ?? 'Sign-in failed',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.colors.accentCoral),
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(flex: 1),

                // ── Footer ──
                Text(
                  'By continuing, you agree to our Terms & Privacy Policy',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: context.colors.textDim,
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: context.colors.primaryLight, size: 20),
        ),
        SizedBox(width: 14),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: context.colors.textMain,
          ),
        ),
      ],
    );
  }
}
