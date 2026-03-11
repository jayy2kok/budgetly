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
      sourceType: SourceType.regexLocal,
      sourceRawText:
          'Rs.8,942.00 debited from a/c **1234 for Grocery Mart on 28-02-26',
      matchedPatternId: 'pat_001',
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
      sourceType: SourceType.regexLocal,
      sourceRawText:
          'Rs.45,000.00 debited from a/c **9876 towards Monthly Rent on 27-02-26',
      matchedPatternId: 'pat_003',
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
      sourceType: SourceType.regexLocal,
      sourceRawText:
          'Rs.12,420.00 spent at Organic Groceries via ICICI CC **5678 on 28-02-26',
      matchedPatternId: 'pat_002',
      transactionDate: DateTime.now().subtract(const Duration(hours: 4)),
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  // ─── Messages (new: covers incomplete, unprocessed, non-financial) ───
  static final messages = [
    // ── Incomplete: regex matched but missing 'timestamp' ──
    Message(
      id: 'msg_001',
      userId: 'user_001',
      familyGroupId: 'family_001',
      sender: 'HDFCBK',
      rawText: 'Rs.2,340 debited for BigBasket from HDFC a/c',
      status: MessageStatus.pending,
      parseSource: ParseSource.regexLocal,
      matchedPatternId: 'pat_001',
      extractedData: {'amount': '2,340', 'merchant': 'BigBasket'},
      receivedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),

    // ── Incomplete: regex matched but missing 'merchant' ──
    Message(
      id: 'msg_002',
      userId: 'user_001',
      familyGroupId: 'family_001',
      sender: 'SBIBNK',
      rawText: 'Rs.5,200 debited from SBI a/c **4321 on 01/03/26',
      status: MessageStatus.pending,
      parseSource: ParseSource.regexLocal,
      matchedPatternId: 'pat_004',
      extractedData: {'amount': '5,200', 'timestamp': '01/03/26'},
      receivedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),

    // ── Unprocessed: no regex match (unknown sender) ──
    Message(
      id: 'msg_003',
      userId: 'user_001',
      familyGroupId: 'family_001',
      sender: 'KOTAKB',
      rawText:
          'INR 1,850 spent on your Kotak card ending 7890 at Swiggy on 02-Mar-26. Avl bal: INR 45,230.',
      status: MessageStatus.pending,
      receivedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),

    // ── Unprocessed: no regex match (unknown format) ──
    Message(
      id: 'msg_004',
      userId: 'user_001',
      familyGroupId: 'family_001',
      sender: 'YESBNK',
      rawText:
          'You have done a UPI txn of Rs 750.00 to IRCTC on 03-03-26. UPI Ref: 406312345678.',
      status: MessageStatus.pending,
      receivedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),

    // ── Unprocessed: another unknown ──
    Message(
      id: 'msg_005',
      userId: 'user_001',
      sender: 'PAYTMB',
      rawText:
          'Payment of Rs.320 to Uber via Paytm Payments Bank. Ref No 987654321.',
      status: MessageStatus.pending,
      receivedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),

    // ── Non-financial: OTP ──
    Message(
      id: 'msg_006',
      userId: 'user_001',
      sender: 'SBIBNK',
      rawText: 'Your OTP is 482910. Valid for 5 mins. Do not share.',
      status: MessageStatus.ignored,
      nonFinancialCategory: NonFinancialCategory.otp,
      receivedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),

    // ── Non-financial: Promo ──
    Message(
      id: 'msg_007',
      userId: 'user_001',
      sender: 'AMAZON',
      rawText:
          'Flash Sale! Up to 80% off on electronics. Shop now at amazon.in. T&C apply.',
      status: MessageStatus.ignored,
      nonFinancialCategory: NonFinancialCategory.promo,
      receivedAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),

    // ── Non-financial: Delivery ──
    Message(
      id: 'msg_008',
      userId: 'user_001',
      sender: 'AMAZON',
      rawText:
          'Your order #123-456 has been delivered. Rate your experience at amazon.in/feedback',
      status: MessageStatus.ignored,
      nonFinancialCategory: NonFinancialCategory.delivery,
      receivedAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),

    // ── Non-financial: Personal ──
    Message(
      id: 'msg_009',
      userId: 'user_001',
      sender: 'HDFCBK',
      rawText:
          'Dear Customer, your FD of Rs. 1,00,000 has matured. Please visit your nearest branch.',
      status: MessageStatus.ignored,
      nonFinancialCategory: NonFinancialCategory.personal,
      receivedAt: DateTime.now().subtract(const Duration(hours: 8)),
    ),

    // ── Deleted by user ──
    Message(
      id: 'msg_010',
      userId: 'user_001',
      sender: 'TMBANK',
      rawText: 'Pre-approved personal loan up to 5L. Apply now!',
      status: MessageStatus.rejected,
      nonFinancialCategory: NonFinancialCategory.promo,
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
