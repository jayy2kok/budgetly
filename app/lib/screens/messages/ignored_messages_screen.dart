import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../models/message.dart';
import '../../providers/message_provider.dart';

/// Ignored Messages — Two tabs: Non-Financial and Deleted.
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
    // Load fresh ignored/deleted messages each time the screen opens — data
    // otherwise only refreshes at the end of an SMS sync (issue #28).
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
                  borderRadius:
                      BorderRadius.circular(BudgetlyTheme.radiusPill),
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
                  Tab(
                      text:
                          'Non-Financial (${msgState.totalNonFinancial})'),
                  Tab(text: 'Deleted (${msgState.totalDeleted})'),
                ],
              ),
            ),

            SizedBox(height: 8),

            // ── Tab Content ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _RefreshableMessageList(
                    messages: msgState.nonFinancialMessages,
                    emptyLabel: 'No non-financial messages',
                    emptyIcon: Icons.smart_toy_outlined,
                    showCategory: true,
                    onRestore: (id) =>
                        ref.read(messageProvider.notifier).restoreMessage(id),
                    onRefresh: () =>
                        ref.read(messageProvider.notifier).loadMessages(),
                  ),
                  _RefreshableMessageList(
                    messages: msgState.deletedMessages,
                    emptyLabel: 'No deleted messages',
                    emptyIcon: Icons.delete_outline,
                    showCategory: false,
                    onRestore: (id) =>
                        ref.read(messageProvider.notifier).restoreMessage(id),
                    onRefresh: () =>
                        ref.read(messageProvider.notifier).loadMessages(),
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

/// Tab content wrapped in a [RefreshIndicator] so pulling down reloads the
/// ignored/deleted lists. The empty state is itself scrollable (with
/// [AlwaysScrollableScrollPhysics]) so pull-to-refresh works even when empty.
class _RefreshableMessageList extends StatelessWidget {
  final List<Message> messages;
  final String emptyLabel;
  final IconData emptyIcon;
  final bool showCategory;
  final void Function(String id) onRestore;
  final Future<void> Function() onRefresh;

  const _RefreshableMessageList({
    required this.messages,
    required this.emptyLabel,
    required this.emptyIcon,
    required this.showCategory,
    required this.onRestore,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: _MessageList(
        messages: messages,
        emptyLabel: emptyLabel,
        emptyIcon: emptyIcon,
        showCategory: showCategory,
        onRestore: onRestore,
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final List<Message> messages;
  final String emptyLabel;
  final IconData emptyIcon;
  final bool showCategory;
  final void Function(String id) onRestore;

  const _MessageList({
    required this.messages,
    required this.emptyLabel,
    required this.emptyIcon,
    required this.showCategory,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      // Scrollable so the enclosing RefreshIndicator still fires on pull.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: Center(
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
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: messages.length,
      separatorBuilder: (context, index) => SizedBox(height: 8),
      itemBuilder: (context, index) {
        final msg = messages[index];
        return _IgnoredMessageRow(
          message: msg,
          showCategory: showCategory,
          onRestore: () => onRestore(msg.id),
        );
      },
    );
  }
}

class _IgnoredMessageRow extends StatelessWidget {
  final Message message;
  final bool showCategory;
  final VoidCallback onRestore;

  const _IgnoredMessageRow({
    required this.message,
    required this.showCategory,
    required this.onRestore,
  });

  Color _categoryColor(NonFinancialCategory? cat) {
    switch (cat) {
      case NonFinancialCategory.otp:
        return const Color(0xFFFB7185); // Rose
      case NonFinancialCategory.promo:
        return const Color(0xFFFBBF24); // Amber
      case NonFinancialCategory.personal:
        return const Color(0xFF60A5FA); // Blue
      case NonFinancialCategory.delivery:
        return const Color(0xFF22D3EE); // Cyan
      case NonFinancialCategory.unknown:
      case null:
        return const Color(0xFF94A3B8); // Slate
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColor(message.nonFinancialCategory);

    return Container(
      padding: EdgeInsets.all(14),
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
              // Sender avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colors.surfaceHighlight,
                  borderRadius:
                      BorderRadius.circular(BudgetlyTheme.radiusMedium),
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

              // Sender name + category tag
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          message.sender,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textMain,
                          ),
                        ),
                        if (showCategory &&
                            message.nonFinancialCategory != null) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              message.categoryLabel,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: catColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2),
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

              // Undo button
              TextButton(
                onPressed: onRestore,
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.primary,
                  textStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text('Undo'),
              ),
            ],
          ),

          // Preview text
          SizedBox(height: 8),
          Text(
            message.rawText,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: context.colors.textDim,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
