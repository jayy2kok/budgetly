import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../data/remote/api_client.dart';

/// User-configurable backend base URL, persisted locally with
/// SharedPreferences.
///
/// The build-time [ApiConfig.defaultBaseUrl] (or the `--dart-define`
/// `API_BASE_URL`) stays the default; the value stored under
/// [BackendBaseUrlNotifier.storageKey] overrides it and is applied to the
/// shared [ApiClient] (Dio `baseUrl`) as soon as it loads at startup, so every
/// remote service and the token-refresh client use it without a restart.
class BackendBaseUrlState {
  /// Effective base URL in use (persisted override or build-time default).
  final String baseUrl;

  /// Whether [baseUrl] is the user's override rather than the default.
  final bool isCustom;

  const BackendBaseUrlState({required this.baseUrl, required this.isCustom});
}

class BackendBaseUrlNotifier extends Notifier<BackendBaseUrlState> {
  /// SharedPreferences key for the persisted override.
  static const String storageKey = 'backend_base_url';

  @override
  BackendBaseUrlState build() {
    _load();
    return const BackendBaseUrlState(
      baseUrl: ApiConfig.defaultBaseUrl,
      isCustom: false,
    );
  }

  /// Loads the persisted override from SharedPreferences and applies it.
  ///
  /// Called from [build] and awaited by the settings screen so the UI can
  /// rebuild once a stored value is available.
  Future<void> load() => _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(storageKey);
    final effective = (stored != null && stored.isNotEmpty)
        ? stored
        : ApiConfig.defaultBaseUrl;
    ApiClient.instance.setBaseUrl(effective);
    state = BackendBaseUrlState(
      baseUrl: effective,
      isCustom: stored != null && stored.isNotEmpty,
    );
  }

  /// Applies [baseUrl] to the live Dio client and updates state synchronously.
  ///
  /// Call [persistBaseUrl] afterwards to write the override to disk.
  void applyBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    final effective = trimmed.isEmpty ? ApiConfig.defaultBaseUrl : trimmed;
    ApiClient.instance.setBaseUrl(effective);
    state = BackendBaseUrlState(
      baseUrl: effective,
      isCustom: trimmed.isNotEmpty,
    );
  }

  /// Persists the current [state] override to SharedPreferences (or removes it
  /// when it is the default).
  Future<void> persistBaseUrl(String baseUrl) async {
    final trimmed = baseUrl.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(storageKey);
    } else {
      await prefs.setString(storageKey, trimmed);
    }
  }

  /// Persists [baseUrl] (trimmed) as the override and applies it to the API
  /// client. An empty value resets to the build-time default.
  Future<void> setBaseUrl(String baseUrl) async {
    applyBaseUrl(baseUrl);
    await persistBaseUrl(baseUrl);
  }
}

final backendBaseUrlProvider =
    NotifierProvider<BackendBaseUrlNotifier, BackendBaseUrlState>(
      BackendBaseUrlNotifier.new,
    );

/// Normalizes a user-entered base URL for storage and requests.
///
/// Trims surrounding whitespace, drops a trailing slash, and prepends
/// `http://` when no scheme is given. Returns `null` when [input] is blank or
/// is not a valid absolute http(s) URL (which also rejects embedded spaces).
String? normalizeBackendBaseUrl(String input) {
  var value = input.trim();
  if (value.isEmpty) return null;
  if (!value.contains('://')) {
    value = 'http://$value';
  }
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  // Reject anything that isn't a clean absolute URL (e.g. embedded spaces).
  if (uri.toString() != value) return null;
  // Drop a trailing slash so Dio joins paths cleanly.
  return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}