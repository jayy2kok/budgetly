import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message.dart';
import '../data/mock/mock_message_service.dart';

/// State for message triage.
class MessageState {
  final List<Message> pendingMessages;
  final List<Message> ignoredMessages;
  final List<Message> deletedMessages;
  final bool isLoading;
  final int currentIndex;

  const MessageState({
    this.pendingMessages = const [],
    this.ignoredMessages = const [],
    this.deletedMessages = const [],
    this.isLoading = false,
    this.currentIndex = 0,
  });

  /// The message currently being reviewed.
  Message? get currentMessage =>
      pendingMessages.isNotEmpty && currentIndex < pendingMessages.length
      ? pendingMessages[currentIndex]
      : null;

  int get totalPending => pendingMessages.length;

  bool get hasMore => currentIndex < pendingMessages.length;

  MessageState copyWith({
    List<Message>? pendingMessages,
    List<Message>? ignoredMessages,
    List<Message>? deletedMessages,
    bool? isLoading,
    int? currentIndex,
  }) {
    return MessageState(
      pendingMessages: pendingMessages ?? this.pendingMessages,
      ignoredMessages: ignoredMessages ?? this.ignoredMessages,
      deletedMessages: deletedMessages ?? this.deletedMessages,
      isLoading: isLoading ?? this.isLoading,
      currentIndex: currentIndex ?? this.currentIndex,
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
      // Scoped to current user (hardcoded 'user_001' for mock)
      final result = await _service.getMessages('user_001');
      state = MessageState(
        pendingMessages: result
            .where((m) => m.status == MessageStatus.pending)
            .toList(),
        ignoredMessages: result
            .where(
              (m) =>
                  m.status == MessageStatus.ignored &&
                  m.triageResult == TriageResult.otp,
            )
            .toList(),
        deletedMessages: result
            .where(
              (m) =>
                  m.status == MessageStatus.ignored &&
                  m.triageResult == TriageResult.promo,
            )
            .toList(),
        isLoading: false,
        currentIndex: 0,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void confirmMessage(String messageId) {
    final pending = [...state.pendingMessages];
    pending.removeWhere((m) => m.id == messageId);
    final newIndex = state.currentIndex < pending.length
        ? state.currentIndex
        : (pending.isEmpty ? 0 : pending.length - 1);
    state = state.copyWith(pendingMessages: pending, currentIndex: newIndex);
  }

  void rejectMessage(String messageId) {
    final pending = [...state.pendingMessages];
    final msg = pending.firstWhere((m) => m.id == messageId);
    pending.removeWhere((m) => m.id == messageId);
    final newIndex = state.currentIndex < pending.length
        ? state.currentIndex
        : (pending.isEmpty ? 0 : pending.length - 1);
    state = state.copyWith(
      pendingMessages: pending,
      deletedMessages: [...state.deletedMessages, msg],
      currentIndex: newIndex,
    );
  }

  void restoreMessage(String messageId) {
    // Try from ignored
    final ignored = [...state.ignoredMessages];
    final fromIgnored = ignored.where((m) => m.id == messageId).toList();
    if (fromIgnored.isNotEmpty) {
      ignored.removeWhere((m) => m.id == messageId);
      state = state.copyWith(
        ignoredMessages: ignored,
        pendingMessages: [...state.pendingMessages, fromIgnored.first],
      );
      return;
    }
    // Try from deleted
    final deleted = [...state.deletedMessages];
    final fromDeleted = deleted.where((m) => m.id == messageId).toList();
    if (fromDeleted.isNotEmpty) {
      deleted.removeWhere((m) => m.id == messageId);
      state = state.copyWith(
        deletedMessages: deleted,
        pendingMessages: [...state.pendingMessages, fromDeleted.first],
      );
    }
  }

  void nextMessage() {
    if (state.currentIndex < state.pendingMessages.length - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  void previousMessage() {
    if (state.currentIndex > 0) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    }
  }
}

final messageProvider = NotifierProvider<MessageNotifier, MessageState>(
  MessageNotifier.new,
);
