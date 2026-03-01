import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../models/family_member.dart';

/// Invite / Link Family — Share link, QR placeholder, role selector.
class LinkFamilyScreen extends StatefulWidget {
  const LinkFamilyScreen({super.key});

  @override
  State<LinkFamilyScreen> createState() => _LinkFamilyScreenState();
}

class _LinkFamilyScreenState extends State<LinkFamilyScreen> {
  MemberRole _selectedRole = MemberRole.member;
  bool _copied = false;

  static const _inviteLink = 'https://budgetly.app/join/sharma-family-abc123';

  void _copyLink() {
    Clipboard.setData(const ClipboardData(text: _inviteLink));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      'Invite Members',
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 32),

                    // Illustration
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.group_add,
                        size: 36,
                        color: context.colors.primaryLight,
                      ),
                    ),

                    SizedBox(height: 20),

                    Text(
                      'Invite your family',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textMain,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Share this link with family members\nto join your budget group',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: context.colors.textDim,
                        height: 1.5,
                      ),
                    ),

                    SizedBox(height: 32),

                    // ── Share Link Card ──
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
                            'INVITE LINK',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textDim,
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.background,
                              borderRadius: BorderRadius.circular(
                                BudgetlyTheme.radiusMedium,
                              ),
                            ),
                            child: Text(
                              _inviteLink,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                color: context.colors.primaryLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: _copyLink,
                              icon: Icon(
                                _copied ? Icons.check : Icons.copy,
                                size: 18,
                              ),
                              label: Text(
                                _copied ? 'Copied!' : 'Copy Link',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _copied
                                    ? context.colors.accentMint
                                    : context.colors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    BudgetlyTheme.radiusMedium,
                                  ),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // ── QR Code Placeholder ──
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: context.colors.cardSurface,
                        borderRadius: BorderRadius.circular(
                          BudgetlyTheme.radiusCard,
                        ),
                        border: Border.all(color: context.colors.borderSubtle),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                BudgetlyTheme.radiusMedium,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.qr_code_2,
                                size: 100,
                                color: context.colors.background,
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Scan to join',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: context.colors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // ── Default Role Selector ──
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
                            'DEFAULT ROLE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textDim,
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(height: 12),
                          _RoleOption(
                            role: MemberRole.member,
                            label: 'Member',
                            description: 'Can add expenses and view everything',
                            selected: _selectedRole == MemberRole.member,
                            onTap: () => setState(
                              () => _selectedRole = MemberRole.member,
                            ),
                          ),
                        ],
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

class _RoleOption extends StatelessWidget {
  final MemberRole role;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.role,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.primary.withValues(alpha: 0.08)
              : context.colors.background,
          borderRadius: BorderRadius.circular(BudgetlyTheme.radiusMedium),
          border: Border.all(
            color: selected
                ? context.colors.primary.withValues(alpha: 0.3)
                : context.colors.surfaceHighlight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? context.colors.primary
                      : context.colors.textDim,
                  width: 2,
                ),
                color: selected ? context.colors.primary : Colors.transparent,
              ),
              child: selected
                  ? Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textMain,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.colors.textDim,
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
