import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message.dart';
import '../models/transaction.dart';
import '../providers/auth_provider.dart';
import '../providers/family_provider.dart';
import '../providers/service_providers.dart';
import '../services/sms_inbox_reader.dart';

/// The device SMS inbox, split by whether an SMS produced a recorded
/// transaction.
class InboxState {
  /// Device SMS that match a recorded transaction, newest first.
  final List<Message> recordedMessages;

  /// Device SMS that produced no transaction (OTP, promo, personal, or a
  /// financial message no pattern could parse), newest first.
  final List<Message> nonTransactions;

  /// Message id → recorded transaction, for the summary and the detail link.
  final Map<String, Transaction> transactionByMessageId;

  final bool isLoading;

  /// True when SMS permission is missing, so the screen shows a grant CTA.
  final bool permissionDenied;

  final String? error;

  const InboxState({
    this.recordedMessages = const [],
    this.nonTransactions = const [],
    this.transactionByMessageId = const {},
    this.isLoading = false,
    this.permissionDenied = false,
    this.error,
  });

  InboxState copyWith({
    List<Message>? recordedMessages,
    List<Message>? nonTransactions,
    Map<String, Transaction>? transactionByMessageId,
    bool? isLoading,
    bool? permissionDenied,
    String? error,
  }) {
    return InboxState(
      recordedMessages: recordedMessages ?? this.recordedMessages,
      nonTransactions: nonTransactions ?? this.nonTransactions,
      transactionByMessageId:
          transactionByMessageId ?? this.transactionByMessageId,
      isLoading: isLoading ?? this.isLoading,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      error: error,
    );
  }

  /// The device message with [id], or null when it is not in the inbox window.
  Message? messageById(String? id) {
    if (id == null) return null;
    for (final message in [...recordedMessages, ...nonTransactions]) {
      if (message.id == id) return message;
    }
    return null;
  }
}

/// Reads the device inbox and pairs SMS with recorded transactions.
class InboxNotifier extends Notifier<InboxState> {
  /// Max transaction pages fetched while looking for matches (page size 200).
  static const int _maxTransactionPages = 5;

  late final SmsInboxReader _reader;

  @override
  InboxState build() {
    _reader = ref.watch(smsInboxReaderProvider);
    return const InboxState();
  }

  /// Re-reads the device inbox and rebuilds both tabs.
  Future<void> refresh() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) {
      state = state.copyWith(isLoading: false, error: 'Not signed in');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      if (!await _reader.hasPermission()) {
        state = state.copyWith(
          isLoading: false,
          permissionDenied: true,
          recordedMessages: const [],
          nonTransactions: const [],
          transactionByMessageId: const {},
        );
        return;
      }

      final messages = await _reader.readAllInbox(userId: userId);
      final familyId = ref.read(familyProvider).currentFamily?.id;
      final transactions = familyId == null
          ? const <Transaction>[]
          : await _recentTransactions(familyId, messages);

      final byRawText = _groupTransactionsByBody(transactions);
      final recorded = <Message>[];
      final nonTransactions = <Message>[];
      final transactionByMessageId = <String, Transaction>{};

      // Newest-first walk with one-to-one consumption so two SMS with the
      // same body pair with two distinct transactions.
      for (final message in messages) {
        final candidates =
            byRawText[_normaliseBody(message.rawText)] ?? const <Transaction>[];
        if (candidates.isNotEmpty) {
          final transaction = candidates.removeLast();
          recorded.add(message);
          transactionByMessageId[message.id] = transaction;
        } else {
          nonTransactions.add(message);
        }
      }

      state = InboxState(
        recordedMessages: recorded,
        nonTransactions: nonTransactions,
        transactionByMessageId: transactionByMessageId,
        isLoading: false,
        permissionDenied: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Fetches recent SMS-sourced transactions, stopping once every device SMS
  /// can be covered (oldest SMS − 1 day) or the page cap is reached.
  Future<List<Transaction>> _recentTransactions(
    String familyId,
    List<Message> messages,
  ) async {
    if (messages.isEmpty) return const [];

    final oldestSms = messages
        .map((m) => m.receivedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final cutoff = oldestSms.subtract(const Duration(days: 1));

    final service = ref.read(transactionServiceProvider);
    final result = <Transaction>[];
    for (var page = 0; page < _maxTransactionPages; page++) {
      final batch = await service.getTransactions(familyId, page: page, size: 200);
      result.addAll(batch);
      final oldestFetched = batch
          .map((t) => t.transactionDate)
          .fold<DateTime?>(
            null,
            (oldest, date) => oldest == null || date.isBefore(oldest) ? date : oldest,
          );
      if (batch.length < 200 ||
          oldestFetched == null ||
          oldestFetched.isBefore(cutoff)) {
        break;
      }
    }
    return result;
  }

  /// Multiset of transactions keyed by their normalised SMS body.
  ///
  /// Only SMS-sourced rows carry [Transaction.sourceRawText]; manual rows are
  /// excluded because they were never derived from a message.
  Map<String, List<Transaction>> _groupTransactionsByBody(
    List<Transaction> transactions,
  ) {
    final grouped = <String, List<Transaction>>{};
    for (final transaction in transactions) {
      if (transaction.sourceType == SourceType.manual) continue;
      final rawText = transaction.sourceRawText;
      if (rawText == null || rawText.trim().isEmpty) continue;
      grouped.putIfAbsent(_normaliseBody(rawText), () => []).add(transaction);
    }
    // Oldest first so removeLast() consumes the newest match of a duplicate.
    for (final list in grouped.values) {
      list.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
    }
    return grouped;
  }

  static String _normaliseBody(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ');
}

final inboxProvider = NotifierProvider<InboxNotifier, InboxState>(
  InboxNotifier.new,
);