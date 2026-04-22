// App configuration loaded from the .env file.
// All API URLs and environment-specific settings live here.
// Never hardcode URLs in widget files.
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Private constructor — use AppConfig.apiBaseUrl, not AppConfig()
  AppConfig._();

  /// Base URL for the Go backend API.
  /// In development: http://10.0.2.2:8080/api/v1 (Android emulator → localhost)
  /// In production: https://api.yourdomain.com/api/v1
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8080/api/v1';

  /// How long to wait for an API response before giving up.
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}