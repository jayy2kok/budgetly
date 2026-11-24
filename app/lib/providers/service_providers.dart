import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_service.dart';
import '../data/budget_service.dart';
import '../data/category_service.dart';
import '../data/family_service.dart';
import '../data/message_service.dart';
import '../data/transaction_service.dart';

import '../data/mock/mock_auth_service.dart';
import '../data/mock/mock_budget_service.dart';
import '../data/mock/mock_category_service.dart';
import '../data/mock/mock_family_service.dart';
import '../data/mock/mock_message_service.dart';
import '../data/mock/mock_transaction_service.dart';

import '../data/remote/api_client.dart';
import '../data/remote/remote_auth_service.dart';
import '../data/remote/remote_budget_service.dart';
import '../data/remote/remote_category_service.dart';
import '../data/remote/remote_family_service.dart';
import '../data/remote/remote_message_service.dart';
import '../data/remote/remote_transaction_service.dart';
import '../services/pattern_cache_service.dart';
import '../services/sms_inbox_reader.dart';
import 'backend_base_url_provider.dart';

/// Toggle between mock and real API.
///
/// Set to `true` to use the real Spring Boot API (requires `docker-compose up`).
/// Set to `false` to use in-memory mock data (Phase 2 mode).
const bool useRealApi = true;

// ── API client initialisation ─────────────────────────────────

/// Initialises the Dio client once when first used.
///
/// Runs in both real-API and mock mode: PatternCacheService (and other
/// services) read [ApiClient.instance.dio], which must be initialized before
/// they can be constructed — otherwise opening Settings in mock/dev mode
/// throws a LateInitializationError.
///
/// Watches [backendBaseUrlProvider] so a persisted user override is applied to
/// the live Dio client before any remote service is constructed.
final _apiClientInitProvider = Provider<void>((ref) {
  ref.watch(backendBaseUrlProvider);
  ApiClient.instance.init();
});

// ── Service Providers ─────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) {
  ref.watch(_apiClientInitProvider);
  return useRealApi ? RemoteAuthService() : MockAuthService();
});

final familyServiceProvider = Provider<FamilyService>((ref) {
  return useRealApi ? RemoteFamilyService() : MockFamilyService();
});

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return useRealApi ? RemoteTransactionService() : MockTransactionService();
});

final categoryServiceProvider = Provider<CategoryService>((ref) {
  return useRealApi ? RemoteCategoryService() : MockCategoryService();
});

final messageServiceProvider = Provider<MessageService>((ref) {
  return useRealApi ? RemoteMessageService() : MockMessageService();
});

final budgetServiceProvider = Provider<BudgetService>((ref) {
  return useRealApi ? RemoteBudgetService() : MockBudgetService();
});

// ── SMS infrastructure ─────────────────────────────────────────

/// Shared SMS pattern cache. Override in tests with a seeded fake cache.
final patternCacheServiceProvider = Provider<PatternCacheService>((ref) {
  ref.watch(_apiClientInitProvider); // ensure ApiClient.init() runs in real-API mode
  return PatternCacheService();
});

/// SMS inbox reader wired to the shared pattern cache.
/// Override in tests with a fake reader that returns canned messages.
final smsInboxReaderProvider = Provider<SmsInboxReader>((ref) {
  return SmsInboxReader(cache: ref.watch(patternCacheServiceProvider));
});
