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

/// Splits a route line into one piece per leg (stop 1 -> stop 2, stop 2 -> stop 3, ...).
///
/// [stops] are the stop coordinates in visiting order. Each stop is matched to
/// the closest point of the line at or after the previous stop, so a route that
/// passes near a later stop early on is not cut in the wrong place. When the
/// line cannot be split sensibly, the whole line is returned as one piece.
List<List<LatLng>> splitLineByStops(List<LatLng> line, List<LatLng> stops) {
  if (line.length < 2 || stops.length < 3) return [line];

  double dist2(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLng = (a.longitude - b.longitude) * math.cos(a.latitude * math.pi / 180);
    return dLat * dLat + dLng * dLng;
  }

  // Index in the line where each stop is reached (first and last are fixed).
  final cuts = <int>[0];
  var from = 0;
  for (var i = 1; i < stops.length - 1; i++) {
    var best = from;
    var bestD = double.infinity;
    for (var k = from; k < line.length; k++) {
      final d = dist2(line[k], stops[i]);
      if (d < bestD) {
        bestD = d;
        best = k;
      }
    }
    cuts.add(best);
    from = best;
  }
  cuts.add(line.length - 1);

  final pieces = <List<LatLng>>[];
  for (var i = 0; i < cuts.length - 1; i++) {
    final a = cuts[i];
    final b = cuts[i + 1];
    if (b > a) pieces.add(line.sublist(a, b + 1));
  }
  return pieces.length == stops.length - 1 ? pieces : [line];
}
