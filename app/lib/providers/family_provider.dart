import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/family_service.dart';
import '../data/remote/remote_family_service.dart';
import '../models/family_group.dart';
import '../models/family_member.dart';
import 'service_providers.dart';

/// State for the current family group and its members.
class FamilyState {
  final FamilyGroup? currentFamily;
  final List<FamilyMember> members;
  final bool isLoading;
  final String? error;

  const FamilyState({
    this.currentFamily,
    this.members = const [],
    this.isLoading = false,
    this.error,
  });

  FamilyState copyWith({
    FamilyGroup? currentFamily,
    List<FamilyMember>? members,
    bool? isLoading,
    String? error,
  }) {
    return FamilyState(
      currentFamily: currentFamily ?? this.currentFamily,
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class FamilyNotifier extends Notifier<FamilyState> {
  late final FamilyService _service;

  @override
  FamilyState build() {
    _service = ref.watch(familyServiceProvider);
    return const FamilyState();
  }

  /// Loads the current user's family, or auto-creates one (real-API mode).
  /// Falls back to loading `family_001` in mock mode.
  Future<void> loadMyFamily() async {
    if (useRealApi) {
      state = state.copyWith(isLoading: true);
      try {
        final remoteSvc = _service as RemoteFamilyService;
        final family = await remoteSvc.getMyFamily();
        final members = await remoteSvc.getMembers(family.id);

        state = FamilyState(
          currentFamily: family,
          members: members,
          isLoading: false,
        );
      } catch (e) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    } else {
      await loadFamily('family_001');
    }
  }

  Future<void> loadFamily(String familyId) async {
    state = state.copyWith(isLoading: true);
    try {
      final family = await _service.getFamily(familyId);
      final members = await _service.getMembers(familyId);
      state = FamilyState(
        currentFamily: family,
        members: members,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateSettings(Map<String, dynamic> updates) async {
    final familyId = state.currentFamily?.id;
    if (familyId == null) return;
    state = state.copyWith(isLoading: true);
    try {
      final updated = await _service.updateFamily(familyId, updates);
      state = state.copyWith(currentFamily: updated, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateBudgetLimit(double limit) async {
    await updateSettings({'monthlyBudgetLimit': limit});
  }
}

final familyProvider = NotifierProvider<FamilyNotifier, FamilyState>(
  FamilyNotifier.new,
);
