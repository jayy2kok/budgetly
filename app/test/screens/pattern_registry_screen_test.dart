import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:budgetly/config/budgetly_colors.dart';
import 'package:budgetly/models/family_member.dart';
import 'package:budgetly/models/sms_pattern.dart';
import 'package:budgetly/models/user.dart';
import 'package:budgetly/providers/auth_provider.dart';
import 'package:budgetly/providers/family_provider.dart';
import 'package:budgetly/providers/service_providers.dart';
import 'package:budgetly/screens/settings/pattern_registry_screen.dart';
import 'package:budgetly/services/pattern_cache_service.dart';

/// A [PatternCacheService] seeded with a fixed list; refreshPatterns is a no-op
/// so the screen renders exactly the seeded data.
class _FakePatternCacheService extends PatternCacheService {
  _FakePatternCacheService(List<SmsPattern> seeded) : super(dio: Dio()) {
    debugSetPatterns(seeded);
  }

  final List<String> deleted = [];
  final List<String> promoted = [];

  @override
  Future<void> refreshPatterns() async {}

  @override
  Future<void> deletePattern(String patternId) async {
    deleted.add(patternId);
    debugSetPatterns(patterns.where((p) => p.id != patternId).toList());
  }

  @override
  Future<SmsPattern> promotePattern(String patternId) async {
    promoted.add(patternId);
    throw const _PromoteFailure();
  }
}

class _PromoteFailure implements Exception {
  const _PromoteFailure();
  @override
  String toString() => 'Promote not supported in this test';
}

const _userId = 'user-1';

User _user() => User(
      id: _userId,
      googleId: 'g-1',
      displayName: 'Jay Raj',
      email: 'jay@example.com',
      createdAt: DateTime.utc(2026, 1, 1),
    );

FamilyMember _member({required String userId, MemberRole role = MemberRole.member}) =>
    FamilyMember(
      id: 'fm-$userId',
      userId: userId,
      familyGroupId: 'fam-1',
      role: role,
      status: MemberStatus.active,
      joinedAt: DateTime.utc(2026, 1, 1),
    );

SmsPattern _pattern({
  required String id,
  required String sender,
  required String template,
  PatternScope scope = PatternScope.global,
  PatternSource source = PatternSource.llm,
  String? createdByUserId,
  int usageCount = 0,
}) =>
    SmsPattern(
      id: id,
      sender: sender,
      template: template,
      extractionMap: const ExtractionMap(amount: 'amount', merchant: 'merchant'),
      sampleMessage: 'sample for $sender',
      usageCount: usageCount,
      scope: scope,
      ownerFamilyGroupId:
          scope == PatternScope.family ? 'fam-1' : null,
      createdByUserId: createdByUserId,
      source: source,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 6, 1),
    );

AuthState _authState() => AuthState(
      status: AuthStatus.authenticated,
      user: _user(),
      accessToken: 'token',
      refreshToken: 'refresh',
    );

