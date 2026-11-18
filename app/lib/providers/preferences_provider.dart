import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User notification preferences, persisted locally with SharedPreferences.
///
/// These are the Settings screen's notification toggles. Values survive app
/// restarts, mirroring how the SMS background-service toggle is persisted in
/// [SmsNotifier].
class PreferencesState {
  final bool pushNotifications;
  final bool budgetAlerts;

  const PreferencesState({
    this.pushNotifications = true,
    this.budgetAlerts = true,
  });

  PreferencesState copyWith({
    bool? pushNotifications,
    bool? budgetAlerts,
  }) {
    return PreferencesState(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      budgetAlerts: budgetAlerts ?? this.budgetAlerts,
    );
  }
}

class PreferencesNotifier extends Notifier<PreferencesState> {
  /// SharedPreferences keys for each toggle.
  static const String pushNotificationsKey = 'notifications_push_enabled';
  static const String budgetAlertsKey = 'notifications_budget_alerts_enabled';

  @override
  PreferencesState build() {
    _load();
    return const PreferencesState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = PreferencesState(
      pushNotifications: prefs.getBool(pushNotificationsKey) ?? true,
      budgetAlerts: prefs.getBool(budgetAlertsKey) ?? true,
    );
  }

  Future<void> setPushNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(pushNotificationsKey, enabled);
    state = state.copyWith(pushNotifications: enabled);
  }

  Future<void> setBudgetAlerts(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(budgetAlertsKey, enabled);
    state = state.copyWith(budgetAlerts: enabled);
  }
}

final preferencesProvider =
    NotifierProvider<PreferencesNotifier, PreferencesState>(
      PreferencesNotifier.new,
    );
