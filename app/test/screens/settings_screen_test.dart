import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budgetly/config/budgetly_colors.dart';
import 'package:budgetly/data/mock/sample_data.dart';
import 'package:budgetly/models/family_member.dart';
import 'package:budgetly/models/user.dart';
import 'package:budgetly/providers/auth_provider.dart';
import 'package:budgetly/providers/family_provider.dart';
import 'package:budgetly/providers/preferences_provider.dart';
import 'package:budgetly/providers/sms_provider.dart';
import 'package:budgetly/screens/settings/settings_screen.dart';

// ── Fakes ─────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final User? _user;

  @override
  AuthState build() => AuthState(
    status: _user == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated,
    user: _user,
  );
}

class _FakeFamilyNotifier extends FamilyNotifier {
  _FakeFamilyNotifier(this._state);

  final FamilyState _state;

  /// Updates requested through the notifier (e.g. the expense-alert toggle).
  final List<Map<String, dynamic>> settingsUpdates = [];

  @override
  FamilyState build() => _state;

  @override
  Future<void> updateSettings(Map<String, dynamic> updates) async {
    settingsUpdates.add(updates);
  }
}

class _FakeSmsNotifier extends SmsNotifier {
  _FakeSmsNotifier(this._state);

  final SmsState _state;

  @override
  SmsState build() => _state;
}

// ── Test rig ──────────────────────────────────────────────────────

late ProviderContainer container;

Future<void> pumpApp(
  WidgetTester tester, {
  List<FamilyMember>? members,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  // The settings screen is a tall CustomScrollView; give the test a tall
  // surface so every sliver (including NOTIFICATIONS and ABOUT) is built.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  container = ProviderContainer(
    overrides: [
      authProvider.overrideWith(() => _FakeAuthNotifier(SampleData.user1)),
      familyProvider.overrideWith(
        () => _FakeFamilyNotifier(
          FamilyState(
            currentFamily: SampleData.familyGroup,
            members: members ?? SampleData.members,
            isLoading: false,
          ),
        ),
      ),
      smsProvider.overrideWith(
        () => _FakeSmsNotifier(
          SmsState(
            smsPermissionGranted: false,
            backgroundServiceEnabled: true,
            cachedPatternCount: 142,
            lastSyncTime: DateTime.utc(2026, 11, 10, 9),
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(extensions: [BudgetlyColors.dark]),
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The switches render in tree order:
/// 0 = Background Service (SMS & Parsing), 1 = Push, 2 = Alerts.
List<Switch> switches(WidgetTester tester) =>
    tester.widgetList<Switch>(find.byType(Switch)).toList();

/// The [_SettingsRow] (a `GestureDetector`) wrapping `label`.
Finder rowOf(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
    .first;

// ── Tests ─────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('notification toggles are real preferences', () {
    testWidgets('reflect persisted values on launch', (tester) async {
      SharedPreferences.setMockInitialValues({
        PreferencesNotifier.pushNotificationsKey: true,
        PreferencesNotifier.budgetAlertsKey: false,
      });
      await pumpApp(tester);

      final values = switches(tester);
      expect(values, hasLength(3));
      expect(values[1].value, isTrue); // Push Notifications
      expect(values[2].value, isFalse); // Budget Alerts restored
    });

    testWidgets('toggling updates the provider and persists', (tester) async {
      await pumpApp(tester);

      expect(switches(tester)[2].value, isTrue); // Budget Alerts default on

      await tester.tap(find.byType(Switch).at(2));
      await tester.pumpAndSettle();

      expect(container.read(preferencesProvider).budgetAlerts, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PreferencesNotifier.budgetAlertsKey), isFalse);

      // Admins also flip the family-wide setting the backend uses to gate
      // expense-alert pushes.
      final familyNotifier =
          container.read(familyProvider.notifier) as _FakeFamilyNotifier;
      expect(
        familyNotifier.settingsUpdates,
        [
          {'expenseAlertsEnabled': false},
        ],
      );

      // The switch reflects the new persisted value, not a transient copy.
      expect(switches(tester)[2].value, isFalse);
    });

    testWidgets('defaults match the previous display (on/on)', (
      tester,
    ) async {
      await pumpApp(tester);

      final values = switches(tester);
      expect(values[1].value, isTrue); // Push Notifications
      expect(values[2].value, isTrue); // Budget Alerts
    });
  });

  group('Background Service toggle stays wired', () {
    testWidgets('toggling it flips smsProvider state', (tester) async {
      await pumpApp(tester);

      expect(container.read(smsProvider).backgroundServiceEnabled, isTrue);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(container.read(smsProvider).backgroundServiceEnabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('background_sms_service_enabled'), isFalse);
    });
  });

  group('non-functional rows no longer look tappable', () {
    for (final label in [
      'Currency',
      'Language',
      'Permissions',
      'Version',
      'Privacy Policy',
      'Terms of Service',
    ]) {
      testWidgets('"$label" has no tap handler and no chevron', (tester) async {
        await pumpApp(tester);

        final row = rowOf(label);
        expect(
          tester.widget<GestureDetector>(row).onTap,
          isNull,
          reason: '"$label" should be informational, not tappable',
        );
        expect(
          find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)),
          findsNothing,
          reason: '"$label" should not render a navigation chevron',
        );
      });
    }

    testWidgets('tapping a disabled row does nothing', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Currency'));
      await tester.pumpAndSettle();

      // Still on the settings screen — no navigation, no dialog.
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('wired rows keep their chevron', (tester) async {
      await pumpApp(tester);

      for (final label in [
        'Appearance',
        'Message Inbox',
        'Family Members',
        'Join Family',
      ]) {
        final row = rowOf(label);
        expect(
          tester.widget<GestureDetector>(row).onTap,
          isNotNull,
          reason: '"$label" should be tappable',
        );
        expect(
          find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)),
          findsOneWidget,
          reason: '"$label" should render a navigation chevron',
        );
      }
    });
  });

  group('family member count is singular-aware', () {
    testWidgets('single-member family renders "1 member"', (tester) async {
      await pumpApp(tester, members: [SampleData.members.first]);

      expect(find.text('1 member'), findsOneWidget);
      expect(find.text('1 members'), findsNothing);
    });

    testWidgets('multi-member family renders "N members"', (tester) async {
      await pumpApp(tester);

      expect(find.text('3 members'), findsOneWidget);
    });
  });
}
