import '../../models/user.dart';
import '../../models/family_group.dart';
import '../../models/family_member.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../models/message.dart';

/// Seed data matching the Stitch screen designs.
///
/// Used by mock services in Phase 2 to provide realistic data
/// without a backend connection.
class SampleData {
  SampleData._();

  // ─── Users ───
  static final user1 = User(
    id: 'user_001',
    googleId: 'google_001',
    displayName: 'Arjun Sharma',
    email: 'arjun.sharma@gmail.com',
    avatarUrl: null,
    createdAt: DateTime(2025, 1, 15),
  );

  static final user2 = User(
    id: 'user_002',
    googleId: 'google_002',
    displayName: 'Priya Sharma',
    email: 'priya.sharma@gmail.com',
    avatarUrl: null,
    createdAt: DateTime(2025, 1, 16),
  );

  static final user3 = User(
    id: 'user_003',
    googleId: 'google_003',
    displayName: 'Rohan Sharma',
    email: 'rohan.sharma@gmail.com',
    avatarUrl: null,
    createdAt: DateTime(2025, 2, 1),
  );

  static List<User> get allUsers => [user1, user2, user3];

  // ─── Family Group ───
  static final familyGroup = FamilyGroup(
    id: 'family_001',
    name: 'Sharma Family',
    avatarInitial: 'S',
    defaultCurrency: 'INR',
    regionFormat: 'IN',
    expenseAlertsEnabled: true,
    monthlyBudgetLimit: 350000,
    createdByUserId: 'user_001',
    createdAt: DateTime(2025, 1, 15),
  );

  // ─── Family Members ───
  static final members = [
    FamilyMember(
      id: 'member_001',
      userId: 'user_001',
      familyGroupId: 'family_001',
      user: user1,
      role: MemberRole.admin,
      status: MemberStatus.active,
      joinedAt: DateTime(2025, 1, 15),
    ),
    FamilyMember(
      id: 'member_002',
      userId: 'user_002',
      familyGroupId: 'family_001',
      user: user2,
      role: MemberRole.member,
      status: MemberStatus.active,
      joinedAt: DateTime(2025, 1, 16),
    ),
    FamilyMember(
      id: 'member_003',
      userId: 'user_003',
      familyGroupId: 'family_001',
      user: user3,
      role: MemberRole.member,
      status: MemberStatus.active,
      joinedAt: DateTime(2025, 2, 1),
    ),
  ];

  // ─── Categories ───
  static List<Category> categories = [
    Category(
      id: 'cat_001',
      familyGroupId: 'family_001',
      name: 'Groceries',
      icon: '🛒',
      budgetLimit: 25000,
      color: '#34D399',
    ),
    Category(
      id: 'cat_002',
      familyGroupId: 'family_001',
      name: 'Dining',
      icon: '🍽️',
      budgetLimit: 15000,
      color: '#FB7185',
    ),
    Category(
      id: 'cat_003',
      familyGroupId: 'family_001',
      name: 'Transport',
      icon: '🚗',
      budgetLimit: 12000,
      color: '#60A5FA',
    ),
    Category(
      id: 'cat_004',
      familyGroupId: 'family_001',
      name: 'Housing',
      icon: '🏠',
      budgetLimit: 120000,
      color: '#FBBF24',
    ),
    Category(
      id: 'cat_005',
      familyGroupId: 'family_001',
      name: 'Bills',
      icon: '📄',
      budgetLimit: 18000,
      color: '#A78BFA',
    ),
    Category(
      id: 'cat_006',
      familyGroupId: 'family_001',
      name: 'Health',
      icon: '💊',
      budgetLimit: 10000,
      color: '#2DD4BF',
    ),
    Category(
      id: 'cat_007',
      familyGroupId: 'family_001',
      name: 'Entertainment',
      icon: '🎬',
      budgetLimit: 8000,
      color: '#F472B6',
    ),
    Category(
      id: 'cat_008',
      familyGroupId: 'family_001',
      name: 'Shopping',
      icon: '🛍️',
      budgetLimit: 15000,
      color: '#FB923C',
    ),
  ];

