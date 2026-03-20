import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/message_service.dart';
import '../models/message.dart';
import 'service_providers.dart';

/// State for the SMS message processing pipeline.
class MessageState {
  /// Regex-matched but missing mandatory fields (amount/merchant/timestamp).
  final List<Message> incompleteMessages;

  /// No regex pattern matched — needs server-side LLM analysis.
  final List<Message> unprocessedMessages;

  /// LLM-classified non-financial messages (OTP, promo, delivery, personal).
  final List<Message> nonFinancialMessages;

  /// User-deleted / rejected messages.
  final List<Message> deletedMessages;

  /// Message IDs currently being submitted to server.
  final Set<String> processingIds;

  final bool isLoading;
  final String? error;

  const MessageState({
    this.incompleteMessages = const [],
    this.unprocessedMessages = const [],
    this.nonFinancialMessages = const [],
    this.deletedMessages = const [],
    this.processingIds = const {},
    this.isLoading = false,
    this.error,
  });

  int get totalIncomplete => incompleteMessages.length;
  int get totalUnprocessed => unprocessedMessages.length;
  int get totalNonFinancial => nonFinancialMessages.length;
  int get totalDeleted => deletedMessages.length;

  MessageState copyWith({
    List<Message>? incompleteMessages,
    List<Message>? unprocessedMessages,
    List<Message>? nonFinancialMessages,
    List<Message>? deletedMessages,
    Set<String>? processingIds,
    bool? isLoading,
    String? error,
  }) {
    return MessageState(
      incompleteMessages: incompleteMessages ?? this.incompleteMessages,
      unprocessedMessages: unprocessedMessages ?? this.unprocessedMessages,
      nonFinancialMessages: nonFinancialMessages ?? this.nonFinancialMessages,
      deletedMessages: deletedMessages ?? this.deletedMessages,
      processingIds: processingIds ?? this.processingIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MessageNotifier extends Notifier<MessageState> {
  late final MessageService _service;

  @override
  MessageState build() {
    _service = ref.watch(messageServiceProvider);
    return const MessageState();
  }

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true);
    try {
      final pending = await _service.getPendingMessages();
      final ignored = await _service.getIgnoredMessages();

      state = MessageState(
        // Incomplete: regex matched (parseSource == regexLocal) but missing fields
        incompleteMessages: pending.where((m) {
          return m.parseSource == ParseSource.regexLocal && m.isIncomplete;
        }).toList(),

        // Unprocessed: no regex match (parseSource == null, status == pending)
        unprocessedMessages: pending.where((m) {
          return m.parseSource == null;
        }).toList(),

        // Non-financial: classified by LLM with non-financial category
        nonFinancialMessages: ignored.where((m) {
          return m.status == MessageStatus.ignored &&
              m.nonFinancialCategory != null;
        }).toList(),

        // Deleted: user-rejected
        deletedMessages: ignored.where((m) {
          return m.status == MessageStatus.rejected;
        }).toList(),

        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Confirm an incomplete message with user-supplied data.
  Future<void> confirmMessage(String messageId) async {
    try {
      await _service.confirmMessage(messageId);
      final incomplete = [...state.incompleteMessages]
        ..removeWhere((m) => m.id == messageId);
      state = state.copyWith(incompleteMessages: incomplete);
    } catch (_) {
      // Optimistic: remove from UI regardless
      final incomplete = [...state.incompleteMessages]
        ..removeWhere((m) => m.id == messageId);
      state = state.copyWith(incompleteMessages: incomplete);
    }
  }

  /// Reject a message — move from incomplete/unprocessed to deleted.
  Future<void> rejectMessage(String messageId) async {
    final incomplete = [...state.incompleteMessages];
    final unprocessed = [...state.unprocessedMessages];
    Message? msg;

    final fromIncomplete =
        incomplete.where((m) => m.id == messageId).toList();
    if (fromIncomplete.isNotEmpty) {
      msg = fromIncomplete.first;
      incomplete.removeWhere((m) => m.id == messageId);
    } else {
      final fromUnprocessed =
          unprocessed.where((m) => m.id == messageId).toList();
      if (fromUnprocessed.isNotEmpty) {
        msg = fromUnprocessed.first;
        unprocessed.removeWhere((m) => m.id == messageId);
      }
    }

    try {
      await _service.rejectMessage(messageId);
    } catch (_) {
      // Best-effort
    }

    state = state.copyWith(
      incompleteMessages: incomplete,
      unprocessedMessages: unprocessed,
      deletedMessages:
          msg != null ? [...state.deletedMessages, msg] : state.deletedMessages,
    );
  }

  /// Submit an unprocessed message to the server for LLM analysis.
  Future<void> submitToServer(
      String messageId, String familyGroupId) async {
    state = state.copyWith(
      processingIds: {...state.processingIds, messageId},
    );

    try {
      final msg = state.unprocessedMessages.firstWhere(
        (m) => m.id == messageId,
      );

      await _service.processMessage({
        'sender': msg.sender,
        'rawText': msg.rawText,
        'familyGroupId': familyGroupId,
      });

      // Remove from unprocessed on success
      final unprocessed = [...state.unprocessedMessages]
        ..removeWhere((m) => m.id == messageId);
      final ids = {...state.processingIds}..remove(messageId);
      state = state.copyWith(
        unprocessedMessages: unprocessed,
        processingIds: ids,
      );
    } catch (e) {
      final ids = {...state.processingIds}..remove(messageId);
      state = state.copyWith(processingIds: ids, error: e.toString());
    }
  }

  /// Restore a message from non-financial or deleted back to unprocessed.
  Future<void> restoreMessage(String messageId) async {
    try {
      await _service.restoreMessage(messageId);
    } catch (_) {
      // Best-effort
    }

    final nonFinancial = [...state.nonFinancialMessages];
    final fromNF = nonFinancial.where((m) => m.id == messageId).toList();
    if (fromNF.isNotEmpty) {
      nonFinancial.removeWhere((m) => m.id == messageId);
      state = state.copyWith(
        nonFinancialMessages: nonFinancial,
        unprocessedMessages: [...state.unprocessedMessages, fromNF.first],
      );
      return;
    }

    final deleted = [...state.deletedMessages];
    final fromDel = deleted.where((m) => m.id == messageId).toList();
    if (fromDel.isNotEmpty) {
      deleted.removeWhere((m) => m.id == messageId);
      state = state.copyWith(
        deletedMessages: deleted,
        unprocessedMessages: [...state.unprocessedMessages, fromDel.first],
      );
    }
  }
}

final messageProvider = NotifierProvider<MessageNotifier, MessageState>(
  MessageNotifier.new,
);
