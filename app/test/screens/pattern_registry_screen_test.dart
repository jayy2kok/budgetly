import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:budgetly/config/budgetly_colors.dart';
import 'package:budgetly/models/family_member.dart';
import 'package:budgetly/models/sms_pattern.dart';
import 'package:budgetly/models/user.dart';
import 'package:budgetly/providers/auth_provider.dart';
import 'package:budgetly/providers/family_provider.dart';
import 'package:budgetly/providers/pattern_registry_provider.dart';
import 'package:budgetly/providers/service_providers.dart';
import 'package:budgetly/screens/settings/pattern_builder_screen.dart';
import 'package:budgetly/screens/settings/pattern_registry_screen.dart';
import 'package:budgetly/services/pattern_cache_service.dart';

/// A [PatternCacheService] seeded with a fixed list. Mutations update the list
/// the way the real service's refresh-after-mutation does, without a network.
class _FakePatternCacheService extends PatternCacheService {
  _FakePatternCacheService(List<SmsPattern> seeded) : super(dio: Dio()) {
    debugSetPatterns(seeded);
  }

  final List<String> disabled = [];
  final List<String> enabled = [];
  final List<String> promoted = [];

  @override
  Future<void> refreshPatterns() async {}

  @override
  Future<SmsPattern> disablePattern(String patternId) async {
    disabled.add(patternId);
    final updated = _withState(
      patternId,
      hiddenForFamily: true,
      active: false,
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<SmsPattern> enablePattern(String patternId) async {
    enabled.add(patternId);
    final updated = _withState(
      patternId,
      hiddenForFamily: false,
      active: true,
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<SmsPattern> promotePattern(String patternId) async {
    promoted.add(patternId);
    throw const _PromoteFailure();
  }

  void _replace(SmsPattern updated) {
    debugSetPatterns([
      for (final p in patterns) p.id == updated.id ? updated : p,
    ]);
  }

  SmsPattern _withState(
    String patternId, {
    required bool hiddenForFamily,
    required bool active,
  }) {
    final p = patterns.firstWhere((candidate) => candidate.id == patternId);
    return SmsPattern(
      id: p.id,
      sender: p.sender,
      template: p.template,
      extractionMap: p.extractionMap,
      fixedValues: p.fixedValues,
      sampleMessage: p.sampleMessage,
      categoryName: p.categoryName,
      usageCount: p.usageCount,
      scope: p.scope,
      ownerFamilyGroupId: p.ownerFamilyGroupId,
      createdByUserId: p.createdByUserId,
      source: p.source,
      active: p.scope == PatternScope.global ? true : active,
      hiddenForFamily:
          p.scope == PatternScope.global ? hiddenForFamily : false,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
    );
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
  bool active = true,
  bool hiddenForFamily = false,
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
      active: active,
      hiddenForFamily: hiddenForFamily,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 6, 1),
    );

AuthState _authState() => AuthState(
      status: AuthStatus.authenticated,
      user: _user(),
      accessToken: 'token',
      refreshToken: 'refresh',
    );

Future<ProviderContainer> _pumpRegistryScreen(
  WidgetTester tester, {
  required List<SmsPattern> patterns,
  List<FamilyMember> members = const [],
  bool withRouter = false,
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

  final theme = ThemeData(extensions: [BudgetlyColors.dark]);

  if (withRouter) {
    final router = GoRouter(
      initialLocation: '/settings/patterns',
      routes: [
        GoRoute(
          path: '/settings/patterns',
          builder: (context, state) => const PatternRegistryScreen(),
        ),
        GoRoute(
          path: '/settings/patterns/new',
          builder: (context, state) => PatternBuilderScreen(
            patternId: state.uri.queryParameters['patternId'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: theme, routerConfig: router),
      ),
    );
  } else {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme,
          home: const PatternRegistryScreen(),
        ),
      ),
    );
  }
  await tester.pumpAndSettle();
  return container;
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
      expect(find.text('Active'), findsNWidgets(3));
      expect(find.text('0 uses'), findsNWidgets(3));
    });

    testWidgets('there is no New pattern action in the registry', (
      tester,
    ) async {
      await _pumpRegistryScreen(
        tester,
        patterns: [_pattern(id: 'p-global', sender: 'HDFCBK', template: 'T')],
      );

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('New pattern'), findsNothing);
    });

    testWidgets('every visible pattern offers Edit and Disable', (tester) async {
      await _pumpRegistryScreen(
        tester,
        patterns: [
          _pattern(id: 'p-global', sender: 'HDFCBK', template: 'Spent {amount}'),
          _pattern(
            id: 'p-family',
            sender: 'SBIBNK',
            template: 'Rs.{amount} debited',
            scope: PatternScope.family,
            source: PatternSource.user,
          ),
        ],
      );

      expect(find.byKey(const Key('pattern-edit-p-global')), findsOneWidget);
      expect(find.byKey(const Key('pattern-edit-p-family')), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, 'Disable'),
        findsNWidgets(2),
      );
      expect(find.byTooltip('Delete pattern'), findsNothing);
    });

