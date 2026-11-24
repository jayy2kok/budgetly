import 'package:budgetly/providers/backend_base_url_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeBackendBaseUrl', () {
    test('prepends http:// when no scheme is given', () {
      expect(
        normalizeBackendBaseUrl('192.168.31.50:8080/api/v1'),
        'http://192.168.31.50:8080/api/v1',
      );
    });

    test('keeps an explicit http:// scheme', () {
      expect(
        normalizeBackendBaseUrl('http://10.0.2.2:8080/api/v1'),
        'http://10.0.2.2:8080/api/v1',
      );
    });

    test('keeps an explicit https:// scheme', () {
      expect(
        normalizeBackendBaseUrl('https://api.budgetly.example/v1'),
        'https://api.budgetly.example/v1',
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        normalizeBackendBaseUrl('  http://localhost:8080/api/v1  '),
        'http://localhost:8080/api/v1',
      );
    });

    test('drops a single trailing slash', () {
      expect(
        normalizeBackendBaseUrl('http://localhost:8080/api/v1/'),
        'http://localhost:8080/api/v1',
      );
    });

    test('returns null for blank input', () {
      expect(normalizeBackendBaseUrl('   '), isNull);
      expect(normalizeBackendBaseUrl(''), isNull);
    });

    test('returns null for a non-http(s) scheme', () {
      expect(normalizeBackendBaseUrl('ftp://host/api'), isNull);
    });

    test('returns null for a scheme without a host', () {
      expect(normalizeBackendBaseUrl('http://'), isNull);
    });
  });
}