import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../models/message.dart';
import '../../providers/message_provider.dart';

/// Ignored Messages — Two tabs for AI Skipped and Deleted messages.
class IgnoredMessagesScreen extends ConsumerStatefulWidget {
  const IgnoredMessagesScreen({super.key});

  @override
  ConsumerState<IgnoredMessagesScreen> createState() =>
      _IgnoredMessagesScreenState();
}

class _IgnoredMessagesScreenState extends ConsumerState<IgnoredMessagesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                          'Ignored Messages',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textMain,
                          ),
                        ),
                        Text(
                          'Showing only your messages',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: context.colors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 48), // balance
                ],
              ),
            ),

            SizedBox(height: 8),

            // ── Tabs ──
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.colors.cardSurface,
                borderRadius: BorderRadius.circular(BudgetlyTheme.radiusPill),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: context.colors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(BudgetlyTheme.radiusPill),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerHeight: 0,
                labelStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                labelColor: context.colors.textMain,
                unselectedLabelColor: context.colors.textMuted,
                tabs: [
                  Tab(text: 'AI Skipped (${msgState.ignoredMessages.length})'),
                  Tab(text: 'Deleted (${msgState.deletedMessages.length})'),
                ],
              ),
            ),

            SizedBox(height: 8),

            // ── Tab Content ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _MessageList(
                    messages: msgState.ignoredMessages,
                    emptyLabel: 'No AI-skipped messages',
                    emptyIcon: Icons.smart_toy_outlined,
                    onRestore: (id) =>
                        ref.read(messageProvider.notifier).restoreMessage(id),
                  ),
                  _MessageList(
                    messages: msgState.deletedMessages,
                    emptyLabel: 'No deleted messages',
                    emptyIcon: Icons.delete_outline,
                    onRestore: (id) =>
                        ref.read(messageProvider.notifier).restoreMessage(id),
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

class _MessageList extends StatelessWidget {
  final List<Message> messages;
  final String emptyLabel;
  final IconData emptyIcon;
  final void Function(String id) onRestore;

  const _MessageList({
    required this.messages,
    required this.emptyLabel,
    required this.emptyIcon,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              emptyIcon,
              size: 40,
              color: context.colors.textDim.withValues(alpha: 0.4),
            ),
            SizedBox(height: 12),
            Text(
              emptyLabel,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: context.colors.textDim,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: messages.length,
      separatorBuilder: (_, _) => SizedBox(height: 8),
      itemBuilder: (context, index) {
        final msg = messages[index];
        return _IgnoredMessageRow(
          message: msg,
          onRestore: () => onRestore(msg.id),
        );
      },
    );
  }
}

class _IgnoredMessageRow extends StatelessWidget {
  final Message message;
  final VoidCallback onRestore;

  const _IgnoredMessageRow({required this.message, required this.onRestore});

  String get _reasonLabel {
    switch (message.triageResult) {
      case TriageResult.otp:
        return 'OTP detected';
      case TriageResult.promo:
        return 'Promotional';
      case TriageResult.transaction:
        return 'User deleted';
      case TriageResult.personal:
        return 'Personal message';
      case TriageResult.unknown:
        return 'Unknown';
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
          // Sender
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.colors.surfaceHighlight,
              borderRadius: BorderRadius.circular(BudgetlyTheme.radiusMedium),
            ),
            child: Center(
              child: Text(
                message.sender[0],
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textMuted,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.sender,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textMain,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  _reasonLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.colors.textDim,
                  ),
                ),
              ],
            ),
          ),

          // Restore
          TextButton(
            onPressed: onRestore,
            style: TextButton.styleFrom(
              foregroundColor: context.colors.primary,
              textStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text('Restore'),
          ),
        ],
      ),
    );
  }
}