    testWidgets('disabled and hidden patterns show their status and Enable', (
      tester,
    ) async {
      await _pumpRegistryScreen(
        tester,
        patterns: [
          _pattern(
            id: 'p-hidden',
            sender: 'HDFCBK',
            template: 'Hidden {amount}',
            hiddenForFamily: true,
          ),
          _pattern(
            id: 'p-disabled',
            sender: 'SBIBNK',
            template: 'Disabled {amount}',
            scope: PatternScope.family,
            source: PatternSource.user,
            active: false,
          ),
          _pattern(id: 'p-active', sender: 'ICICI', template: 'Active {amount}'),
        ],
      );

      expect(find.text('Hidden for family'), findsOneWidget);
      expect(find.text('Disabled'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Enable'), findsNWidgets(2));
      expect(find.widgetWithText(TextButton, 'Disable'), findsOneWidget);
    });

    testWidgets('disabling a global hides it for the family', (tester) async {
      final container = await _pumpRegistryScreen(
        tester,
        patterns: [
          _pattern(id: 'p-global', sender: 'HDFCBK', template: 'Spent {amount}'),
        ],
      );

      await tester.tap(find.byKey(const Key('pattern-toggle-p-global')));
      await tester.pumpAndSettle();

      expect(find.text('Hidden for family'), findsOneWidget);
      expect(find.text('Pattern hidden for your family'), findsOneWidget);
      expect(
        container.read(patternRegistryProvider).patterns.single.hiddenForFamily,
        isTrue,
      );
    });

    testWidgets('disabling a family pattern deactivates it', (tester) async {
      await _pumpRegistryScreen(
        tester,
        patterns: [
          _pattern(
            id: 'p-family',
            sender: 'SBIBNK',
            template: 'Rs.{amount} debited',
            scope: PatternScope.family,
            source: PatternSource.user,
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('pattern-toggle-p-family')));
      await tester.pumpAndSettle();

      expect(find.text('Disabled'), findsOneWidget);
      expect(find.text('Pattern disabled'), findsOneWidget);
    });

    testWidgets('enabling a disabled family pattern reactivates it', (
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
            active: false,
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('pattern-toggle-p-family')));
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Pattern enabled'), findsOneWidget);
    });

    testWidgets('Edit opens the builder with the pattern id', (tester) async {
      await _pumpRegistryScreen(
        tester,
        withRouter: true,
        patterns: [
          _pattern(
            id: 'p-family',
            sender: 'SBIBNK',
            template: 'Rs.{amount} debited',
            scope: PatternScope.family,
            source: PatternSource.user,
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('pattern-edit-p-family')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Pattern'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
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

    testWidgets('empty registry points to the inbox', (tester) async {
      await _pumpRegistryScreen(tester, patterns: const []);

      expect(
        find.text('No patterns yet — define one from a non-transaction message'),
        findsOneWidget,
      );
    });
  });
}