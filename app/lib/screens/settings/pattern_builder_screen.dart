import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../models/category.dart';
import '../../models/message.dart';
import '../../providers/category_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/pattern_registry_provider.dart';
import '../../services/pattern_draft_builder.dart';
import '../../services/sms_parser_service.dart';
import '../../widgets/category_picker_sheet.dart';

/// Pattern Builder — highlight spans in a failed/ignored SMS and tag them with
/// standard fields to derive a template + extractionMap, with a live dry-run
/// preview before saving.
class PatternBuilderScreen extends ConsumerStatefulWidget {
  const PatternBuilderScreen({super.key, this.messageId});

  /// Id of the FAILED/IGNORED message this pattern is authored from, if any.
  final String? messageId;

  @override
  ConsumerState<PatternBuilderScreen> createState() =>
      _PatternBuilderScreenState();
}

/// A derived draft plus the client dry-run verdict.
class _DraftResult {
  final PatternDraft draft;
  final bool templateMatches;

  const _DraftResult({required this.draft, required this.templateMatches});
}

class _PatternBuilderScreenState extends ConsumerState<PatternBuilderScreen> {
  Message? _message;
  final List<TaggedSpan> _spans = [];
  final TextEditingController _templateController = TextEditingController();

  /// Editable text control for the source message so selections are
  /// deterministically settable (also by widget tests).
  final TextEditingController _sourceController = TextEditingController();
  final FocusNode _sourceFocus = FocusNode();

  bool _templateEdited = false;
  bool _saving = false;

  /// Category override applied to transactions this pattern parses.
  Category? _category;

