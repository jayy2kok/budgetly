import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/theme.dart';
import '../../models/family_invite.dart';
import '../../models/family_member.dart';
import '../../providers/family_provider.dart';
import '../../providers/service_providers.dart';

/// Invite / Link Family — Share a real backend-generated invite link and QR.
class LinkFamilyScreen extends ConsumerStatefulWidget {
  const LinkFamilyScreen({super.key});

  @override
  ConsumerState<LinkFamilyScreen> createState() => _LinkFamilyScreenState();
}

class _LinkFamilyScreenState extends ConsumerState<LinkFamilyScreen> {
  MemberRole _selectedRole = MemberRole.member;
  bool _copied = false;

  FamilyInvite? _invite;
  bool _loading = false;
  String? _error;
  String? _lastAttemptedFamilyId;

  @override
  void initState() {
    super.initState();
    _generateInvite();
  }

  /// Generate a fresh invite from the backend for the current family.
  Future<void> _generateInvite({String? familyId}) async {
    final fid = familyId ?? ref.read(familyProvider).currentFamily?.id;
    if (fid == null) {
      setState(() {
        _loading = false;
        _error = 'No family group available yet. Please sign in and try again.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _lastAttemptedFamilyId = fid;
    try {
      final invite = await ref
          .read(familyServiceProvider)
          .inviteFamily(fid, {'method': 'LINK'});
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _loading = false;
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        final serverMessage = data['message'] as String;
        if (serverMessage.isNotEmpty) return serverMessage;
      }
      if (error.response?.statusCode == 403) {
        return 'Only admins can invite members.';
      }
      if (error.response?.statusCode == 401) {
        return 'Your session has expired. Please sign in again.';
      }
    }
    return 'Could not generate an invite link. Please try again.';
  }

  void _copyLink(String link) {
    Clipboard.setData(ClipboardData(text: link));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  /// Converts a backend-generated https://budgetly.app/join?code=X link to the
  /// budgetly:// scheme, which Android launches reliably without assetlinks.json.
  String _toBudgetlyScheme(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return link;
    if (uri.scheme == 'https' && uri.host == 'budgetly.app') {
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) return 'budgetly://join?code=$code';
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) return 'budgetly://join?code=${segments.first}';
      return 'budgetly://join';
    }
    return link;
  }

  String _formatExpiry(DateTime expiresAt) {
    final local = expiresAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    // If the current family loads after this screen first opened without one,
    // generate the invite automatically.
    ref.listen(familyProvider, (prev, next) {
      final nextId = next.currentFamily?.id;
      if (nextId == null) return;
      if (nextId != _lastAttemptedFamilyId && !_loading) {
        _generateInvite(familyId: nextId);
      }
    });

    final bool showLoading = _loading && _invite == null;
    final bool showErrorOnly = _error != null && _invite == null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
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
                      'Invite Members',
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

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 32),

                    // Illustration
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.group_add,
                        size: 36,
                        color: context.colors.primaryLight,
                      ),
                    ),

                    SizedBox(height: 20),

                    Text(
                      'Invite your family',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textMain,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Share this link with family members\nto join your budget group',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: context.colors.textDim,
                        height: 1.5,
                      ),
                    ),

                    SizedBox(height: 32),

                    if (showLoading)
                      _buildLoadingCard()
                    else if (showErrorOnly)
                      _buildErrorCard(context)
                    else if (_invite != null) ...[
                      if (_error != null) _buildInlineErrorBanner(context),
                      _buildLinkCard(context),
                      SizedBox(height: 24),
                      _buildQrCard(context),
                    ] else
                      _buildErrorCard(context),

                    SizedBox(height: 24),

                    // ── Default Role Selector ──
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.cardSurface,
                        borderRadius: BorderRadius.circular(
                          BudgetlyTheme.radiusCard,
                        ),
                        border: Border.all(color: context.colors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DEFAULT ROLE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textDim,
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(height: 12),
                          _RoleOption(
                            role: MemberRole.member,
                            label: 'Member',
                            description: 'Can add expenses and view everything',
                            selected: _selectedRole == MemberRole.member,
                            onTap: () => setState(
                              () => _selectedRole = MemberRole.member,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Invite states ─────────────────────────────────────────────

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: context.colors.primary,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Generating invite link…',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: context.colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineErrorBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.accentCoral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusMedium),
        border: Border.all(
          color: context.colors.accentCoral.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: context.colors.accentCoral,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              _error ?? 'Something went wrong.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: context.colors.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(
            Icons.link_off,
            size: 36,
            color: context.colors.accentCoral,
          ),
          SizedBox(height: 12),
          Text(
            _error ?? 'No invite available.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: context.colors.textMuted,
              height: 1.4,
            ),
          ),
          SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _generateInvite,
            icon: Icon(Icons.refresh, size: 18),
            label: Text(
              'Try Again',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.primary,
              side: BorderSide(color: context.colors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BudgetlyTheme.radiusMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Invite content (invite exists) ────────────────────────────

  Widget _buildLinkCard(BuildContext context) {
    final invite = _invite!;
    final link = _toBudgetlyScheme(invite.inviteLink ?? '');
    final copyingEnabled = link.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'INVITE LINK',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textDim,
                  letterSpacing: 1.5,
                ),
              ),
              Spacer(),
              // Regenerate — asks the backend for a fresh code.
              InkWell(
                onTap: _loading ? null : _generateInvite,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      if (_loading)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.primary,
                          ),
                        )
                      else
                        Icon(
                          Icons.refresh,
                          size: 14,
                          color: context.colors.textMuted,
                        ),
                      SizedBox(width: 4),
                      Text(
                        'Regenerate',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.colors.background,
              borderRadius: BorderRadius.circular(BudgetlyTheme.radiusMedium),
            ),
            child: Text(
              link.isEmpty ? 'No invite link returned' : link,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: context.colors.primaryLight,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: copyingEnabled ? () => _copyLink(link) : null,
              icon: Icon(
                _copied ? Icons.check : Icons.copy,
                size: 18,
              ),
              label: Text(
                _copied ? 'Copied!' : 'Copy Link',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _copied
                    ? context.colors.accentMint
                    : context.colors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    BudgetlyTheme.radiusMedium,
                  ),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard(BuildContext context) {
    final link = _toBudgetlyScheme(_invite?.inviteLink ?? '');
    final hasLink = link != null && link.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(BudgetlyTheme.radiusCard),
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                BudgetlyTheme.radiusMedium,
              ),
            ),
            child: hasLink
                ? QrImageView(
                    data: link,
                    size: 140,
                    padding: EdgeInsets.all(8),
                    backgroundColor: Colors.white,
                  )
                : Center(
                    child: Icon(
                      Icons.qr_code_2,
                      size: 100,
                      color: context.colors.background,
                    ),
                  ),
          ),
          SizedBox(height: 12),
          Text(
            'Scan to join',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: context.colors.textDim,
            ),
          ),
          if (_invite?.expiresAt != null) ...[
            SizedBox(height: 4),
            Text(
              'Expires ${_formatExpiry(_invite!.expiresAt!)}',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: context.colors.textDim,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final MemberRole role;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.role,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.primary.withValues(alpha: 0.08)
              : context.colors.background,
          borderRadius: BorderRadius.circular(BudgetlyTheme.radiusMedium),
          border: Border.all(
            color: selected
                ? context.colors.primary.withValues(alpha: 0.3)
                : context.colors.surfaceHighlight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? context.colors.primary
                      : context.colors.textDim,
                  width: 2,
                ),
                color: selected ? context.colors.primary : Colors.transparent,
              ),
              child: selected
                  ? Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textMain,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.colors.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}