  // ─── Transactions (matching Stitch dashboard amounts) ───
  static List<Transaction> transactions = [
    Transaction(
      id: 'txn_001',
      familyGroupId: 'family_001',
      createdByUserId: 'user_001',
      categoryId: 'cat_001',
      amount: 8942,
      merchant: 'Grocery Mart',
      type: TransactionType.expense,
      sourceType: SourceType.aiParsed,
      sourceRawText:
          'Rs.8,942.00 debited from a/c **1234 for Grocery Mart on 28-02-26',
      aiVerified: true,
      transactionDate: DateTime.now().subtract(const Duration(hours: 2)),
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Transaction(
      id: 'txn_002',
      familyGroupId: 'family_001',
      createdByUserId: 'user_001',
      categoryId: 'cat_004',
      amount: 45000,
      merchant: 'Monthly Rent',
      type: TransactionType.expense,
      sourceType: SourceType.aiParsed,
      sourceRawText:
          'Rs.45,000.00 debited from a/c **9876 towards Monthly Rent on 27-02-26',
      aiVerified: true,
      transactionDate: DateTime.now().subtract(const Duration(days: 1)),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Transaction(
      id: 'txn_003',
      familyGroupId: 'family_001',
      createdByUserId: 'user_002',
      categoryId: 'cat_002',
      amount: 3250,
      merchant: 'Dinner Night',
      type: TransactionType.expense,
      transactionDate: DateTime.now().subtract(const Duration(days: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Transaction(
      id: 'txn_004',
      familyGroupId: 'family_001',
      createdByUserId: 'user_001',
      categoryId: 'cat_007',
      amount: 4150,
      merchant: 'Digital Store',
      type: TransactionType.expense,
      transactionDate: DateTime.now().subtract(const Duration(hours: 5)),
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    Transaction(
      id: 'txn_005',
      familyGroupId: 'family_001',
      createdByUserId: 'user_001',
      categoryId: 'cat_003',
      amount: 18500,
      merchant: 'Travel Refund',
      type: TransactionType.income,
      transactionDate: DateTime.now().subtract(const Duration(days: 1)),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Transaction(
      id: 'txn_006',
      familyGroupId: 'family_001',
      createdByUserId: 'user_002',
      categoryId: 'cat_002',
      amount: 540,
      merchant: 'Coffee House',
      type: TransactionType.expense,
      transactionDate: DateTime.now().subtract(
        const Duration(days: 1, hours: 3),
      ),
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
    ),
    Transaction(
      id: 'txn_007',
      familyGroupId: 'family_001',
      createdByUserId: 'user_001',
      categoryId: 'cat_003',
      amount: 3520,
      merchant: 'Fuel Refill',
      type: TransactionType.expense,
      transactionDate: DateTime.now().subtract(
        const Duration(days: 1, hours: 6),
      ),
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
    ),
    Transaction(
      id: 'txn_008',
      familyGroupId: 'family_001',
      createdByUserId: 'user_001',
      categoryId: 'cat_007',
      amount: 649,
      merchant: 'Streaming Service',
      type: TransactionType.subscription,
      transactionDate: DateTime.now().subtract(const Duration(days: 3)),
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Transaction(
      id: 'txn_009',
      familyGroupId: 'family_001',
      createdByUserId: 'user_001',
      categoryId: 'cat_001',
      amount: 12420,
      merchant: 'Organic Groceries',
      type: TransactionType.expense,
      sourceType: SourceType.aiParsed,
      sourceRawText:
          'Rs.12,420.00 spent at Organic Groceries via ICICI CC **5678 on 28-02-26',
      aiVerified: true,
      transactionDate: DateTime.now().subtract(const Duration(hours: 4)),
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  // ─── Messages ───
  static final messages = [
    Message(
      id: 'msg_001',
      userId: 'user_001',
      familyGroupId: 'family_001',
      sender: 'HDFCBK',
      rawText:
          'Rs.8,942.00 debited from a/c **1234 for Grocery Mart on 28-02-26',
      status: MessageStatus.pending,
      triageResult: TriageResult.transaction,
      receivedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Message(
      id: 'msg_002',
      userId: 'user_001',
      sender: 'SBIBNK',
      rawText: 'Your OTP is 482910. Valid for 5 mins.',
      status: MessageStatus.ignored,
      triageResult: TriageResult.otp,
      receivedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Message(
      id: 'msg_003',
      userId: 'user_001',
      familyGroupId: 'family_001',
      sender: 'ICICIB',
      rawText:
          'Rs.12,420.00 spent at Organic Groceries via ICICI CC **5678 on 28-02-26',
      status: MessageStatus.pending,
      triageResult: TriageResult.transaction,
      receivedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    Message(
      id: 'msg_004',
      userId: 'user_001',
      sender: 'AMAZON',
      rawText: 'Your order #123-456 has been delivered. Rate your experience.',
      status: MessageStatus.ignored,
      triageResult: TriageResult.promo,
      receivedAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    Message(
      id: 'msg_005',
      userId: 'user_001',
      familyGroupId: 'family_001',
      sender: 'AXISBK',
      rawText:
          'Rs.45,000.00 debited from a/c **9876 towards Monthly Rent on 27-02-26',
      status: MessageStatus.pending,
      triageResult: TriageResult.transaction,
      receivedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  // ─── Dashboard (matching Stitch design) ───
  static double monthlyBudgetLimit = 350000;
  static const double totalSpent = 208000;
  static double get leftToSpend => monthlyBudgetLimit - totalSpent;
  static const double dailyAverage = 4500;
  static const double projectedSpend = 310000;
  static double get estimatedSavings => monthlyBudgetLimit - projectedSpend;
}
