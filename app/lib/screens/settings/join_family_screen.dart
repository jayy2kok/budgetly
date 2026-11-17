import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/family_provider.dart';

/// Join Family — enter an invite code or scan a QR to join a family group.
class JoinFamilyScreen extends ConsumerStatefulWidget {
  /// Optional invite code pre-filled from a deep link.
  final String? deepLinkCode;

  const JoinFamilyScreen({super.key, this.deepLinkCode});

  @override
  ConsumerState<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends ConsumerState<JoinFamilyScreen> {
  final _codeController = TextEditingController();
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController.text = widget.deepLinkCode ?? '';
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter an invite code.');
      return;
    }
    setState(() {
      _joining = true;
      _error = null;
    });
    final success =
        await ref.read(familyProvider.notifier).joinViaInvite(code);
    if (!mounted) return;
    if (success) {
      if (context.mounted) context.go(AppRoutes.dashboard);
    } else {
      setState(() {
        _joining = false;
        _error = ref.read(familyProvider).error ??
            'Could not join family. Check the code and try again.';
      });
    }
  }

  /// Opens the device camera to scan a QR code.
  Future<void> _scanQr(BuildContext context) async {
    try {
      await _launchCameraScanner(context);
    } catch (e) {
      if (!mounted) return;
      setState(() =>
          _error = 'QR scanner not available. Enter code manually.');
    }
  }

  /// Launch a camera-based QR scanner that extracts the invite code.
  Future<void> _launchCameraScanner(BuildContext context) async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (ctx) => _QrScannerPage(
          onCodeDetected: (code) {
            if (context.mounted) {
              Navigator.of(context).pop(code);
            }
          },
        ),
      ),
    ).then((code) {
      if (code != null && context.mounted) {
        final parsed = _extractInviteCode(code);
        _codeController.text = parsed;
        setState(() => _error = null);
        // Auto-join after scanning
        _join();
      }
    });
  }

  /// Extract an invite code from various formats:
  /// - Plain code: "FAM-ABC123"
  /// - URL: "https://budgetly.app/join?code=FAM-ABC123"
  /// - URL with path: "https://budgetly.app/join/FAM-ABC123"
  /// - Deep link: "budgetly://join?code=FAM-ABC123"
  String _extractInviteCode(String raw) {
    try {
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.queryParameters['code'] != null) {
        return uri.queryParameters['code']!;
      }
    } catch (_) {}

    try {
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last;
        if (last.isNotEmpty && !last.startsWith('/')) return last;
      }
    } catch (_) {}

    return raw.trim();
  }

  @override
  Widget build(BuildContext context) {
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
                      'Join Family',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textMain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
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
                      'Join your family group',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textMain,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Enter the invite code or scan a QR\ncode shared by your family admin',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: context.colors.textDim,
                        height: 1.5,
                      ),
                    ),

                    SizedBox(height: 32),

                    // Error banner
                    if (_error != null) _buildErrorBanner(context),

                    // Invite code input
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.cardSurface,
                        borderRadius: BorderRadius.circular(
                          BudgetlyTheme.radiusCard,
                        ),
                        border:
                            Border.all(color: context.colors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INVITE CODE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textDim,
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(height: 12),
                          TextField(
                            controller: _codeController,
                            autofocus: _codeController.text.isEmpty,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textMain,
                              letterSpacing: 2,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. FAM-ABC123',
                              hintStyle: GoogleFonts.jetBrainsMono(
                                fontSize: 16,
                                color: context.colors.textDim,
                                letterSpacing: 2,
                              ),
                              filled: true,
                              fillColor: context.colors.surfaceHighlight,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  BudgetlyTheme.radiusMedium,
                                ),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _join(),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Join button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _joining ? null : _join,
                        icon: _joining
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(Icons.group_add, size: 20),
                        label: Text(
                          _joining ? 'Joining…' : 'Join Family',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.primary,
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

                    SizedBox(height: 24),

                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child:
                              Divider(color: context.colors.borderSubtle),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textDim,
                            ),
                          ),
                        ),
                        Expanded(
                          child:
                              Divider(color: context.colors.borderSubtle),
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // QR Scan button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _joining ? null : () => _scanQr(context),
                        icon: Icon(Icons.qr_code_scanner, size: 20),
                        label: Text(
                          'Scan QR Code',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.colors.primary,
                          side: BorderSide(color: context.colors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              BudgetlyTheme.radiusMedium,
                            ),
                          ),
                        ),
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

  Widget _buildErrorBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
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
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: Icon(
              Icons.close,
              size: 18,
              color: context.colors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen QR code scanner page using mobile_scanner.
class _QrScannerPage extends StatefulWidget {
  final Function(String) onCodeDetected;

  const _QrScannerPage({required this.onCodeDetected});

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    torchEnabled: false,
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.normal,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            _controller.stop();
            Navigator.of(context).pop();
          },
          icon: Icon(Icons.close),
        ),
        title: Text(
          'Scan QR Code',
          style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: () => _controller.toggleTorch(),
            icon: Icon(Icons.flash_on),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera feed from mobile_scanner
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null && code.isNotEmpty) {
                  _controller.stop();
                  if (context.mounted) {
                    widget.onCodeDetected(code);
                    Navigator.of(context).pop(code);
                  }
                  return;
                }
              }
            },
          ),

          // Overlay — scan frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: context.colors.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.qr_code_scanner,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Instruction overlay at bottom
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Point camera at the QR code',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: EdgeInsets.all(24),
        color: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flash_on, size: 18, color: Colors.white70),
                SizedBox(width: 8),
                Text(
                  'Ensure good lighting for best results',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                await _controller.stop();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: Icon(Icons.close),
              label: Text('Cancel'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
