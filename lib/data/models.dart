class Stop {
  const Stop({required this.uid, required this.name, required this.address});

  /// Unique id so the same address can appear twice in a list.
  final int uid;
  final String name;
  final String address;

  Stop copyWith({int? uid}) =>
      Stop(uid: uid ?? this.uid, name: name, address: address);
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

  Trip copyWith({bool? starred}) => Trip(
        id: id,
        title: title,
        stops: stops,
        distance: distance,
        time: time,
        date: date,
        starred: starred ?? this.starred,
        savedPercent: savedPercent,
        editedFrom: editedFrom,
        failed: failed,
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
