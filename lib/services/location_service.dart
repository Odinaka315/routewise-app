import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Thrown with a message that is safe to show to the rider.
class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationService {
  LocationService._();

  /// The phone's current position. Asks for permission the first time.
  static Future<LatLng> current() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationException('Location is switched off. Turn it on and try again.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('Allow location access to use your current position.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location access is blocked. Allow it for Routewise in your phone settings.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      throw const LocationException(
        'Could not get your position. Move to an open area and try again.',
      );
    }
  }
}
