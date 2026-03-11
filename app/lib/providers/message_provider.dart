import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message.dart';
import '../data/mock/mock_message_service.dart';

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

  const MessageState({
    this.incompleteMessages = const [],
    this.unprocessedMessages = const [],
    this.nonFinancialMessages = const [],
    this.deletedMessages = const [],
    this.processingIds = const {},
    this.isLoading = false,
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
  }) {
    return MessageState(
      incompleteMessages: incompleteMessages ?? this.incompleteMessages,
      unprocessedMessages: unprocessedMessages ?? this.unprocessedMessages,
      nonFinancialMessages: nonFinancialMessages ?? this.nonFinancialMessages,
      deletedMessages: deletedMessages ?? this.deletedMessages,
      processingIds: processingIds ?? this.processingIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class MessageNotifier extends Notifier<MessageState> {
  late final MockMessageService _service;

  @override
  MessageState build() {
    _service = MockMessageService();
    return const MessageState();
  }

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _service.getMessages('user_001');

      state = MessageState(
        // Incomplete: regex matched (parseSource == regexLocal) but missing fields
        incompleteMessages: result.where((m) {
          return m.status == MessageStatus.pending &&
              m.parseSource == ParseSource.regexLocal &&
              m.isIncomplete;
        }).toList(),

        // Unprocessed: no regex match (parseSource == null, status == pending)
        unprocessedMessages: result.where((m) {
          return m.status == MessageStatus.pending && m.parseSource == null;
        }).toList(),

        // Non-financial: classified by LLM (status == ignored, has category)
        nonFinancialMessages: result.where((m) {
          return m.status == MessageStatus.ignored &&
              m.nonFinancialCategory != null;
        }).toList(),

        // Deleted: user-rejected
        deletedMessages: result.where((m) {
          return m.status == MessageStatus.rejected;
        }).toList(),

        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Confirm an incomplete message with user-supplied data.
  void confirmMessage(String messageId) {
    final incomplete = [...state.incompleteMessages];
    incomplete.removeWhere((m) => m.id == messageId);
    state = state.copyWith(incompleteMessages: incomplete);
  }

  /// Reject a message — move from incomplete/unprocessed to deleted.
  void rejectMessage(String messageId) {
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

    state = state.copyWith(
      incompleteMessages: incomplete,
      unprocessedMessages: unprocessed,
      deletedMessages:
          msg != null ? [...state.deletedMessages, msg] : state.deletedMessages,
    );
  }

  /// Submit an unprocessed message to the server for LLM analysis.
  Future<void> submitToServer(String messageId) async {
    // Add to processing set
    state = state.copyWith(
      processingIds: {...state.processingIds, messageId},
    );

    try {
      final msg = state.unprocessedMessages.firstWhere(
        (m) => m.id == messageId,
      );
      await _service.submitToServer(msg);

      // Remove from unprocessed
      final unprocessed = [...state.unprocessedMessages];
      unprocessed.removeWhere((m) => m.id == messageId);

      final ids = {...state.processingIds};
      ids.remove(messageId);

      state = state.copyWith(
        unprocessedMessages: unprocessed,
        processingIds: ids,
      );
    } catch (_) {
      final ids = {...state.processingIds};
      ids.remove(messageId);
      state = state.copyWith(processingIds: ids);
    }
  }

  /// Restore a message from non-financial or deleted back to unprocessed.
  void restoreMessage(String messageId) {
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
