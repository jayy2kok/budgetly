import '../models/sms_pattern.dart';

/// In-memory mock cache for SMS regex patterns.
///
/// In production this would persist to sqflite/SharedPreferences
/// and sync with the server via GET /patterns?since=...
class PatternCacheService {
  List<SmsPattern> _patterns = [];
  DateTime? _lastSyncTime;

  /// Number of cached patterns.
  int get patternCount => _patterns.length;

  /// When the cache was last synced.
  DateTime? get lastSyncTime => _lastSyncTime;

  /// All cached patterns.
  List<SmsPattern> get patterns => List.unmodifiable(_patterns);

  /// Load sample patterns (simulates initial cache load).
  Future<void> loadPatterns() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _patterns = _samplePatterns;
    _lastSyncTime = DateTime.now().subtract(const Duration(hours: 2));
  }

  /// Refresh patterns from server (simulates delta sync).
  Future<void> refreshPatterns() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _lastSyncTime = DateTime.now();
    // In production: fetch from GET /patterns?since=_lastSyncTime
  }

  /// Get patterns for a specific sender.
  List<SmsPattern> getPatternsBySender(String sender) {
    return _patterns.where((p) => p.sender == sender).toList();
  }

  // ── Sample patterns ──
  static final _samplePatterns = [
    SmsPattern(
      id: 'pat_001',
      sender: 'HDFCBK',
      regex:
          r'Rs\.(?<amount>[\d,]+\.\d{2}) debited from a/c \*\*(?<account>\d{4}) for (?<merchant>.+?) on (?<timestamp>\d{2}-\d{2}-\d{2})',
      extractionMap: const ExtractionMap(
        amount: 'amount',
        merchant: 'merchant',
        timestamp: 'timestamp',
        accountLast4: 'account',
      ),
      sampleMessage:
          'Rs.8,942.00 debited from a/c **1234 for Grocery Mart on 28-02-26',
      usageCount: 1247,
      createdAt: DateTime(2025, 6, 15),
    ),
    SmsPattern(
      id: 'pat_002',
      sender: 'ICICIB',
      regex:
          r'Rs\.(?<amount>[\d,]+\.\d{2}) spent at (?<merchant>.+?) via ICICI CC \*\*(?<account>\d{4}) on (?<timestamp>\d{2}-\d{2}-\d{2})',
      extractionMap: const ExtractionMap(
        amount: 'amount',
        merchant: 'merchant',
        timestamp: 'timestamp',
        accountLast4: 'account',
      ),
      sampleMessage:
          'Rs.12,420.00 spent at Organic Groceries via ICICI CC **5678 on 28-02-26',
      usageCount: 983,
      createdAt: DateTime(2025, 7, 2),
    ),
    SmsPattern(
      id: 'pat_003',
      sender: 'AXISBK',
      regex:
          r'Rs\.(?<amount>[\d,]+\.\d{2}) debited from a/c \*\*(?<account>\d{4}) towards (?<merchant>.+?) on (?<timestamp>\d{2}-\d{2}-\d{2})',
      extractionMap: const ExtractionMap(
        amount: 'amount',
        merchant: 'merchant',
        timestamp: 'timestamp',
        accountLast4: 'account',
      ),
      sampleMessage:
          'Rs.45,000.00 debited from a/c **9876 towards Monthly Rent on 27-02-26',
      usageCount: 756,
      createdAt: DateTime(2025, 8, 10),
    ),
    SmsPattern(
      id: 'pat_004',
      sender: 'SBIBNK',
      regex:
          r'(?<amount>[\d,]+\.\d{2}) debited.*?(?<merchant>[A-Z][A-Za-z ]+).*?(?<timestamp>\d{2}/\d{2}/\d{2})',
      extractionMap: const ExtractionMap(
        amount: 'amount',
        merchant: 'merchant',
        timestamp: 'timestamp',
      ),
      sampleMessage:
          '5,200.00 debited from SBI a/c for Online Shopping on 01/03/26',
      usageCount: 412,
      createdAt: DateTime(2025, 9, 5),
    ),
  ];
}
