import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/message.dart';
import '../../models/transaction.dart';
import '../../providers/inbox_provider.dart';
import '../../providers/sms_provider.dart';

/// Message Inbox — mirrors the device SMS inbox with two tabs:
/// Recorded Transactions and Non-Transactions.
class MessageInboxScreen extends ConsumerStatefulWidget {
  const MessageInboxScreen({super.key});

  @override
  ConsumerState<MessageInboxScreen> createState() => _MessageInboxScreenState();
}

class _MessageInboxScreenState extends ConsumerState<MessageInboxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Requests SMS access, reads the device inbox, runs the sync pipeline, then
  /// re-reads so freshly recorded messages move to the Recorded tab.
  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final sms = ref.read(smsProvider.notifier);
      await sms.recheckPermission();
      var granted = ref.read(smsProvider).smsPermissionGranted;
      if (!granted) {
        granted = await sms.requestPermission();
      }
      if (!granted) {
        await ref.read(inboxProvider.notifier).refresh();
        return;
      }
      await ref.read(inboxProvider.notifier).refresh();
      await sms.syncInboxMessages();
      await ref.read(inboxProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxProvider);

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
                  IconButton(
                    onPressed: _refreshing ? null : _refresh,
                    icon: _refreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.refresh,
                            color: context.colors.textMuted,
                          ),
                    tooltip: 'Refresh inbox',
                  ),
                ],
              ),
            ),

            // ── Tabs ──
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              padding: const EdgeInsets.all(4),
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
                  Tab(text: 'Recorded (${inbox.recordedMessages.length})'),
                  Tab(text: 'Non-Transactions (${inbox.nonTransactions.length})'),
                ],
              ),
            ),

            if (inbox.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  inbox.error!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.colors.accentCoral,
                  ),
                ),
              ),

            // ── Tab content ──
            if (inbox.isLoading && inbox.recordedMessages.isEmpty &&
                inbox.nonTransactions.isEmpty)
              const Expanded(
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (inbox.permissionDenied)
              Expanded(child: _PermissionState(onGrant: _refresh))
            else
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _RecordedTab(
                      messages: inbox.recordedMessages,
                      transactions: inbox.transactionByMessageId,
                    ),
                    _NonTransactionsTab(messages: inbox.nonTransactions),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Recorded Transactions ───

class _RecordedTab extends StatelessWidget {
  final List<Message> messages;
  final Map<String, Transaction> transactions;

  const _RecordedTab({required this.messages, required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _EmptyState(
        icon: Icons.receipt_long_outlined,
        label: 'No recorded transactions',
        subtitle: 'Messages that produce a transaction appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshInbox(context),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: messages.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final message = messages[index];
          return _RecordedCard(
            message: message,
            transaction: transactions[message.id],
          );
        },
      ),
    );
  }
}

class _RecordedCard extends StatelessWidget {
  final Message message;
  final Transaction? transaction;

  const _RecordedCard({required this.message, this.transaction});

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    return InkWell(
      onTap: tx == null
          ? null
          : () => context.push(
              '${AppRoutes.transactionDetail}/${tx.id}',
              extra: tx,
            ),
      borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(16),
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
                _SenderChip(sender: message.sender),
                const Spacer(),
                Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: context.colors.accentMint,
                ),
                const SizedBox(width: 4),
                Text(
                  'Recorded',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.colors.accentMint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message.rawText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: context.colors.textMuted,
                height: 1.4,
              ),
            ),
            if (tx != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.colors.background,
                  borderRadius:
                      BorderRadius.circular(BudgetlyTheme.radiusSmall),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tx.merchant,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textMain,
                        ),
                      ),
                    ),
                    Text(
                      '${tx.isExpense ? '-' : '+'}${tx.currencySymbol}'
                      '${tx.amount.toStringAsFixed(0)}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tx.isExpense
                            ? context.colors.textMain
                            : context.colors.accentMint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatDate(tx.transactionDate),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: context.colors.textDim,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Non-Transactions ───

class _NonTransactionsTab extends StatelessWidget {
  final List<Message> messages;

  const _NonTransactionsTab({required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _EmptyState(
        icon: Icons.mark_email_read_outlined,
        label: 'No non-transaction messages',
        subtitle: 'Every SMS in the device inbox produced a transaction',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshInbox(context),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: messages.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _NonTransactionCard(message: messages[index]),
      ),
    );
  }
}

class _NonTransactionCard extends StatelessWidget {
  final Message message;

  const _NonTransactionCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              _SenderChip(sender: message.sender),
              const Spacer(),
              Text(
                _formatDate(message.receivedAt),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: context.colors.textDim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message.rawText,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: context.colors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              key: const Key('define-pattern-button'),
              onPressed: () => context.push(
                '${AppRoutes.patternBuilder}'
                '?messageId=${Uri.encodeComponent(message.id)}',
              ),
              icon: const Icon(Icons.dashboard_customize_outlined, size: 16),
              label: Text(
                'Define pattern',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.primaryLight,
                side: BorderSide(
                  color: context.colors.primaryLight.withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(BudgetlyTheme.radiusMedium),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared pieces ───

class _SenderChip extends StatelessWidget {
  final String sender;

  const _SenderChip({required this.sender});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusPill),
      ),
      child: Text(
        sender,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: context.colors.primaryLight,
        ),
      ),
    );
  }
}

class _PermissionState extends StatelessWidget {
  final Future<void> Function() onGrant;

  const _PermissionState({required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sms_outlined,
                size: 32,
                color: context.colors.primaryLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'SMS access required',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.colors.textMain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Allow SMS access to see the messages on this device.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: context.colors.textDim,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onGrant,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(BudgetlyTheme.radiusMedium),
                ),
              ),
              child: Text(
                'Grant access',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          const SizedBox(height: 16),
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.colors.textMain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
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

/// Pull-to-refresh hook for the tab lists.
Future<void> _refreshInbox(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  await container.read(inboxProvider.notifier).refresh();
}

final DateFormat _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

/// Date-led timestamp: "22 Nov 2026, 14:05".
String _formatDate(DateTime date) => _dateFormat.format(date.toLocal());