Future<void> _pumpRegistryScreen(
  WidgetTester tester, {
  required List<SmsPattern> patterns,
  List<FamilyMember> members = const [],
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final cache = _FakePatternCacheService(patterns);

  final container = ProviderContainer(
    overrides: [
      patternCacheServiceProvider.overrideWithValue(cache),
      familyProvider.overrideWith(
        () => _StubFamilyNotifier(FamilyState(members: members)),
      ),
      authProvider.overrideWith(() => _StubAuthNotifier(_authState())),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(extensions: [BudgetlyColors.dark]),
        home: const PatternRegistryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _StubFamilyNotifier extends FamilyNotifier {
  _StubFamilyNotifier(this._state);

  final FamilyState _state;

  @override
  FamilyState build() => _state;
}

class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

void main() {
  group('PatternRegistryScreen', () {
    testWidgets('groups global and family patterns by sender', (tester) async {
      await _pumpRegistryScreen(
        tester,
        patterns: [
          _pattern(id: 'p-global', sender: 'HDFCBK', template: 'Spent Rs {amount}'),
          _pattern(
            id: 'p-family',
            sender: 'HDFCBK',
            template: 'Rs.{amount} debited',
            scope: PatternScope.family,
            source: PatternSource.user,
            createdByUserId: _userId,
          ),
          _pattern(id: 'p-sbi', sender: 'SBIBNK', template: 'Paid {amount}'),
        ],
      );

      // Two sender headers, HDFCBK holds both its patterns.
      expect(find.text('HDFCBK'), findsOneWidget);
      expect(find.text('SBIBNK'), findsOneWidget);
      expect(find.text('Spent Rs {amount}'), findsOneWidget);
      expect(find.text('Rs.{amount} debited'), findsOneWidget);
      expect(find.text('Paid {amount}'), findsOneWidget);

      // Scope + source tags.
      expect(find.text('Global'), findsNWidgets(2));
      expect(find.text('Family'), findsOneWidget);
      expect(find.text('by LLM'), findsNWidgets(2));
      expect(find.text('by you'), findsOneWidget);

      // Active/usage indicator.
      expect(find.text('0 uses'), findsNWidgets(3));
    });

    testWidgets('authored family patterns are deletable, global are not', (
      tester,
    ) async {
      await _pumpRegistryScreen(
        tester,
        patterns: [
          _pattern(id: 'p-global', sender: 'HDFCBK', template: 'Spent Rs {amount}'),
          _pattern(
            id: 'p-family',
            sender: 'HDFCBK',
            template: 'Rs.{amount} debited',
            scope: PatternScope.family,
            source: PatternSource.user,
            createdByUserId: _userId,
          ),
        ],
      );

      // Only the family-authored row exposes delete.
      expect(find.byTooltip('Delete pattern'), findsOneWidget);
    });

    testWidgets('another user cannot delete a family pattern', (tester) async {
      await _pumpRegistryScreen(
        tester,
        patterns: [
          _pattern(
            id: 'p-other',
            sender: 'HDFCBK',
            template: 'Rs.{amount} debited',
            scope: PatternScope.family,
            source: PatternSource.user,
            createdByUserId: 'someone-else',
          ),
        ],
      );

      expect(find.byTooltip('Delete pattern'), findsNothing);
    });

    testWidgets('family admins see a promote action on family patterns', (
      tester,
    ) async {
      await _pumpRegistryScreen(
        tester,
        patterns: [
          _pattern(id: 'p-global', sender: 'HDFCBK', template: 'Spent Rs {amount}'),
          _pattern(
            id: 'p-family',
            sender: 'SBIBNK',
            template: 'Rs.{amount} debited',
            scope: PatternScope.family,
            source: PatternSource.user,
            createdByUserId: 'someone-else',
          ),
        ],
        members: [_member(userId: _userId, role: MemberRole.admin)],
      );

      // Promote only applies to family-scoped patterns.
      expect(find.byTooltip('Promote to global'), findsOneWidget);
    });

    testWidgets('non-admin members do not see the promote action', (
      tester,
    ) async {
      await _pumpRegistryScreen(
        tester,
        patterns: [
          _pattern(
            id: 'p-family',
            sender: 'SBIBNK',
            template: 'Rs.{amount} debited',
            scope: PatternScope.family,
            source: PatternSource.user,
            createdByUserId: _userId,
          ),
        ],
        members: [_member(userId: _userId)],
      );

      expect(find.byTooltip('Promote to global'), findsNothing);
    });

    testWidgets('deleting an authored pattern asks for confirmation', (
      tester,
    ) async {
      await _pumpRegistryScreen(
        tester,
        patterns: [
          _pattern(
            id: 'p-family',
            sender: 'HDFCBK',
            template: 'Rs.{amount} debited',
            scope: PatternScope.family,
            source: PatternSource.user,
            createdByUserId: _userId,
          ),
        ],
      );

      await tester.tap(find.byTooltip('Delete pattern'));
      await tester.pumpAndSettle();

      expect(find.text('Delete pattern?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      // The dialog closed and the row is gone.
      expect(find.text('Delete pattern?'), findsNothing);
      expect(find.text('Rs.{amount} debited'), findsNothing);
    });

    testWidgets('empty registry shows the authoring hint', (tester) async {
      await _pumpRegistryScreen(tester, patterns: const []);

      expect(
        find.text('No patterns yet — author one from a failed message'),
        findsOneWidget,
      );
    });
  });
}