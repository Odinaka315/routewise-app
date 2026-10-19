import 'package:flutter_test/flutter_test.dart';
import 'package:routewise/data/models.dart';
import 'package:routewise/services/navigation_service.dart';
import 'package:routewise/utils/format.dart';
import 'package:routewise/utils/polyline.dart';

void main() {
  group('decodePolyline', () {
    // Produced by the backend's own encoder (app/services/polyline.py, precision 6).
    const encoded = 'wzhlKwdwlEnrWv|ZwucF_jAvajJwx{B';

    test('reads the backend format', () {
      final points = decodePolyline(encoded);
      expect(points, hasLength(4));
      expect(points[0].latitude, closeTo(6.5095, 1e-9));
      expect(points[0].longitude, closeTo(3.3711, 1e-9));
      expect(points[3].latitude, closeTo(6.4281, 1e-9));
      expect(points[3].longitude, closeTo(3.4219, 1e-9));
    });

    test('never throws on truncated or empty input', () {
      expect(decodePolyline(''), isEmpty);
      expect(decodePolyline(encoded.substring(0, 5)), isA<List>());
    });
  });

  group('Stop.toApiJson', () {
    test('sends coordinates and their source when known', () {
      const stop = Stop(
        uid: 1,
        name: 'Ikeja City Mall',
        address: 'Obafemi Awolowo Way',
        lat: 6.614,
        lng: 3.358,
        source: 'mapbox',
        placeId: 'abc',
      );
      expect(stop.toApiJson(), {
        'name': 'Ikeja City Mall',
        'address': 'Obafemi Awolowo Way',
        'lat': 6.614,
        'lng': 3.358,
        'geocode_source': 'mapbox',
        'place_provider_id': 'abc',
      });
    });

    test('sends only the address when the stop has no position', () {
      const stop = Stop(uid: 2, name: '12 Foo St', address: '12 Foo St, Yaba');
      expect(stop.toApiJson(), {'name': '12 Foo St', 'address': '12 Foo St, Yaba'});
      expect(stop.hasLocation, isFalse);
    });
  });

  group('NavigationService', () {
    const a = Stop(uid: 1, name: 'A', address: 'A st', lat: 6.5, lng: 3.3);
    const b = Stop(uid: 2, name: 'B', address: 'B st', lat: 6.6, lng: 3.4);
    const c = Stop(uid: 3, name: 'C', address: 'C st', lat: 6.7, lng: 3.5);
    const noPos = Stop(uid: 4, name: 'D', address: '4 Allen Avenue, Ikeja');

    test('Google Maps link navigates to the stop', () {
      final uri = NavigationService.googleMapsTo(b);
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['destination'], '6.6,3.4');
      expect(uri.queryParameters['dir_action'], 'navigate');
    });

    test('a stop without coordinates falls back to its address', () {
      final uri = NavigationService.googleMapsTo(noPos);
      expect(uri.queryParameters['destination'], '4 Allen Avenue, Ikeja');
      expect(NavigationService.wazeTo(noPos), isNull);
    });

    test('Waze link uses coordinates', () {
      final uri = NavigationService.wazeTo(a)!;
      expect(uri.queryParameters['ll'], '6.5,3.3');
      expect(uri.queryParameters['navigate'], 'yes');
    });

    test('whole-route link has origin, waypoints and destination', () {
      final link = NavigationService.googleMapsRoute([a, b, c]);
      expect(link.included, 3);
      expect(link.uri.queryParameters['origin'], '6.5,3.3');
      expect(link.uri.queryParameters['waypoints'], '6.6,3.4');
      expect(link.uri.queryParameters['destination'], '6.7,3.5');
    });
  });

  group('format', () {
    test('distance and duration', () {
      expect(formatDistanceM(34600), '34.6 km');
      expect(formatDistanceM(null), '—');
      expect(formatDurationS(42 * 60), '42 min');
      expect(formatDurationS(65 * 60), '1 hr 5 min');
      expect(formatDurationS(120 * 60), '2 hr');
    });
  });
}
