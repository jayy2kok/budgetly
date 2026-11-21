import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/sms_pattern.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/pattern_registry_provider.dart';

/// Pattern Registry — browse cached patterns (global + family), author new
/// patterns from failed/ignored messages, and promote authored patterns to the
/// global registry (family admin).
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

  Future<void> _confirmDelete(String patternId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.cardSurface,
        title: Text(
          'Delete pattern?',
          style: GoogleFonts.ibmPlexSans(
            color: context.colors.textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This pattern will stop matching incoming messages for your family.',
          style: GoogleFonts.inter(color: context.colors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: context.colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(color: context.colors.accentCoral),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(patternRegistryProvider.notifier).deletePattern(patternId);
    }
  }

  Future<void> _promote(SmsPattern pattern) async {
    try {
      await ref.read(patternRegistryProvider.notifier).promotePattern(pattern.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${pattern.sender}" pattern is now global',
            style: GoogleFonts.inter(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: GoogleFonts.inter()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patternRegistryProvider);
    final userId = ref.watch(authProvider).user?.id ?? '';
    final members = ref.watch(familyProvider).members;
    final isAdmin = members.any(
      (m) => m.userId == userId && m.isAdmin,
    );

    // Group patterns by sender for a compact, scannable list.
    final bySender = <String, List<SmsPattern>>{};
    for (final p in state.patterns) {
      bySender.putIfAbsent(p.sender, () => []).add(p);
    }
    final senders = bySender.keys.toList()..sort();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.patternBuilder),
        icon: const Icon(Icons.add),
        label: Text(
          'New pattern',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: EdgeInsets.fromLTRB(8, 12, 8, 0),
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
                          '${state.patterns.length} active patterns',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: context.colors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 48),
                ],
              ),
            ),

            SizedBox(height: 8),

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
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height * 0.4,
                                  child: Center(
                                    child: Text(
                                      'No patterns yet — author one from a failed message',
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
                              padding: EdgeInsets.only(
                                bottom: 96,
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
                                      canEdit: p.canEdit(userId),
                                      isAdmin: isAdmin,
                                      busy: state.busyPatternIds.contains(p.id),
                                      onDelete: () => _confirmDelete(p.id),
                                      onPromote: () => _promote(p),
                                    ),
                                  SizedBox(height: 12),
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
      padding: EdgeInsets.only(top: 12, bottom: 6),
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
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
  final bool canEdit;
  final bool isAdmin;
  final bool busy;
  final VoidCallback onDelete;
  final VoidCallback onPromote;

  const _PatternTile({
    required this.pattern,
    required this.canEdit,
    required this.isAdmin,
    required this.busy,
    required this.onDelete,
    required this.onPromote,
  });

  @override
  Widget build(BuildContext context) {
    final scopeLabel =
        pattern.scope == PatternScope.family ? 'Family' : 'Global';
    final sourceLabel =
        pattern.source == PatternSource.user ? 'by you' : 'by LLM';

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
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
                    color: context.colors.textMain,
                  ),
                ),
              ),
              _Tag(label: scopeLabel),
              SizedBox(width: 6),
              _Tag(
                label: sourceLabel,
                color: pattern.source == PatternSource.user
                    ? context.colors.primaryLight
                    : context.colors.textDim,
              ),
            ],
          ),
          SizedBox(height: 6),
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
          SizedBox(height: 8),
          Row(
            children: [
              Icon(
                pattern.active ? Icons.check_circle : Icons.pause_circle,
                size: 14,
                color: pattern.active
                    ? context.colors.accentMint
                    : context.colors.textDim,
              ),
              SizedBox(width: 4),
              Text(
                '${pattern.usageCount} uses',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: context.colors.textDim,
                ),
              ),
              Spacer(),
              if (busy)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                if (isAdmin && pattern.scope == PatternScope.family)
                  IconButton(
                    onPressed: onPromote,
                    icon: Icon(
                      Icons.public,
                      size: 18,
                      color: context.colors.primaryLight,
                    ),
                    tooltip: 'Promote to global',
                  ),
                if (canEdit)
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: context.colors.accentCoral,
                    ),
                    tooltip: 'Delete pattern',
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
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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