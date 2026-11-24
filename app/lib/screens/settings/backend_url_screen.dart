import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/backend_base_url_provider.dart';

/// Developer screen — configure the backend base URL the app talks to.
///
/// Persists the override via [backendBaseUrlProvider], which applies it to the
/// shared Dio client immediately. Because auth tokens are tied to one backend,
/// saving a different URL signs the user out and returns to the login screen.
class BackendUrlScreen extends ConsumerStatefulWidget {
  const BackendUrlScreen({super.key});

  @override
  ConsumerState<BackendUrlScreen> createState() => _BackendUrlScreenState();
}

class _BackendUrlScreenState extends ConsumerState<BackendUrlScreen> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(backendBaseUrlProvider).baseUrl,
    );
    // Fill in a persisted override once it loads. Applied once here rather
    // than in build(), so a rebuild (e.g. showing a validation error) never
    // overwrites what the user is typing.
    ref.read(backendBaseUrlProvider.notifier).load().then((_) {
      if (!mounted) return;
      final loaded = ref.read(backendBaseUrlProvider).baseUrl;
      if (_controller.text != loaded) _controller.text = loaded;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final trimmed = _controller.text.trim();

    // Empty input resets to the build-time default.
    final normalized = trimmed.isEmpty ? null : normalizeBackendBaseUrl(trimmed);
    if (trimmed.isNotEmpty && normalized == null) {
      setState(() {
        _errorText = 'Enter a valid URL, e.g. http://192.168.1.10:8080/api/v1';
      });
      // Move focus off the field so the TextField rebuilds cleanly; without
      // this the error can be dropped when the field is still focused.
      FocusScope.of(context).unfocus();
      return;
    }

    FocusScope.of(context).unfocus();
    final previous = ref.read(backendBaseUrlProvider).baseUrl;

    // Apply and persist. The notifier updates its state synchronously before
    // the SharedPreferences write completes, so the UI reflects the new value
    // immediately even if persistence is still in flight.
    final notifier = ref.read(backendBaseUrlProvider.notifier);
    notifier.applyBaseUrl(normalized ?? '');
    await notifier.persistBaseUrl(normalized ?? '');

    if (!mounted) return;
    final message = normalized == null
        ? 'Backend URL reset to default.'
        : 'Backend URL saved. Restart the app to apply it everywhere.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );

    // A token issued by the old backend is invalid on the new one.
    if (normalized != null && normalized != previous) {
      ref.read(authProvider.notifier).signOut();
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(backendBaseUrlProvider);

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
                      'Backend URL',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 28),

                    Text(
                      'The app talks to this Budgetly server. Point it at a '
                      'local, LAN, or hosted backend — e.g. '
                      'http://10.0.2.2:8080/api/v1 for the Android emulator.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5,
                        color: context.colors.textMuted,
                      ),
                    ),
                    SizedBox(height: 20),

                    // ── Current ──
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.cardSurface,
                        borderRadius: BorderRadius.circular(
                          BudgetlyTheme.radiusCard,
                        ),
                        border: Border.all(
                          color: context.colors.borderSubtle,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'CURRENT',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.textDim,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const Spacer(),
                              if (current.isCustom)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.accentMint
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Custom',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: context.colors.accentMint,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            current.baseUrl,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: context.colors.textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Input ──
                    Text(
                      'BACKEND URL',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textDim,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('backend-url-input'),
                      controller: _controller,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: context.colors.textMain,
                      ),
                      decoration: InputDecoration(
                        hintText: 'http://192.168.1.10:8080/api/v1',
                        errorText: _errorText,
                        filled: true,
                        fillColor: context.colors.cardSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            BudgetlyTheme.radiusSmall,
                          ),
                          borderSide: BorderSide(
                            color: context.colors.borderSubtle,
                          ),
                        ),
                      ),
                      onChanged: (_) {
                        if (_errorText != null) {
                          setState(() => _errorText = null);
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Save ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: context.colors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              BudgetlyTheme.radiusMedium,
                            ),
                          ),
                        ),
                        child: Text(
                          'Save',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}