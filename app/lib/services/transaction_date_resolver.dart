/// Resolves the transaction date from an SMS.
///
/// The date written in the body is authoritative; the SMS's received time
/// completes a date-only value (midnight when the received time is
/// unavailable). Mirrors the backend's `TransactionDateParser` so a message
/// parsed on-device and one parsed by the change-stream listener produce the
/// same transaction date.
///
/// Supported timestamps: ISO instants/offsets, ISO dates, `dd/MM/yyyy`,
/// `dd-MM-yyyy`, and the two-digit-year bank form `dd/MM/yy` / `dd-MM-yy`
/// (`26` → 2026), each optionally with `HH:mm[:ss]`.
class TransactionDateResolver {
  const TransactionDateResolver();

  /// Returns the transaction instant.
  ///
  /// 1. Body has a date **and** a time → that instant wins.
  /// 2. Body has a **date only** → that date at the received time-of-day
  ///    (or `00:00:00` when [receivedAt] is unavailable).
  /// 3. Body is missing/unparseable → [receivedAt].
  DateTime resolve(DateTime? receivedAt, String? rawTimestamp) {
    final value = rawTimestamp?.trim();
    if (value == null || value.isEmpty) {
      return receivedAt ?? DateTime.now();
    }

    final dateTime = _parseDateTime(value);
    if (dateTime != null) return dateTime;

    final dateOnly = _parseDateOnly(value);
    if (dateOnly != null) {
      // A date-only body keeps its date and takes the received time-of-day;
      // without a received time the time is midnight.
      return DateTime(
        dateOnly.year,
        dateOnly.month,
        dateOnly.day,
        receivedAt?.hour ?? 0,
        receivedAt?.minute ?? 0,
        receivedAt?.second ?? 0,
        receivedAt?.millisecond ?? 0,
        receivedAt?.microsecond ?? 0,
      );
    }
    return receivedAt ?? DateTime.now();
  }

  static final RegExp _isoDateTime = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?'
    r'(Z|[+-]\d{2}:?\d{2})?$',
  );
  static final RegExp _slashDateTime = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{4}|\d{2})[ ,]+(\d{1,2}):(\d{2})(?::(\d{2}))?$',
  );
  static final RegExp _dashDateTime = RegExp(
    r'^(\d{1,2})-(\d{1,2})-(\d{4}|\d{2})[ ,]+(\d{1,2}):(\d{2})(?::(\d{2}))?$',
  );
  static final RegExp _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static final RegExp _slashDate =
      RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4}|\d{2})$');
  static final RegExp _dashDate =
      RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4}|\d{2})$');

  static DateTime? _parseDateTime(String value) {
    final iso = _isoDateTime.firstMatch(value);
    if (iso != null) {
      // DateTime.parse handles the optional offset and normalises it.
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return _fromDayMonthYearTime(
      _slashDateTime.firstMatch(value) ?? _dashDateTime.firstMatch(value),
    );
  }

  static DateTime? _fromDayMonthYearTime(RegExpMatch? match) {
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = _fullYear(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = match.group(6) != null ? int.parse(match.group(6)!) : 0;
    if (!_isValid(day: day, month: month, hour: hour, minute: minute, second: second)) {
      return null;
    }
    return DateTime(year, month, day, hour, minute, second);
  }

  static DateTime? _parseDateOnly(String value) {
    final iso = _isoDate.firstMatch(value);
    if (iso != null) {
      final year = int.parse(iso.group(1)!);
      final month = int.parse(iso.group(2)!);
      final day = int.parse(iso.group(3)!);
      if (!_isValid(day: day, month: month)) return null;
      return DateTime(year, month, day);
    }
    final match = _slashDate.firstMatch(value) ?? _dashDate.firstMatch(value);
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = _fullYear(match.group(3)!);
    if (!_isValid(day: day, month: month)) return null;
    return DateTime(year, month, day);
  }

  /// Expands a bank-style two-digit year (`26` → `2026`).
  static int _fullYear(String raw) =>
      raw.length == 2 ? 2000 + int.parse(raw) : int.parse(raw);

  static bool _isValid({
    required int day,
    required int month,
    int hour = 0,
    int minute = 0,
    int second = 0,
  }) {
    // DateTime silently rolls invalid values over (31/13 → next year), so
    // validate against a real calendar date first.
    if (month < 1 || month > 12 || day < 1 || day > 31) return false;
    if (hour > 23 || minute > 59 || second > 59) return false;
    final probe = DateTime(2000, month, day); // 2000 is a leap year
    return probe.month == month && probe.day == day;
  }
}