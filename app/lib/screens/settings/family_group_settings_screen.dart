import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/family_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';

/// Family Management — Member list with role badges, invite button.
class FamilyGroupSettingsScreen extends ConsumerWidget {
  const FamilyGroupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyState = ref.watch(familyProvider);
    final members = familyState.members;
    final familyGroup = familyState.currentFamily;

    final authState = ref.watch(authProvider);
    final currentUser = authState.user;
    // Only admins may rename the family (backend enforces this too).
    final isAdmin = members.any(
      (m) => m.userId == currentUser?.id && m.isAdmin,
    );

    if (familyGroup == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: context.colors.primary),
        ),
      );
    }

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
                      'Family Group',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textMain,
                      ),
                    ),
                  ),
                  if (isAdmin)
                    IconButton(
                      onPressed: () => _showEditFamilyNameDialog(
                        context,
                        ref,
                        familyGroup.name,
                      ),
                      icon: Icon(
                        Icons.edit_outlined,
                        color: context.colors.textMuted,
                        size: 20,
                      ),
                    )
                  else
                    // Keep the header symmetric so the title stays centered
                    // for non-admin members, who can't rename the family.
                    const SizedBox(width: 48),
                ],
              ),
            ),

            SizedBox(height: 16),

            // ── Family Name ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.colors.primary.withValues(alpha: 0.1),
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
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.home_outlined,
                        color: context.colors.primaryLight,
                        size: 28,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      familyGroup.name,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textMain,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${members.length} members',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: context.colors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Section header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MEMBERS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    '${members.length}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),

            // ── Member List ──
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 20),
                itemCount: members.length,
                separatorBuilder: (_, _) => SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final member = members[index];
                  return _MemberCard(member: member);
                },
              ),
            ),

            // ── Invite Button ──
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.linkFamily),
                  icon: Icon(Icons.person_add, size: 20),
                  label: Text(
                    'Invite Member',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Prompts an admin to rename the family group.
  /// Mirrors the backend's admin-only `PUT /families/{id}` rule.
  Future<void> _showEditFamilyNameDialog(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.cardSurface,
        title: Text(
          'Edit Family Name',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.colors.textMain,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.inter(color: context.colors.textMain),
          decoration: InputDecoration(
            hintText: 'e.g. Sharma Family',
            hintStyle: GoogleFonts.inter(color: context.colors.textMuted),
            filled: true,
            fillColor: context.colors.surfaceHighlight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BudgetlyTheme.radiusMedium),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
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
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                color: context.colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentName) return;

    await ref.read(familyProvider.notifier).updateSettings({'name': newName});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Family name updated to "$newName"')),
      );
    }
  }
}

class _MemberCard extends StatelessWidget {
  final FamilyMember member;
  const _MemberCard({required this.member});

  Color _roleColor(BuildContext context) {
    switch (member.role) {
      case MemberRole.admin:
        return context.colors.primary;
      case MemberRole.member:
        return context.colors.accentMint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _roleColor(context).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                member.user?.displayName.isNotEmpty == true
                    ? member.user!.displayName[0].toUpperCase()
                    : '?',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _roleColor(context),
                ),
              ),
            ),
          ),
          SizedBox(width: 14),

          // Name + role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.user?.displayName ?? 'Unknown',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textMain,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  member.user?.email ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.colors.textDim,
                  ),
                ),
              ],
            ),
          ),

          // Role badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _roleColor(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(BudgetlyTheme.radiusPill),
            ),
            child: Text(
              member.roleLabel,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _roleColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
