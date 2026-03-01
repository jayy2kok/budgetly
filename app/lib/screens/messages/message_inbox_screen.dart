import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/message.dart';
import '../../providers/message_provider.dart';

/// Message Inbox — AI triage carousel with confirm/edit/reject actions.
class MessageInboxScreen extends ConsumerStatefulWidget {
  const MessageInboxScreen({super.key});

  @override
  ConsumerState<MessageInboxScreen> createState() => _MessageInboxScreenState();
}

class _MessageInboxScreenState extends ConsumerState<MessageInboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messageProvider.notifier).loadMessages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final msgState = ref.watch(messageProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: context.colors.textMuted,
                    ),
                  ),
                  Text(
                    'Message Triage',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textMain,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.ignoredMessages),
                    child: Text(
                      'Ignored',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // ── Progress ──
            if (msgState.totalPending > 0) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reviewing ${msgState.currentIndex + 1} of ${msgState.totalPending}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textMuted,
                          ),
                        ),
                        Text(
                          '${((msgState.currentIndex + 1) / msgState.totalPending * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.colors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        BudgetlyTheme.radiusPill,
                      ),
                      child: LinearProgressIndicator(
                        value:
                            (msgState.currentIndex + 1) / msgState.totalPending,
                        backgroundColor: context.colors.cardSurface,
                        valueColor: AlwaysStoppedAnimation(
                          context.colors.primary,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
            ],

            // ── Content ──
            if (msgState.isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (msgState.currentMessage == null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: context.colors.accentMint.withValues(
                            alpha: 0.1,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle_outline,
                          size: 36,
                          color: context.colors.accentMint,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'All caught up!',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textMain,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No messages to review',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: context.colors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _TriageCard(
                    message: msgState.currentMessage!,
                    onConfirm: () {
                      ref
                          .read(messageProvider.notifier)
                          .confirmMessage(msgState.currentMessage!.id);
                    },
                    onReject: () {
                      ref
                          .read(messageProvider.notifier)
                          .rejectMessage(msgState.currentMessage!.id);
                    },
                    onEdit: () {
                      // Phase 3: navigate to edit form
                    },
                  ),
                ),
              ),

            // ── Navigation arrows ──
            if (msgState.totalPending > 1 && msgState.currentMessage != null)
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavButton(
                      icon: Icons.arrow_back,
                      enabled: msgState.currentIndex > 0,
                      onTap: () =>
                          ref.read(messageProvider.notifier).previousMessage(),
                    ),
                    _NavButton(
                      icon: Icons.arrow_forward,
                      enabled:
                          msgState.currentIndex < msgState.totalPending - 1,
                      onTap: () =>
                          ref.read(messageProvider.notifier).nextMessage(),
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

// ─── Triage Card ───
class _TriageCard extends StatelessWidget {
  final Message message;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onEdit;

  const _TriageCard({
    required this.message,
    required this.onConfirm,
    required this.onReject,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCardLg),
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sender badge
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(BudgetlyTheme.radiusPill),
                ),
                child: Text(
                  message.sender,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.colors.primaryLight,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: context.colors.primary.withValues(alpha: 0.5),
              ),
              SizedBox(width: 4),
              Text(
                _triageLabel(message.triageResult),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textDim,
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Raw SMS text
          Text(
            'SMS MESSAGE',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: context.colors.textDim,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.background,
              borderRadius: BorderRadius.circular(BudgetlyTheme.radiusMedium),
              border: Border.all(
                color: context.colors.surfaceHighlight.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              message.rawText,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                color: context.colors.textMuted,
                height: 1.7,
              ),
            ),
          ),

          const Spacer(),

          // ── Action Buttons ──
          Row(
            children: [
              // Reject
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: Icon(Icons.close, size: 18),
                    label: Text('Reject'),
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
              ),
              SizedBox(width: 10),
              // Edit
              SizedBox(
                width: 48,
                height: 48,
                child: OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: context.colors.textMuted,
                    side: BorderSide(color: context.colors.borderSubtle),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        BudgetlyTheme.radiusMedium,
                      ),
                    ),
                  ),
                  child: Icon(Icons.edit, size: 18),
                ),
              ),
              SizedBox(width: 10),
              // Confirm
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onConfirm,
                    icon: Icon(Icons.check, size: 18),
                    label: Text('Confirm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.accentMint,
                      foregroundColor: context.colors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          BudgetlyTheme.radiusMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _triageLabel(TriageResult result) {
    switch (result) {
      case TriageResult.transaction:
        return 'Transaction detected';
      case TriageResult.otp:
        return 'OTP — skipped';
      case TriageResult.promo:
        return 'Promo — skipped';
      case TriageResult.personal:
        return 'Personal — skipped';
      case TriageResult.unknown:
        return 'Unknown';
    }
  }
}

// ─── Navigation Button ───
class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled
              ? context.colors.cardSurface
              : context.colors.cardSurface.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(color: context.colors.borderSubtle),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? context.colors.textMain
              : context.colors.textDim.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
