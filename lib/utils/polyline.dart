import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Decodes a Google / Mapbox "encoded polyline" string into coordinates.
///
/// The backend sends route geometry this way (`route.polyline`, precision 6).
/// Bad input never throws: decoding stops at the first problem and returns the
/// points read so far.
List<LatLng> decodePolyline(String encoded, {int precision = 6}) {
  final factor = math.pow(10, precision).toDouble();
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  // Reads one signed number; returns null if the string ends early.
  int? readValue() {
    var shift = 0;
    var result = 0;
    while (true) {
      if (index >= encoded.length) return null;
      final byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1F) << shift;
      shift += 5;
      if (byte < 0x20) break;
    }
    return (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  }

  while (index < encoded.length) {
    final dLat = readValue();
    final dLng = readValue();
    if (dLat == null || dLng == null) break;
    lat += dLat;
    lng += dLng;
    points.add(LatLng(lat / factor, lng / factor));
  }
  return points;
}