  /// User-pinned literal values; empty means "use the tagged value".
  final TextEditingController _fixedMerchant = TextEditingController();
  final TextEditingController _fixedAccount = TextEditingController();
  final TextEditingController _fixedBank = TextEditingController();
  final TextEditingController _fixedNotes = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final msgId = widget.messageId;
      if (msgId == null) return;
      final all = [
        ...ref.read(messageProvider).failedMessages,
        ...ref.read(messageProvider).unprocessedMessages,
        ...ref.read(messageProvider).incompleteMessages,
        ...ref.read(messageProvider).nonFinancialMessages,
      ];
      for (final m in all) {
        if (m.id == msgId) {
          _sourceController.text = m.rawText;
          setState(() => _message = m);
          _sourceFocus.requestFocus();
          return;
        }
      }
    });
  }

  @override
  void dispose() {
    _templateController.dispose();
    _sourceController.dispose();
    _sourceFocus.dispose();
    _fixedMerchant.dispose();
    _fixedAccount.dispose();
    _fixedBank.dispose();
    _fixedNotes.dispose();
    super.dispose();
  }

  String _labelFor(PatternField field) {
    switch (field) {
      case PatternField.amount:
        return 'Amount';
      case PatternField.merchant:
        return 'Merchant';
      case PatternField.timestamp:
        return 'Date';
      case PatternField.transactionType:
        return 'Type';
      case PatternField.accountLast4:
        return 'Account';
      case PatternField.notes:
        return 'Notes';
    }
  }

  Color _fieldColor(PatternField field) {
    switch (field) {
      case PatternField.amount:
        return context.colors.accentMint;
      case PatternField.merchant:
        return context.colors.primaryLight;
      case PatternField.timestamp:
        return context.colors.accentCoral;
      case PatternField.transactionType:
        return const Color(0xFFFBBF24);
      case PatternField.accountLast4:
        return const Color(0xFF60A5FA);
      case PatternField.notes:
        return const Color(0xFFA78BFA);
    }
  }

  void _tagSelection(PatternField field) {
    final sel = _sourceController.selection;
    if (!sel.isNormalized || sel.start == sel.end) {
      _snack('Select some text to tag');
      return;
    }
    if (sel.end > _sourceController.text.length) {
      _snack('Select some text to tag');
      return;
    }
    if (PatternDraftBuilder.hasOverlap(_spans, sel.start, sel.end)) {
      _snack('That text is already tagged');
      return;
    }
    setState(() {
      _spans.add(TaggedSpan(field: field, start: sel.start, end: sel.end));
      _spans.sort((a, b) => a.start.compareTo(b.start));
      _syncTemplateController();
    });
  }

  void _removeSpan(TaggedSpan span) {
    setState(() {
      _spans.remove(span);
      _syncTemplateController();
    });
  }

  /// Keeps the editable template field in sync with the tagged spans until the
  /// user edits it by hand (then their text wins).
  void _syncTemplateController() {
    if (_templateEdited) return;
    final msg = _message;
    if (msg == null || _spans.isEmpty) {
      _templateController.text = '';
      return;
    }
    _templateController.text = PatternDraftBuilder.fromSpans(
      msg.rawText,
      _spans,
    ).template;
  }

  /// Derives the draft (tagged spans or manual template) + dry-run verdict.
  _DraftResult? _deriveDraft() {
    final msg = _message;
    if (msg == null) return null;

    if (_templateEdited) {
      final draft = PatternDraftBuilder.fromManualTemplate(
        _templateController.text,
      );
      return _DraftResult(draft: draft, templateMatches: false);
    }

    if (_spans.isEmpty) return null;
    final draft = PatternDraftBuilder.fromSpans(msg.rawText, _spans);
    final extracted = SmsParserService().dryRunTemplate(
      draft.template,
      msg.rawText,
    );
    return _DraftResult(
      draft: draft,
      templateMatches: extracted != null && extracted.isNotEmpty,
    );
  }

  /// Opens the family's category list and records the chosen override.
  ///
  /// Categories are loaded lazily on first open so the builder does not touch
  /// the family/category services unless the user actually picks a category.
  Future<void> _pickCategory() async {
    final familyGroupId = ref.read(familyProvider).currentFamily?.id;
    if (familyGroupId == null) {
      _snack('Join a family before choosing a category');
      return;
    }
    if (ref.read(categoryProvider).categories.isEmpty) {
      await ref.read(categoryProvider.notifier).loadCategories(familyGroupId);
    }
    if (!mounted) return;

    final categories = ref.read(categoryProvider).categories;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CategoryPickerSheet(
        categories: categories,
        selectedCategoryId: _category?.id,
        onSelected: (category) => setState(() => _category = category),
      ),
    );
  }

  /// Non-blank fixed values, keyed by transaction field. Fixed wins over the
  /// value extracted by the template.
  Map<String, String> _fixedValues() {
    final values = <String, String>{};
    void add(String field, TextEditingController controller) {
      final value = controller.text.trim();
      if (value.isNotEmpty) values[field] = value;
    }

    add('merchant', _fixedMerchant);
    add('accountLast4', _fixedAccount);
    add('bankName', _fixedBank);
    add('notes', _fixedNotes);
    return values;
  }

  Future<void> _save() async {
    final msg = _message;
    if (msg == null) return;
    final result = _deriveDraft();
    if (result == null) {
      _snack('Highlight and tag at least one field');
      return;
    }
    final draft = result.draft;
    if (!draft.hasAmountToken) {
      _snack('Tag the amount — it is required');
      return;
    }
    if (!draft.isManual && !result.templateMatches) {
      _snack('The template does not match the message');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(patternRegistryProvider.notifier)
          .createPattern(
            sender: msg.sender,
            template: draft.template,
            extractionMap: draft.extractionMap,
            fixedValues: _fixedValues(),
            sampleMessage: msg.rawText,
            categoryName: _category?.name,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pattern saved for ${msg.sender}',
            style: GoogleFonts.inter(),
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.inter())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final msg = _message;
    final result = _deriveDraft();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: context.colors.textMuted,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'New Pattern',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textMain,
                      ),
                    ),
                  ),
                  SizedBox(width: 48),
                ],
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child: msg == null
                  ? Center(
                      child: Text(
                        'Message not found',
                        style: GoogleFonts.inter(color: context.colors.textDim),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.all(20),
                      children: [
                        // ── Sender + source ──
                        Row(
                          children: [
                            Text(
                              msg.sender,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.colors.primaryLight,
                              ),
                            ),
                            SizedBox(width: 8),
                            _Tag(
                              label: msg.status == MessageStatus.failed
                                  ? 'Failed'
                                  : 'Ignored',
                              color: context.colors.accentCoral,
                            ),
                          ],
                        ),
                        SizedBox(height: 12),

                        // ── Selectable source text ──
                        Text(
                          'Select text to tag:',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textMuted,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.colors.background,
                            borderRadius: BorderRadius.circular(
                              BudgetlyTheme.radiusSmall,
                            ),
                            border: Border.all(
                              color: context.colors.surfaceHighlight.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          // Read-only field (rather than SelectableText) so the
                          // selection lives in a controller we can inspect when
                          // the user tags a span.
                          child: TextField(
                            key: const Key('pattern-source-text'),
                            controller: _sourceController,
                            focusNode: _sourceFocus,
                            readOnly: true,
                            showCursor: false,
                            maxLines: null,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              color: context.colors.textMain,
                              height: 1.6,
                            ),
                            decoration: const InputDecoration.collapsed(
                              hintText: '',
                            ),
                          ),
                        ),

                        // ── Tag buttons ──
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final field in PatternField.values)
                              ActionChip(
                                avatar: Icon(
                                  Icons.label_outline,
                                  size: 16,
                                  color: _fieldColor(field),
                                ),
                                label: Text(
                                  _labelFor(field),
                                  style: GoogleFonts.inter(fontSize: 12),
                                ),
                                onPressed: () => _tagSelection(field),
                              ),
                          ],
                        ),

                        // ── Tagged spans ──
                        if (_spans.isNotEmpty) ...[
                          SizedBox(height: 16),
                          Text(
                            'Tagged',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textMuted,
                            ),
                          ),
                          SizedBox(height: 6),
                          for (final span in _spans)
                            Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _fieldColor(span.field),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '"${msg.rawText.substring(span.start, span.end)}" → ${_labelFor(span.field)}',
                                      style: GoogleFonts.inter(fontSize: 12),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _removeSpan(span),
                                    icon: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: context.colors.textDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],

                        // ── Template preview / manual edit ──
                        SizedBox(height: 16),
                        Text(
                          'Template',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textMuted,
                          ),
                        ),
                        SizedBox(height: 6),
                        TextField(
                          key: const Key('pattern-template-field'),
                          controller: _templateController,
                          onChanged: (_) =>
                              setState(() => _templateEdited = true),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: context.colors.textMain,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Tag fields or type a template with {amount}',
                            hintStyle: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              color: context.colors.textDim,
                            ),
                            filled: true,
                            fillColor: context.colors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                BudgetlyTheme.radiusSmall,
                              ),
                              borderSide: BorderSide(
                                color: context.colors.borderSubtle,
                              ),
                            ),
                          ),
                          maxLines: 2,
                        ),

                        // ── Dry-run feedback ──
                        if (result != null) ...[
                          SizedBox(height: 10),
                          _DryRunBanner(
                            hasAmount: result.draft.hasAmountToken,
                            templateMatches: result.templateMatches,
                            templateEdited: _templateEdited,
                          ),
                        ],

                        // ── Category override ──
                        SizedBox(height: 20),
                        Text(
                          'Category (optional)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textMuted,
                          ),
                        ),
                        SizedBox(height: 6),
                        InkWell(
                          key: const Key('pattern-category-row'),
                          onTap: _pickCategory,
                          borderRadius: BorderRadius.circular(
                            BudgetlyTheme.radiusSmall,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.background,
                              borderRadius: BorderRadius.circular(
                                BudgetlyTheme.radiusSmall,
                              ),
                              border: Border.all(
                                color: context.colors.borderSubtle,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.label_outline,
                                  size: 18,
                                  color: context.colors.textDim,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _category?.name ?? 'Uncategorized',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: _category == null
                                          ? context.colors.textDim
                                          : context.colors.textMain,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: context.colors.textDim,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Fixed values ──
                        SizedBox(height: 20),
                        Text(
                          'Fixed values (optional)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textMuted,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Leave a field empty to use the tagged value, or type '
                          'a literal to always use it for this template.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: context.colors.textDim,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 8),
                        _FixedValueField(
                          fieldKey: const Key('pattern-fixed-merchant'),
                          controller: _fixedMerchant,
                          label: 'Merchant',
                          hint: 'e.g. Pan Shop',
                        ),
                        SizedBox(height: 8),
                        _FixedValueField(
                          fieldKey: const Key('pattern-fixed-account'),
                          controller: _fixedAccount,
                          label: 'Account',
                          hint: 'e.g. 1234',
                        ),
                        SizedBox(height: 8),
                        _FixedValueField(
                          fieldKey: const Key('pattern-fixed-bank'),
                          controller: _fixedBank,
                          label: 'Bank name',
                          hint: 'e.g. HDFC Bank',
                        ),
                        SizedBox(height: 8),
                        _FixedValueField(
                          fieldKey: const Key('pattern-fixed-notes'),
                          controller: _fixedNotes,
                          label: 'Notes',
                          hint: 'e.g. Monthly groceries',
                        ),

                        SizedBox(height: 24),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            key: const Key('pattern-save-button'),
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.colors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  BudgetlyTheme.radiusMedium,
                                ),
                              ),
                            ),
                            child: _saving
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Save pattern',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: 100),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Labelled literal-value input for one transaction field.
class _FixedValueField extends StatelessWidget {
  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String hint;

  const _FixedValueField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      style: GoogleFonts.inter(fontSize: 13, color: context.colors.textMain),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          color: context.colors.textMuted,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 12,
          color: context.colors.textDim,
        ),
        filled: true,
        fillColor: context.colors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BudgetlyTheme.radiusSmall),
          borderSide: BorderSide(color: context.colors.borderSubtle),
        ),
      ),
    );
  }
}

class _DryRunBanner extends StatelessWidget {
  final bool hasAmount;
  final bool templateMatches;
  final bool templateEdited;

  const _DryRunBanner({
    required this.hasAmount,
    required this.templateMatches,
    required this.templateEdited,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (!hasAmount) {
      color = context.colors.accentCoral;
      label = 'Missing required {amount} tag';
    } else if (templateMatches) {
      color = context.colors.accentMint;
      label = 'Preview OK — pattern will parse this message';
    } else if (templateEdited) {
      color = const Color(0xFFFBBF24);
      label = 'Manual template — server will validate on save';
    } else {
      color = context.colors.accentCoral;
      label = 'Template does not match the message';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            color == context.colors.accentMint
                ? Icons.check_circle
                : Icons.warning_amber,
            size: 16,
            color: color,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
