import 'package:flutter_test/flutter_test.dart';

import 'package:budgetly/models/family_invite.dart';

void main() {
  group('FamilyInvite JSON', () {
    test('parses the POST /families/{id}/invite response', () {
      final invite = FamilyInvite.fromJson({
        'inviteCode': 'ABC123XYZ789',
        'inviteLink': 'https://budgetly.app/join?code=ABC123XYZ789',
        'expiresAt': '2026-11-24T10:00:00Z',
      });

      expect(invite.inviteCode, 'ABC123XYZ789');
      expect(invite.inviteLink, 'https://budgetly.app/join?code=ABC123XYZ789');
      expect(invite.expiresAt, DateTime.parse('2026-11-24T10:00:00Z'));
    });

    test('tolerates missing optional fields', () {
      final invite = FamilyInvite.fromJson(const {});
      expect(invite.inviteCode, isNull);
      expect(invite.inviteLink, isNull);
      expect(invite.expiresAt, isNull);
    });

    test('toJson round-trips the wire shape', () {
      final invite = FamilyInvite.fromJson({
        'inviteCode': 'ABC123XYZ789',
        'inviteLink': 'https://budgetly.app/join?code=ABC123XYZ789',
        'expiresAt': '2026-11-24T10:00:00Z',
      });

      final json = invite.toJson();
      expect(json, {
        'inviteCode': 'ABC123XYZ789',
        'inviteLink': 'https://budgetly.app/join?code=ABC123XYZ789',
        'expiresAt': '2026-11-24T10:00:00.000Z',
      });
    });
  });
}