import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';

/// Hands a destination to a turn-by-turn navigation app (Google Maps or Waze).
///
/// Routewise plans the order of the stops; the phone's navigation app does the
/// voice guidance, live traffic and re-routing. The links below are plain
/// https links: if the app is installed it opens straight into navigation,
/// otherwise the browser shows the map.
class NavigationService {
  NavigationService._();

  /// Google Maps limits a link to 9 waypoints between start and finish.
  static const int maxGoogleMapsStops = 11;

  static String _place(Stop s) =>
      s.hasLocation ? '${s.lat},${s.lng}' : (s.address.isNotEmpty ? s.address : s.name);

  /// Turn-by-turn to one stop, starting from wherever the phone is now.
  static Uri googleMapsTo(Stop stop) => Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': _place(stop),
        'travelmode': 'driving',
        'dir_action': 'navigate',
      });

  /// Waze needs coordinates, so this is null for a stop that has none.
  static Uri? wazeTo(Stop stop) {
    if (!stop.hasLocation) return null;
    return Uri.https('waze.com', '/ul', {
      'll': '${stop.lat},${stop.lng}',
      'navigate': 'yes',
    });
  }

  /// The whole route in one Google Maps link (first stop to last, the rest as
  /// waypoints). Returns the link and how many stops it could include.
  static ({Uri uri, int included}) googleMapsRoute(List<Stop> stops) {
    final used = stops.take(maxGoogleMapsStops).toList();
    final params = <String, String>{
      'api': '1',
      'origin': _place(used.first),
      'destination': _place(used.last),
      'travelmode': 'driving',
    };
    if (used.length > 2) {
      params['waypoints'] = used.sublist(1, used.length - 1).map(_place).join('|');
    }
    return (uri: Uri.https('www.google.com', '/maps/dir/', params), included: used.length);
  }

  /// Opens [uri] outside the app. Returns false if nothing could open it.
  static Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
