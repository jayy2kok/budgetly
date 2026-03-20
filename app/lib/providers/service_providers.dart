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

/// Toggle between mock and real API.
///
/// Set to `true` to use the real Spring Boot API (requires `docker-compose up`).
/// Set to `false` to use in-memory mock data (Phase 2 mode).
const bool useRealApi = false;

// ── API client initialisation ─────────────────────────────────

/// Initialises the Dio client once when first used in real-API mode.
final _apiClientInitProvider = Provider<void>((ref) {
  if (useRealApi) ApiClient.instance.init();
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
