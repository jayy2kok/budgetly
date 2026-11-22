import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/sms_pattern.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/pattern_registry_provider.dart';

/// Pattern Registry — every pattern visible to the caller's family (globals and
/// family-authored), with Edit and Disable/Enable. Patterns are authored from a
/// non-transaction message, not from here.
class PatternRegistryScreen extends ConsumerStatefulWidget {
  const PatternRegistryScreen({super.key});

  @override
  ConsumerState<PatternRegistryScreen> createState() =>
      _PatternRegistryScreenState();
}

class _PatternRegistryScreenState extends ConsumerState<PatternRegistryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(patternRegistryProvider.notifier).load();
    });
  }

  /// Disables a pattern. A GLOBAL becomes hidden for this family only; a FAMILY
  /// pattern becomes inactive.
  Future<void> _disable(SmsPattern pattern) async {
    try {
      await ref.read(patternRegistryProvider.notifier).disablePattern(pattern.id);
      if (!mounted) return;
      _snack(_disableMessage(pattern));
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    }
  }

  Future<void> _enable(SmsPattern pattern) async {
    try {
      await ref
          .read(patternRegistryProvider.notifier)
          .enablePattern(pattern.id);
      if (!mounted) return;
      _snack('Pattern enabled');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    }
  }

  String _disableMessage(SmsPattern pattern) =>
      pattern.scope == PatternScope.global
          ? 'Pattern hidden for your family'
          : 'Pattern disabled';

  /// Promotes a family pattern to the global registry. Family-specific fixed
  /// values (e.g. "Pan Shop") are stripped by the server, so warn before
  /// promoting a pattern that pins any.
  Future<void> _promote(SmsPattern pattern) async {
    final confirm = await _confirmPromote(pattern);
    if (confirm != true || !mounted) return;
    try {
      await ref
          .read(patternRegistryProvider.notifier)
          .promotePattern(pattern.id);
      if (!mounted) return;
      _snack('"${pattern.sender}" pattern is now global');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    }
  }

  Future<bool?> _confirmPromote(SmsPattern pattern) async {
    final dropsFixedValues = pattern.fixedValues.isNotEmpty;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
        ),
        title: Text(
          'Promote to global?',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.colors.textMain,
          ),
        ),
        content: Text(
          dropsFixedValues
              ? 'This pattern will be shared with all families. Its fixed '
                  'values (${pattern.fixedValues.values.join(', ')}) are '
                  'family-specific and will not be carried over.'
              : 'This pattern will be shared with every family.',
          style: GoogleFonts.inter(fontSize: 13, color: context.colors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: context.colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Promote',
              style: GoogleFonts.inter(
                color: context.colors.primaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.inter())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patternRegistryProvider);
    final userId = ref.watch(authProvider).user?.id ?? '';
    final members = ref.watch(familyProvider).members;
    final isAdmin = members.any((m) => m.userId == userId && m.isAdmin);

    // Group patterns by sender for a compact, scannable list.
    final bySender = <String, List<SmsPattern>>{};
    for (final p in state.patterns) {
      bySender.putIfAbsent(p.sender, () => []).add(p);
    }
    final senders = bySender.keys.toList()..sort();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Pattern Registry',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textMain,
                          ),
                        ),
                        Text(
                          '${state.patterns.length} patterns',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: context.colors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: state.isLoading && state.patterns.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(patternRegistryProvider.notifier).load(),
                      child: state.patterns.isEmpty
                          ? ListView(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height * 0.4,
                                  child: Center(
                                    child: Text(
                                      'No patterns yet — define one from a '
                                      'non-transaction message',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: context.colors.textDim,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              padding: const EdgeInsets.only(
                                bottom: 24,
                                left: 20,
                                right: 20,
                              ),
                              children: [
                                for (final sender in senders) ...[
                                  _SenderHeader(
                                    sender: sender,
                                    count: bySender[sender]!.length,
                                  ),
                                  for (final p in bySender[sender]!)
                                    _PatternTile(
                                      pattern: p,
                                      isAdmin: isAdmin,
                                      // GLOBALs are customizable by any member
                                      // (copy-on-write); FAMILY patterns need the
                                      // author or a family admin.
                                      canEdit:
                                          p.scope == PatternScope.global ||
                                          p.createdByUserId == userId ||
                                          isAdmin,
                                      busy: state.busyPatternIds.contains(p.id),
                                      onEdit: () => context.push(
                                        '${AppRoutes.patternBuilder}'
                                        '?patternId=${Uri.encodeComponent(p.id)}',
                                      ),
                                      onToggle: () =>
                                          p.isEnabledForFamily
                                              ? _disable(p)
                                              : _enable(p),
                                      onPromote: () => _promote(p),
                                    ),
                                  const SizedBox(height: 12),
                                ],
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

class _SenderHeader extends StatelessWidget {
  final String sender;
  final int count;

  const _SenderHeader({required this.sender, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        children: [
          Text(
            sender,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.primaryLight,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: context.colors.surfaceHighlight,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternTile extends StatelessWidget {
  final SmsPattern pattern;
  final bool isAdmin;

  /// Whether the caller may edit/disable/enable this pattern: any member for a
  /// GLOBAL (copy-on-write), the author or a family admin for a FAMILY pattern.
  final bool canEdit;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onPromote;

  const _PatternTile({
    required this.pattern,
    required this.isAdmin,
    required this.canEdit,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
    required this.onPromote,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = pattern.isEnabledForFamily;
    final scopeLabel =
        pattern.scope == PatternScope.family ? 'Family' : 'Global';
    final sourceLabel =
        pattern.source == PatternSource.user ? 'by you' : 'by LLM';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pattern.template,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? context.colors.textMain
                        : context.colors.textDim,
                  ),
                ),
              ),
              _Tag(label: scopeLabel),
              const SizedBox(width: 6),
              _Tag(
                label: sourceLabel,
                color: pattern.source == PatternSource.user
                    ? context.colors.primaryLight
                    : context.colors.textDim,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pattern.sampleMessage,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: context.colors.textDim,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatusTag(
                label: !pattern.active
                    ? 'Disabled'
                    : pattern.hiddenForFamily
                        ? 'Hidden for family'
                        : 'Active',
                enabled: enabled,
              ),
              const SizedBox(width: 8),
              Text(
                '${pattern.usageCount} uses',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: context.colors.textDim,
                ),
              ),
              const Spacer(),
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (canEdit) ...[
                TextButton(
                  key: Key('pattern-edit-${pattern.id}'),
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.primaryLight,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Edit',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  key: Key('pattern-toggle-${pattern.id}'),
                  onPressed: onToggle,
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    enabled ? 'Disable' : 'Enable',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isAdmin && pattern.scope == PatternScope.family)
                  IconButton(
                    key: Key('pattern-promote-${pattern.id}'),
                    onPressed: onPromote,
                    icon: Icon(
                      Icons.public,
                      size: 18,
                      color: context.colors.primaryLight,
                    ),
                    tooltip: 'Promote to global',
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color? color;

  const _Tag({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    );
  }
}

/// Active / Disabled / Hidden for family indicator.
class _StatusTag extends StatelessWidget {
  final String label;
  final bool enabled;

  const _StatusTag({required this.label, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? context.colors.accentMint : context.colors.textDim;
    return Row(
      children: [
        Icon(
          enabled ? Icons.check_circle : Icons.pause_circle,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: color),
        ),
      ],
    );
  }
}