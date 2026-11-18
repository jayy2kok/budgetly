import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_providers.dart';

/// Login screen — Google OAuth 2.0 sign-in with premium dark branding.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// Server / Web Client ID from Google Cloud Console.
  /// Used by google_sign_in v7 to obtain an ID token that the Spring Boot
  /// backend can verify with Google's tokeninfo endpoint.
  static const _serverClientId =
      '855687685081-5pfm3c76mlekvd15hvuoscbc6itao147.apps.googleusercontent.com';

  bool _isSigningIn = false;

  /// Runs the Google Sign-In flow and passes the ID token to [AuthNotifier].
  Future<void> _handleSignIn() async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);

    try {
      if (useRealApi) {
        // ── Real API mode: google_sign_in v7 interactive flow ────────────
        final signIn = GoogleSignIn.instance;

        // Initialize with the Web Client ID so the backend can verify the token.
        await signIn.initialize(serverClientId: _serverClientId);

        // Show the Google account picker.
        // TODO: add attemptLightweightAuthentication() for silent sign-in
        //       once the base interactive flow is confirmed working.
        final account = await signIn.authenticate(
          scopeHint: ['email', 'profile'],
        );
        final auth = account.authentication;
        final idToken = auth.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw Exception(
            'Google did not return an ID token. '
            'Ensure the serverClientId matches the Web Client ID in '
            'Google Cloud Console → APIs & Services → Credentials.',
          );
        }

        await ref
            .read(authProvider.notifier)
            .signInWithGoogle(overrideIdToken: idToken);
      } else {
        // ── Mock mode: skip Google and use mock credentials ───────────────
        await ref.read(authProvider.notifier).signInWithGoogle();
      }
    } catch (e, stackTrace) {
      // Google Sign-In throws (canceled, Play Services missing, OAuth client
      // misconfigured, ...). Without this the button appears to do nothing.
      debugPrint('❌ Google sign-in failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-in failed: $e'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  /// Shows the in-app Terms & Privacy Policy summary.
  void _showLegalSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
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
                'Terms & Privacy Policy',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textMain,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Terms of Service',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textMain,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Budgetly lets you and your family track shared expenses. '
                'By continuing, you agree to use the app for lawful, personal '
                'family budgeting and to keep your family group’s data private. '
                'The service is provided as-is during development.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: context.colors.textMuted,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Privacy Policy',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textMain,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Budgetly stores family profiles, transactions, and — with your '
                'permission — SMS messages in order to detect expenses. Your '
                'information is shown to your family group to power shared '
                'budgets and is never sold to third parties. You can sign out '
                'or request data deletion at any time.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: context.colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Navigate to dashboard when authenticated
    ref.listen(authProvider, (prev, next) {
      if (next.isAuthenticated) {
        context.go(AppRoutes.dashboard);
      }
    });

    final bool showLoading =
        _isSigningIn || authState.status == AuthStatus.loading;

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
                    onPressed: showLoading ? null : _handleSignIn,
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
                    child: showLoading
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
                GestureDetector(
                  onTap: _showLegalSheet,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text.rich(
                      TextSpan(
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: context.colors.textDim,
                        ),
                        children: [
                          TextSpan(text: 'By continuing, you agree to our '),
                          TextSpan(
                            text: 'Terms & Privacy Policy',
                            style: TextStyle(
                              color: context.colors.primaryLight,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: context.colors.primaryLight
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
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
