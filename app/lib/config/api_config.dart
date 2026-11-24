/// API configuration for the Budgetly app.
class ApiConfig {
  ApiConfig._();

  /// Build-time default base URL for the Budgetly REST API.
  ///
  /// For local development, the Spring Boot server runs on port 8080.
  /// For Android emulators, use `10.0.2.2` instead of `localhost`.
  /// For Android Emulator:      http://10.0.2.2:8080/api/v1
  /// For iOS Simulator:         http://127.0.0.1:8080/api/v1
  /// For real physical device:  `http://LAN_IP:8080/api/v1`
  ///
  /// Override at build/run time with
  ///   `--dart-define=API_BASE_URL=http://<host>:8080/api/v1`
  ///
  /// This is only the default: the user can override it at runtime from
  /// Settings → Developer → Backend URL (persisted in SharedPreferences and
  /// applied by [ApiClient]); see `backend_base_url_provider.dart`.
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.31.50:8080/api/v1',
  );

  /// Request timeout in milliseconds.
  static const int connectTimeout = 10000;

  /// Response timeout in milliseconds.
  static const int receiveTimeout = 60000;

  /// Max number of financial SMS messages to pull per sync.
  ///
  /// Capped low during manual testing so the full pipeline (read → bulk →
  /// change-stream → LLM → transaction) can be exercised quickly without
  /// waiting on the whole inbox. Raise or remove this once testing is done.
  ///
  /// Override at build/run time with
  ///   `--dart-define=SMS_SYNC_MAX_MESSAGES=<n>`
  static const int smsSyncMaxMessages = int.fromEnvironment(
    'SMS_SYNC_MAX_MESSAGES',
    defaultValue: 10,
  );

  /// Max number of device SMS the inbox screen displays (newest first).
  ///
  /// The inbox mirrors the phone's SMS app, so this is a display window over
  /// the device inbox rather than a sync batch size.
  ///
  /// Override at build/run time with
  ///   `--dart-define=SMS_INBOX_DISPLAY_LIMIT=<n>`
  static const int smsInboxDisplayLimit = int.fromEnvironment(
    'SMS_INBOX_DISPLAY_LIMIT',
    defaultValue: 300,
  );
}
