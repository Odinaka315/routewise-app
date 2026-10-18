/// Application-wide configuration.
/// 
/// Centralizes all backend URLs, link domains, package identifiers,
/// and scheme configurations for single-line updates.
class AppConfig {
  AppConfig._();

  /// Backend domain (host only, without https:// or trailing slash).
  /// Change this single constant when migrating to a custom domain.
  static const String linkDomain = 'routewise-backend-6bmk.onrender.com';

  /// Base API URL for all REST requests.
  static const String apiBaseUrl = 'https://$linkDomain';

  /// Custom URL scheme for local dev testing (e.g. routewise://verify-email?token=xyz).
  static const String appScheme = 'routewise';

  /// Android Application ID / Package name.
  static const String androidPackage = 'com.example.routewise';

  /// iOS Bundle ID.
  static const String iosBundleId = 'com.example.routewise';

  /// Request timeout duration.
  /// Hosted backends on free tiers (like Render) can take 30-50s to wake up from cold sleep.
  static const Duration requestTimeout = Duration(seconds: 60);

  /// Threshold after which a "Server is waking up" notification is shown.
  static const Duration slowResponseNoticeDelay = Duration(seconds: 3);
}
