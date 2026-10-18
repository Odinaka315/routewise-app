class Stop {
  const Stop({
    required this.uid,
    required this.name,
    required this.address,
    this.legDistanceM,
    this.legDurationS,
    this.lat,
    this.lng,
  });

  /// Unique id so the same address can appear twice in a list.
  final int uid;
  final String name;
  final String address;
  final double? legDistanceM;
  final double? legDurationS;
  final double? lat;
  final double? lng;

  String? get legSummary {
    if (legDistanceM == null && legDurationS == null) return null;
    final distStr = legDistanceM != null ? '${(legDistanceM! / 1000).toStringAsFixed(1)} km' : '';
    final mins = legDurationS != null ? (legDurationS! / 60).round() : 0;
    final timeStr = mins > 0 ? '$mins min' : '';
    if (distStr.isNotEmpty && timeStr.isNotEmpty) return '$distStr · $timeStr';
    return distStr.isNotEmpty ? distStr : timeStr;
  }

  Stop copyWith({
    int? uid,
    String? name,
    String? address,
    double? legDistanceM,
    double? legDurationS,
    double? lat,
    double? lng,
  }) =>
      Stop(
        uid: uid ?? this.uid,
        name: name ?? this.name,
        address: address ?? this.address,
        legDistanceM: legDistanceM ?? this.legDistanceM,
        legDurationS: legDurationS ?? this.legDurationS,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
      );
}

class Trip {
  const Trip({
    required this.id,
    required this.title,
    required this.stops,
    required this.distance,
    required this.time,
    required this.date,
    this.starred = false,
    this.savedPercent,
    this.editedFrom,
    this.failed = false,
    this.distanceM,
    this.durationS,
    this.createdAt,
  });

  final String id;
  final String title;
  final int stops;
  final String distance;
  final String time;
  final String date;
  final bool starred;
  final String? savedPercent;
  final String? editedFrom;
  final bool failed;
  final double? distanceM;
  final double? durationS;
  final DateTime? createdAt;

  Trip copyWith({
    bool? starred,
    String? title,
    String? distance,
    String? time,
    String? savedPercent,
  }) =>
      Trip(
        id: id,
        title: title ?? this.title,
        stops: stops,
        distance: distance ?? this.distance,
        time: time ?? this.time,
        date: date,
        starred: starred ?? this.starred,
        savedPercent: savedPercent ?? this.savedPercent,
        editedFrom: editedFrom,
        failed: failed,
        distanceM: distanceM,
        durationS: durationS,
        createdAt: createdAt,
      );
}

/// One calculation of a trip (shown on the Run history screen).
class RouteRun {
  const RouteRun({
    required this.date,
    required this.meta,
    required this.distance,
    required this.time,
    required this.summary,
    required this.ready,
  });

  final String date;
  final String meta;
  final String distance;
  final String time;
  final String summary;
  final bool ready;
}
