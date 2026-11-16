import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:budgetly/config/budgetly_colors.dart';
import 'package:budgetly/data/family_service.dart';
import 'package:budgetly/data/mock/sample_data.dart';
import 'package:budgetly/models/family_group.dart';
import 'package:budgetly/models/family_invite.dart';
import 'package:budgetly/models/family_member.dart';
import 'package:budgetly/providers/family_provider.dart';
import 'package:budgetly/providers/service_providers.dart';
import 'package:budgetly/screens/settings/link_family_screen.dart';

const inviteLink = 'https://budgetly.app/join?code=TEST123';

final _invite = FamilyInvite(
  inviteCode: 'TEST123',
  inviteLink: inviteLink,
  expiresAt: DateTime.utc(2026, 11, 24),
);

class _FakeFamilyService implements FamilyService {
  _FakeFamilyService({this.exception});

  final Object? exception;

  @override
  Future<FamilyInvite> inviteFamily(
    String familyId,
    Map<String, dynamic> request,
  ) async {
    if (exception != null) throw exception!;
    return _invite;
  }

  @override
  Future<FamilyGroup> createFamily(Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<FamilyGroup> getFamily(String familyId) async =>
      throw UnimplementedError();

  @override
  Future<FamilyGroup> updateFamily(
    String familyId,
    Map<String, dynamic> updates,
  ) async => throw UnimplementedError();

  @override
  Future<void> deleteFamily(String familyId) async {}

  @override
  Future<List<FamilyMember>> getMembers(String familyId) async =>
      throw UnimplementedError();
}

class _FakeFamilyNotifier extends FamilyNotifier {
  _FakeFamilyNotifier(this._state);

  final FamilyState _state;

  @override
  FamilyState build() => _state;
}

Future<void> pumpScreen(WidgetTester tester, {Object? exception}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        familyServiceProvider.overrideWithValue(
          _FakeFamilyService(exception: exception),
        ),
        familyProvider.overrideWith(
          () => _FakeFamilyNotifier(
            FamilyState(
              currentFamily: SampleData.familyGroup,
              isLoading: false,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: [BudgetlyColors.dark]),
        home: const LinkFamilyScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the backend-generated link and a real QR', (tester) async {
    await pumpScreen(tester);

    expect(find.text(inviteLink), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Copy Link'), findsOneWidget);
    expect(find.text('Invite your family'), findsOneWidget);
  });

  testWidgets('copy copies the real invite link', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await pumpScreen(tester);
    await tester.tap(find.text('Copy Link'));
    await tester.pump();

    expect(find.text('Copied!'), findsOneWidget);
    final setData =
        calls.where((c) => c.method == 'Clipboard.setData').toList();
    expect(setData, hasLength(1));
    expect((setData.single.arguments as Map)['text'], inviteLink);

    // Flush the "Copied!" reset timer before the test ends.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('regenerates a fresh invite from the API', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Regenerate'));
    await tester.pumpAndSettle();

    expect(find.text(inviteLink), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('service failure shows an error card with retry', (tester) async {
    await pumpScreen(tester, exception: Exception('boom'));

    expect(
      find.text('Could not generate an invite link. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('non-admin 403 shows the admin-only message', (tester) async {
    final forbidden = DioException(
      requestOptions: RequestOptions(path: '/families/f_1/invite'),
      response: Response(
        requestOptions: RequestOptions(path: '/families/f_1/invite'),
        statusCode: 403,
      ),
    );

    await pumpScreen(tester, exception: forbidden);

    expect(find.text('Only admins can invite members.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });
}