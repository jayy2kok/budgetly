import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../data/mock/sample_data.dart';
import '../../providers/theme_provider.dart';
import '../../providers/sms_provider.dart';

/// Settings screen — Profile card, grouped settings, SMS & Parsing, sign out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final currentMode = ref.read(themeModeProvider);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.colors.cardSurface,
          title: Text(
            'Choose Theme',
            style: GoogleFonts.ibmPlexSans(
              color: context.colors.textMain,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values.map((mode) {
              return ListTile(
                title: Text(
                  mode.name.capitalize(),
                  style: GoogleFonts.inter(color: context.colors.textMain),
                ),
                leading: Radio<ThemeMode>(
                  value: mode,
                  // ignore: deprecated_member_use
                  groupValue: currentMode,
                  activeColor: context.colors.primary,
                  // ignore: deprecated_member_use
                  onChanged: (ThemeMode? newMode) {
                    if (newMode != null) {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(newMode);
                    }
                    context.pop(); // Close dialog
                  },
                ),
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  context.pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final smsState = ref.watch(smsProvider);

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
                child: Text(
                  'Settings',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textMain,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
          ),

          // ── Profile Card ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.primary.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          user?.displayName.isNotEmpty == true
                              ? user!.displayName[0].toUpperCase()
                              : 'A',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Arjun Sharma',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textMain,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            user?.email ?? 'arjun@budgetly.app',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: context.colors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: context.colors.textDim),
                  ],
                ),
              ),
            ),
          ),

          // ── General ──
          _SectionHeader('GENERAL'),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.palette_outlined,
                label: 'Appearance',
                onTap: () => _showThemeDialog(context, ref),
                trailing: Text(
                  ref.watch(themeModeProvider).name.capitalize(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.textDim,
                  ),
                ),
              ),
              _SettingsRow(
                icon: Icons.currency_rupee,
                label: 'Currency',
                trailing: Text(
                  '₹ INR',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.textDim,
                  ),
                ),
              ),
              _SettingsRow(
                icon: Icons.language,
                label: 'Language',
                trailing: Text(
                  'English',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.textDim,
                  ),
                ),
              ),
              _SettingsRow(
                icon: Icons.mark_email_read_outlined,
                label: 'Ignored Messages',
                onTap: () => context.push(AppRoutes.ignoredMessages),
              ),
            ],
          ),

          // ── SMS & Parsing ──
          _SectionHeader('SMS & PARSING'),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.sms_outlined,
                label: 'SMS Permission',
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: smsState.smsPermissionGranted
                        ? context.colors.accentMint.withValues(alpha: 0.15)
                        : context.colors.accentCoral.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    smsState.smsPermissionGranted ? 'Granted' : 'Denied',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: smsState.smsPermissionGranted
                          ? context.colors.accentMint
                          : context.colors.accentCoral,
                    ),
                  ),
                ),
                onTap: smsState.smsPermissionGranted
                    ? null
                    : () =>
                        ref.read(smsProvider.notifier).requestPermission(),
              ),
              _SettingsToggle(
                icon: Icons.play_circle_outline,
                label: 'Background Service',
                value: smsState.backgroundServiceEnabled,
                onChanged: (_) =>
                    ref.read(smsProvider.notifier).toggleBackgroundService(),
              ),
              _SettingsRow(
                icon: Icons.pattern,
                label: 'Cached Patterns',
                trailing: Text(
                  '${smsState.cachedPatternCount} patterns',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.textDim,
                  ),
                ),
              ),
              _SettingsRow(
                icon: Icons.schedule,
                label: 'Last Synced',
                trailing: Text(
                  smsState.lastSyncLabel,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.textDim,
                  ),
                ),
              ),
              _SettingsRow(
                icon: Icons.refresh,
                label: 'Refresh Patterns',
                trailing: smsState.isRefreshing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.primary,
                        ),
                      )
                    : null,
                onTap: smsState.isRefreshing
                    ? null
                    : () =>
                        ref.read(smsProvider.notifier).refreshPatterns(),
              ),
            ],
          ),

          // ── Family ──
          _SectionHeader('FAMILY'),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.group_outlined,
                label: 'Family Members',
                trailing: Text(
                  '${SampleData.members.length} members',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.textDim,
                  ),
                ),
                onTap: () => context.push(AppRoutes.familySettings),
              ),
              if (isAdmin) ...[
                _SettingsRow(
                  icon: Icons.person_add_outlined,
                  label: 'Invite Members',
                  onTap: () => context.push(AppRoutes.linkFamily),
                ),
                _SettingsRow(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Permissions',
                ),
              ],
            ],
          ),

          // ── Notifications ──
          _SectionHeader('NOTIFICATIONS'),
          _SettingsGroup(
            children: [
              _SettingsToggle(
                icon: Icons.notifications_outlined,
                label: 'Push Notifications',
                value: true,
              ),
              _SettingsToggle(
                icon: Icons.email_outlined,
                label: 'Email Reports',
                value: false,
              ),
              _SettingsToggle(
                icon: Icons.warning_amber_outlined,
                label: 'Budget Alerts',
                value: true,
              ),
            ],
          ),

          // ── About ──
          _SectionHeader('ABOUT'),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.info_outline,
                label: 'Version',
                trailing: Text(
                  '1.0.0 (Phase 3)',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.colors.textDim,
                  ),
                ),
              ),
              _SettingsRow(
                icon: Icons.description_outlined,
                label: 'Privacy Policy',
              ),
              _SettingsRow(
                icon: Icons.gavel_outlined,
                label: 'Terms of Service',
              ),
            ],
          ),

          // ── Sign Out ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: SizedBox(
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
                      color:
                          context.colors.accentCoral.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        BudgetlyTheme.radiusMedium,
                      ),
                    ),
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

// ─── Helpers ───

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 28, 24, 10),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: context.colors.textMuted,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            color: context.colors.cardSurface,
            borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
            border: Border.all(color: context.colors.borderSubtle),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    indent: 52,
                    color:
                        context.colors.borderSubtle.withValues(alpha: 0.5),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.colors.textMuted),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textMain,
                ),
              ),
            ),
            if (trailing != null) ...[trailing!, SizedBox(width: 6)],
            Icon(
              Icons.chevron_right,
              size: 18,
              color: context.colors.textDim.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsToggle extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SettingsToggle({
    required this.icon,
    required this.label,
    required this.value,
    this.onChanged,
  });

  @override
  State<_SettingsToggle> createState() => _SettingsToggleState();
}

class _SettingsToggleState extends State<_SettingsToggle> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant _SettingsToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(widget.icon, size: 20, color: context.colors.textMuted),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: context.colors.textMain,
              ),
            ),
          ),
          Switch(
            value: _value,
            onChanged: (v) {
              setState(() => _value = v);
              widget.onChanged?.call(v);
            },
            activeThumbColor: context.colors.primary,
            activeTrackColor:
                context.colors.primary.withValues(alpha: 0.3),
            inactiveTrackColor: context.colors.surfaceHighlight,
            inactiveThumbColor: context.colors.textDim,
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
