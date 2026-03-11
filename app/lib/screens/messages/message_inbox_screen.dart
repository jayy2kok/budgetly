import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/message.dart';
import '../../providers/message_provider.dart';

/// Message Inbox — Two-tab layout: Incomplete + Unprocessed.
class MessageInboxScreen extends ConsumerStatefulWidget {
  const MessageInboxScreen({super.key});

  @override
  ConsumerState<MessageInboxScreen> createState() => _MessageInboxScreenState();
}

class _MessageInboxScreenState extends ConsumerState<MessageInboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messageProvider.notifier).loadMessages();
    });
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
                    child: Text(
                      'Message Inbox',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textMain,
                      ),
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

            // ── Auto-post banner ──
            Container(
              margin: EdgeInsets.fromLTRB(20, 8, 20, 4),
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.colors.accentMint.withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(BudgetlyTheme.radiusMedium),
                border: Border.all(
                  color: context.colors.accentMint.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 16, color: context.colors.accentMint),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fully parsed messages are auto-posted as transactions',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.colors.accentMint,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
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
                borderRadius:
                    BorderRadius.circular(BudgetlyTheme.radiusPill),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: context.colors.surfaceHighlight,
                  borderRadius:
                      BorderRadius.circular(BudgetlyTheme.radiusPill),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerHeight: 0,
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                labelColor: context.colors.textMain,
                unselectedLabelColor: context.colors.textMuted,
                tabs: [
                  Tab(
                      text:
                          'Incomplete (${msgState.totalIncomplete})'),
                  Tab(
                      text:
                          'Unprocessed (${msgState.totalUnprocessed})'),
                ],
              ),
            ),

            SizedBox(height: 8),

            // ── Tab Content ──
            if (msgState.isLoading)
              const Expanded(
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // ── INCOMPLETE TAB ──
                    _IncompleteTab(
                      messages: msgState.incompleteMessages,
                      onConfirm: (id) =>
                          ref.read(messageProvider.notifier).confirmMessage(id),
                      onReject: (id) =>
                          ref.read(messageProvider.notifier).rejectMessage(id),
                    ),
                    // ── UNPROCESSED TAB ──
                    _UnprocessedTab(
                      messages: msgState.unprocessedMessages,
                      processingIds: msgState.processingIds,
                      onSubmit: (id) =>
                          ref.read(messageProvider.notifier).submitToServer(id),
                      onReject: (id) =>
                          ref.read(messageProvider.notifier).rejectMessage(id),
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

// ─── Incomplete Tab ───
class _IncompleteTab extends StatelessWidget {
  final List<Message> messages;
  final void Function(String id) onConfirm;
  final void Function(String id) onReject;

  const _IncompleteTab({
    required this.messages,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return _EmptyState(
        icon: Icons.check_circle_outline,
        label: 'No incomplete messages',
        subtitle: 'All regex-matched messages were fully parsed',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: messages.length,
      separatorBuilder: (_, __) => SizedBox(height: 10),
      itemBuilder: (context, index) {
        final msg = messages[index];
        return _IncompleteCard(
          message: msg,
          onConfirm: () => onConfirm(msg.id),
          onReject: () => onReject(msg.id),
        );
      },
    );
  }
}

// ─── Incomplete Card ───
class _IncompleteCard extends StatelessWidget {
  final Message message;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  const _IncompleteCard({
    required this.message,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final data = message.extractedData ?? {};
    final mandatoryFields = ['amount', 'merchant', 'timestamp'];

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(BudgetlyTheme.radiusPill),
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
              Spacer(),
              Icon(Icons.pattern, size: 14,
                  color: context.colors.textDim),
              SizedBox(width: 4),
              Text(
                'Regex matched',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: context.colors.textDim,
                ),
              ),
            ],
          ),

          SizedBox(height: 14),

          // Extracted fields
          ...mandatoryFields.map((field) {
            final hasValue = data.containsKey(field);
            return Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      field.capitalize(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textDim,
                      ),
                    ),
                  ),
                  if (hasValue)
                    Text(
                      data[field]!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textMain,
                      ),
                    )
                  else
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Missing',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),

          SizedBox(height: 8),

          // Raw SMS
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.colors.background,
              borderRadius:
                  BorderRadius.circular(BudgetlyTheme.radiusSmall),
              border: Border.all(
                color: context.colors.surfaceHighlight.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              message.rawText,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: context.colors.textDim,
                height: 1.6,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          SizedBox(height: 14),

          // Actions
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.accentCoral,
                      side: BorderSide(
                        color: context.colors.accentCoral
                            .withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            BudgetlyTheme.radiusMedium),
                      ),
                    ),
                    child: Text('Reject',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: onConfirm,
                    icon: Icon(Icons.check, size: 16),
                    label: Text('Complete & Confirm',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            BudgetlyTheme.radiusMedium),
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
}

// ─── Unprocessed Tab ───
class _UnprocessedTab extends StatelessWidget {
  final List<Message> messages;
  final Set<String> processingIds;
  final void Function(String id) onSubmit;
  final void Function(String id) onReject;

  const _UnprocessedTab({
    required this.messages,
    required this.processingIds,
    required this.onSubmit,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return _EmptyState(
        icon: Icons.mark_email_read_outlined,
        label: 'No unprocessed messages',
        subtitle: 'All incoming SMS matched a known pattern',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: messages.length,
      separatorBuilder: (_, __) => SizedBox(height: 10),
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isProcessing = processingIds.contains(msg.id);
        return _UnprocessedCard(
          message: msg,
          isProcessing: isProcessing,
          onSubmit: () => onSubmit(msg.id),
          onReject: () => onReject(msg.id),
        );
      },
    );
  }
}

// ─── Unprocessed Card ───
class _UnprocessedCard extends StatelessWidget {
  final Message message;
  final bool isProcessing;
  final VoidCallback onSubmit;
  final VoidCallback onReject;

  const _UnprocessedCard({
    required this.message,
    required this.isProcessing,
    required this.onSubmit,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender + timestamp
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.colors.surfaceHighlight,
                  borderRadius:
                      BorderRadius.circular(BudgetlyTheme.radiusMedium),
                ),
                child: Center(
                  child: Text(
                    message.sender[0],
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textMuted,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
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
                    Text(
                      _timeAgo(message.receivedAt),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: context.colors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'No match',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Raw SMS text
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.colors.background,
              borderRadius:
                  BorderRadius.circular(BudgetlyTheme.radiusSmall),
              border: Border.all(
                color: context.colors.surfaceHighlight.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              message.rawText,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: context.colors.textMuted,
                height: 1.6,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          SizedBox(height: 14),

          // Actions
          Row(
            children: [
              SizedBox(
                height: 40,
                child: OutlinedButton(
                  onPressed: isProcessing ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.textDim,
                    side: BorderSide(color: context.colors.borderSubtle),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          BudgetlyTheme.radiusMedium),
                    ),
                  ),
                  child: Text('Dismiss',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: isProcessing ? null : onSubmit,
                    icon: isProcessing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.cloud_upload_outlined, size: 18),
                    label: Text(
                      isProcessing ? 'Analyzing...' : 'Submit to Server',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          context.colors.primary.withValues(alpha: 0.6),
                      disabledForegroundColor:
                          Colors.white.withValues(alpha: 0.7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            BudgetlyTheme.radiusMedium),
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─── Empty State ───
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.colors.accentMint.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: context.colors.accentMint),
          ),
          SizedBox(height: 16),
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.colors.textMain,
            ),
          ),
          SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: context.colors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper ───
extension _StringCap on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
