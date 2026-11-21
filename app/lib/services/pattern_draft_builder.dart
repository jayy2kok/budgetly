import '../models/sms_pattern.dart';

/// A standard field the user can tag in the pattern builder.
///
/// [name] doubles as the anchor-template token: `{amount}`, `{merchant}`,
/// `{timestamp}`, `{transactionType}`, `{accountLast4}`, `{notes}`.
enum PatternField {
  amount,
  merchant,
  timestamp,
  transactionType,
  accountLast4,
  notes;

  /// The `{token}` written into the template for this field.
  String get token => '{$name}';

  /// Whether this field is required for an auto-postable pattern.
  bool get isRequired => this == PatternField.amount;
}

/// A span of the source SMS tagged with a [PatternField].
class TaggedSpan {
  final PatternField field;
  final int start;
  final int end;

  const TaggedSpan({required this.field, required this.start, required this.end});

  /// Whether this span overlaps the range [start, end).
  bool overlaps(int start, int end) => this.start < end && start < this.end;
}

/// The template + extractionMap derived from tagged spans (or a manual edit).
class PatternDraft {
  /// Anchored template with `{tokens}` at the tagged spans.
  final String template;

  /// Maps each token name to itself (the anchor parser keys values by token).
  final ExtractionMap extractionMap;

  /// Whether the template contains a `{amount}` token.
  final bool hasAmountToken;

  /// Whether the draft was authored by hand rather than from tagged spans.
  final bool isManual;

  const PatternDraft({
    required this.template,
    required this.extractionMap,
    required this.hasAmountToken,
    this.isManual = false,
  });
}

/// Derives builder templates and extraction maps from tagged SMS spans.
///
/// Pure computation shared by the builder screen and its tests: the client
/// dry-run (via [SmsParserService.dryRunTemplate]) and the server both reuse
/// the identical literal-anchor contract.
class PatternDraftBuilder {
  const PatternDraftBuilder._();

  /// Whether [spans] contain a tag overlapping the range [start, end).
  static bool hasOverlap(List<TaggedSpan> spans, int start, int end) {
    return spans.any((s) => s.overlaps(start, end));
  }

  /// Builds a draft from [rawText] and the [spans] tagged against it.
  ///
  /// Spans must be non-overlapping; callers reject overlaps via [hasOverlap]
  /// before adding. If there are no spans the template is just [rawText].
  static PatternDraft fromSpans(String rawText, List<TaggedSpan> spans) {
    final sorted = [...spans]..sort((a, b) => a.start.compareTo(b.start));
    final template = StringBuffer();
    final types = <String, String>{};
    int cursor = 0;

    for (final span in sorted) {
      template.write(rawText.substring(cursor, span.start));
      template.write(span.field.token);
      types[span.field.name] = span.field.name;
      cursor = span.end;
    }
    template.write(rawText.substring(cursor));

    final templateStr = template.toString();
    return PatternDraft(
      template: templateStr,
      extractionMap: _extractionMapFor(types),
      hasAmountToken: types.containsKey(PatternField.amount.name),
    );
  }

  /// Builds a draft from a hand-edited [template].
  static PatternDraft fromManualTemplate(String template) {
    final names = RegExp(r'\{([^}]+)\}')
        .allMatches(template)
        .map((m) => m.group(1)!)
        .toSet();
    return PatternDraft(
      template: template,
      extractionMap: _extractionMapFor({for (final n in names) n: n}),
      hasAmountToken: names.contains(PatternField.amount.name),
      isManual: true,
    );
  }

  static ExtractionMap _extractionMapFor(Map<String, String> types) {
    String? group(String name) => types.containsKey(name) ? name : null;
    return ExtractionMap(
      amount: PatternField.amount.name,
      merchant: group(PatternField.merchant.name),
      timestamp: group(PatternField.timestamp.name),
      accountLast4: group(PatternField.accountLast4.name),
      type: group(PatternField.transactionType.name),
    );
  }
}