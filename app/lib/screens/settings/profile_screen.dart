import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';

/// Profile screen — Avatar, name, email, sign out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: context.colors.textMuted,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Profile',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textMain,
                      ),
                    ),
                  ),
                  SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SizedBox(height: 32),

                    // ── Avatar ──
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: context.colors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.primary.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              user?.displayName.isNotEmpty == true
                                  ? user!.displayName[0].toUpperCase()
                                  : 'A',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: context.colors.cardSurface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.colors.borderSubtle,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 28),

                    // ── Name Field ──
                    _ProfileField(
                      label: 'DISPLAY NAME',
                      value: user?.displayName ?? 'Arjun Sharma',
                      icon: Icons.person_outline,
                    ),
                    SizedBox(height: 16),

                    // ── Email ──
                    _ProfileField(
                      label: 'EMAIL',
                      value: user?.email ?? 'arjun@budgetly.app',
                      icon: Icons.email_outlined,
                    ),
                    SizedBox(height: 16),

                    // ── Phone ──
                    _ProfileField(
                      label: 'PHONE',
                      value: '+91 98765 43210',
                      icon: Icons.phone_outlined,
                    ),
                    SizedBox(height: 16),

                    // ── Linked Account ──
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.cardSurface,
                        borderRadius: BorderRadius.circular(
                          BudgetlyTheme.radiusCard,
                        ),
                        border: Border.all(color: context.colors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LINKED ACCOUNTS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textDim,
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    BudgetlyTheme.radiusSmall,
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'G',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4285F4),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Google',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: context.colors.textMain,
                                      ),
                                    ),
                                    Text(
                                      user?.email ?? 'arjun@gmail.com',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: context.colors.textDim,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.accentMint.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    BudgetlyTheme.radiusPill,
                                  ),
                                ),
                                child: Text(
                                  'Connected',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.accentMint,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32),

                    // ── Sign Out ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ref.read(authProvider.notifier).signOut();
                          context.go(AppRoutes.login);
                        },
                        icon: Icon(Icons.logout, size: 20),
                        label: Text(
                          'Sign Out',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.colors.accentCoral,
                          side: BorderSide(
                            color: context.colors.accentCoral.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              BudgetlyTheme.radiusMedium,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Delete text
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'Delete Account',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: context.colors.accentCoral.withValues(
                            alpha: 0.7,
                          ),
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
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.colors.textDim,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, size: 18, color: context.colors.textMuted),
              SizedBox(width: 10),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textMain,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
