import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/family_group.dart';
import '../models/family_member.dart';

/// State for the current family group and its members.
class FamilyState {
  final FamilyGroup? currentFamily;
  final List<FamilyMember> members;
  final bool isLoading;

  const FamilyState({
    this.currentFamily,
    this.members = const [],
    this.isLoading = false,
  });

  FamilyState copyWith({
    FamilyGroup? currentFamily,
    List<FamilyMember>? members,
    bool? isLoading,
  }) {
    return FamilyState(
      currentFamily: currentFamily ?? this.currentFamily,
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FamilyNotifier extends Notifier<FamilyState> {
  @override
  FamilyState build() => const FamilyState();

  Future<void> loadFamily(String familyId) async {
    state = state.copyWith(isLoading: true);
    // Phase 2: load from mock service
  }

  Future<void> updateBudgetLimit(double limit) async {
    if (state.currentFamily != null) {
      // Phase 2: update via mock service
    }
  }
}

final familyProvider = NotifierProvider<FamilyNotifier, FamilyState>(
  FamilyNotifier.new,
);
