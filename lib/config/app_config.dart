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

  // ---------------------------------------------------------------- maps

  /// Where the map and address search start before the rider has any stops.
  /// This is central Lagos (Yaba / Ikeja area).
  static const double defaultLat = 6.5244;
  static const double defaultLng = 3.3792;

  /// Mapbox PUBLIC access token (starts with "pk."). Optional.
  ///
  /// Without it the app uses OpenStreetMap / CARTO tiles, which are free but
  /// are meant for light use. Before a public release, pass a token so the map
  /// tiles come from Mapbox instead:
  ///
  ///     flutter run --dart-define=MAPBOX_TOKEN=pk.your-token-here
  ///
  /// A public token is designed to be shipped inside an app. Restrict it to
  /// your app in the Mapbox dashboard. Never put a secret (sk.) token here.
  static const String mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

  /// Sent with every map tile request (OpenStreetMap requires an identifier).
  static const String mapUserAgent = androidPackage;
}
