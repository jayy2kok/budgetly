/// API configuration for the Budgetly app.
class ApiConfig {
  ApiConfig._();

  /// Base URL for the Budgetly REST API.
  ///
  /// For local development, the Spring Boot server runs on port 8080.
  /// For Android emulators, use `10.0.2.2` instead of `localhost`.
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  /// Request timeout in milliseconds.
  static const int connectTimeout = 10000;

  /// Response timeout in milliseconds.
  static const int receiveTimeout = 15000;
}
