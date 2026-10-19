/// "34.6 km", or "—" when the value is unknown.
String formatDistanceM(num? metres) {
  if (metres == null) return '—';
  return '${(metres / 1000).toStringAsFixed(1)} km';
}

/// "42 min" / "1 hr 5 min" / "2 hr", or "—" when the value is unknown.
String formatDurationS(num? seconds) {
  if (seconds == null) return '—';
  final mins = (seconds / 60).round();
  if (mins < 60) return '$mins min';
  final h = mins ~/ 60;
  final m = mins % 60;
  return m > 0 ? '$h hr $m min' : '$h hr';
}
