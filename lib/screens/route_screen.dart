import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../data/api_models.dart';
import '../data/models.dart';
import '../services/api_service.dart';
import '../services/navigation_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/helpers.dart';
import '../utils/polyline.dart';
import '../widgets/action_sheet.dart';
import '../widgets/buttons.dart';
import '../widgets/misc.dart';
import '../widgets/route_map.dart';
import '../widgets/trip_dialogs.dart';
import 'history_screen.dart';
import 'navigation_screen.dart';
import 'plan_screen.dart';

/// Result of a route calculation: map + summary + ordered stops.
///
/// Opened right after planning (with [initialDetail]) or from the Trips list
/// (with just a [tripId]). A trip that is still being calculated is polled
/// until the route is ready.
class RouteScreen extends StatefulWidget {
  const RouteScreen({
    super.key,
    this.tripId,
    required this.title,
    this.initialStops = const [],
    this.initialDistance,
    this.initialTime,
    this.initialSavedPercent,
    this.initialStarred = false,
    this.initialDetail,
  });

  /// Backend trip UUID. When present, trip detail is fetched on mount.
  final String? tripId;
  final String title;

  /// Stops already known to the caller.
  final List<Stop> initialStops;

  /// Summary values shown immediately while the detail loads.
  final String? initialDistance;
  final String? initialTime;
  final String? initialSavedPercent;
  final bool initialStarred;

  /// A trip detail the caller has just fetched (skips the first request).
  final Map<String, dynamic>? initialDetail;

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final GlobalKey<RouteMapState> _mapKey = GlobalKey<RouteMapState>();
  final ScrollController _scroll = ScrollController();

  late String _title;
  late bool _starred;
  late String _distance;
  late String _time;
  String? _savedPercent;
  List<Stop> _stops = [];
  List<LatLng> _line = [];
  bool _lineIsApproximate = false;
  String? _runStatus; // queued | running | succeeded | failed
  String? _runError;
  bool _loadingDetail = false;
  bool _polling = false;
  int _nextUid = 1000;

  bool get _runActive => _runStatus == 'queued' || _runStatus == 'running';
  bool get _ready => _runStatus == 'succeeded' || (_runStatus == null && _stops.length >= 2);

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _starred = widget.initialStarred;
    _distance = widget.initialDistance ?? '—';
    _time = widget.initialTime ?? '—';
    _savedPercent = widget.initialSavedPercent;
    _stops = List<Stop>.of(widget.initialStops);

    if (widget.initialDetail != null) {
      _parse(widget.initialDetail!);
    }
    if (widget.tripId != null) {
      if (widget.initialDetail == null) {
        unawaited(_fetchDetail());
      } else if (_runActive) {
        unawaited(_poll());
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- loading

  /// Reads a `GET /trips/{id}` response into the fields above (no setState).
  void _parse(Map<String, dynamic> data) {
    final route = data['route'] as Map<String, dynamic>?;
    final run = data['latest_run'] as Map<String, dynamic>?;

    _title = (data['title'] as String?) ?? _title;
    _starred = (data['is_starred'] as bool?) ?? _starred;
    _runStatus = run?['status'] as String?;
    _runError = run?['error_message'] as String?;

    if (route != null) {
      _distance = formatDistanceM(route['total_distance_m'] as num?);
      _time = formatDurationS(route['total_duration_s'] as num?);
      final saved = route['percent_saved'] as num?;
      _savedPercent = saved == null ? null : '${saved.round()}%';
    }

    final stops = <Stop>[];
    final routeStops = route?['stops'] as List<dynamic>?;
    if (routeStops != null && routeStops.isNotEmpty) {
      // Optimised visiting order.
      for (final s in routeStops.whereType<Map<String, dynamic>>()) {
        stops.add(Stop(
          uid: _nextUid++,
          name: (s['name'] as String?) ?? 'Stop',
          address: (s['address'] as String?) ?? '',
          legDistanceM: (s['leg_distance_m'] as num?)?.toDouble(),
          legDurationS: (s['leg_duration_s'] as num?)?.toDouble(),
          lat: (s['lat'] as num?)?.toDouble(),
          lng: (s['lng'] as num?)?.toDouble(),
        ));
      }
    } else {
      // No finished route yet: show the stops in the order they were entered.
      final input = data['stops'] as List<dynamic>?;
      for (final s in (input ?? const []).whereType<Map<String, dynamic>>()) {
        stops.add(Stop(
          uid: _nextUid++,
          name: (s['name'] as String?) ?? 'Stop',
          address: (s['address'] as String?) ?? '',
          lat: (s['lat'] as num?)?.toDouble(),
          lng: (s['lng'] as num?)?.toDouble(),
        ));
      }
    }
    if (stops.isNotEmpty) _stops = stops;

    // Road geometry for the map.
    final encoded = route?['polyline'] as String?;
    if (encoded != null && encoded.isNotEmpty) {
      _line = decodePolyline(encoded, precision: (route?['polyline_precision'] as num?)?.toInt() ?? 6);
      _lineIsApproximate = (route?['geometry_is_fallback'] as bool?) ?? false;
    } else if (_runStatus == 'succeeded') {
      _line = [
        for (final s in _stops)
          if (s.hasLocation) LatLng(s.lat!, s.lng!),
      ];
      _lineIsApproximate = true;
    }
  }

  void _apply(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      _parse(data);
      _loadingDetail = false;
    });
  }

  Future<void> _fetchDetail() async {
    final id = widget.tripId;
    if (id == null) return;
    setState(() => _loadingDetail = true);
    try {
      final data = await ApiService.instance.getTrip(id);
      _apply(data);
      if (_runActive) unawaited(_poll());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadingDetail = false);
      showInfo(context, e.message);
    }
  }

  Future<void> _poll() async {
    final id = widget.tripId;
    if (id == null || _polling) return;
    setState(() => _polling = true);
    try {
      final data = await ApiService.instance.waitForRun(id, timeout: const Duration(minutes: 3));
      _apply(data);
      unawaited(appState.refreshTrips());
    } on ApiException catch (e) {
      if (mounted) showInfo(context, e.message);
    } finally {
      if (mounted) setState(() => _polling = false);
    }
  }

  Future<void> _recalculate() async {
    final id = widget.tripId;
    if (id == null) return;
    try {
      await ApiService.instance.recalculateTrip(id);
    } on ApiException catch (e) {
      // 409 = it is already being calculated; just keep watching it.
      if (e.statusCode != 409) {
        if (mounted) showInfo(context, e.message);
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _runStatus = 'queued';
      _runError = null;
    });
    unawaited(_poll());
  }

  // ------------------------------------------------------------- actions

  void _backToTrips() => Navigator.of(context).popUntil((r) => r.isFirst);

  void _edit() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanScreen(editing: true, sourceTitle: _title, initialStops: _stops),
      ),
    );
  }

  void _history() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistoryScreen(title: _title, tripId: widget.tripId),
      ),
    );
  }

  void _startNavigation() {
    if (_stops.length < 2) {
      showInfo(context, 'Add at least two stops to navigate.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NavigationScreen(
          title: _title,
          stops: _stops,
          line: _line,
          lineIsApproximate: _lineIsApproximate,
        ),
      ),
    );
  }

  void _toggleStar() {
    final next = !_starred;
    setState(() => _starred = next);
    final id = widget.tripId;
    if (id != null) {
      ApiService.instance
          .patchTrip(id, isStarred: next)
          .then((_) => appState.refreshTrips())
          .catchError((_) {
        if (mounted) setState(() => _starred = !next);
      });
    }
  }

  Future<void> _rename() async {
    final id = widget.tripId;
    if (id == null) return;
    final name = await promptRenameTrip(context, _title);
    if (name == null || name == _title || !mounted) return;
    try {
      await appState.renameTrip(id, name);
      if (mounted) setState(() => _title = name);
    } on ApiException catch (e) {
      if (mounted) showInfo(context, e.message);
    }
  }

  Future<void> _delete() async {
    final id = widget.tripId;
    if (id == null) return;
    if (!await confirmDeleteTrip(context, _title) || !mounted) return;
    try {
      await appState.deleteTrip(id);
      if (mounted) _backToTrips();
    } on ApiException catch (e) {
      if (mounted) showInfo(context, e.message);
    }
  }

  String _asText() {
    final b = StringBuffer(_title);
    if (_distance != '—') b.write('\n$_distance · $_time');
    for (var i = 0; i < _stops.length; i++) {
      final s = _stops[i];
      b.write('\n${i + 1}. ${s.name}');
      if (s.address.isNotEmpty && s.address != s.name) b.write(' — ${s.address}');
    }
    return b.toString();
  }

  Future<void> _copyRoute() async {
    await Clipboard.setData(ClipboardData(text: _asText()));
    if (mounted) showInfo(context, 'Route copied. Paste it into WhatsApp or a note.');
  }

  Future<void> _openInGoogleMaps() async {
    if (_stops.length < 2) return;
    final link = NavigationService.googleMapsRoute(_stops);
    final opened = await NavigationService.open(link.uri);
    if (!mounted) return;
    if (!opened) {
      showInfo(context, 'Could not open Google Maps.');
    } else if (link.included < _stops.length) {
      showInfo(context, 'Google Maps takes ${link.included} stops per link. Use Start navigation for the rest.');
    }
  }

  void _showActions() {
    showActionSheet(
      context,
      title: _title,
      actions: [
        SheetAction(
          icon: Icons.edit_outlined,
          label: 'Rename trip',
          onTap: _rename,
        ),
        SheetAction(
          icon: _starred ? Icons.star_border_rounded : Icons.star_rounded,
          label: _starred ? 'Remove star' : 'Star trip',
          onTap: _toggleStar,
        ),
        SheetAction(
          icon: Icons.content_copy_rounded,
          label: 'Edit a copy',
          subtitle: 'Change the stops without touching this route',
          onTap: _edit,
        ),
        SheetAction(
          icon: Icons.map_outlined,
          label: 'Open whole route in Google Maps',
          onTap: _openInGoogleMaps,
        ),
        SheetAction(
          icon: Icons.ios_share_rounded,
          label: 'Copy route as text',
          subtitle: 'Send the stop list to someone',
          onTap: _copyRoute,
        ),
        SheetAction(
          icon: Icons.delete_outline_rounded,
          label: 'Delete trip',
          danger: true,
          onTap: _delete,
        ),
      ],
    );
  }

  void _focusStop(Stop stop) {
    if (!stop.hasLocation) {
      showInfo(context, 'This stop has no map position yet.');
      return;
    }
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    _mapKey.currentState?.focusOn(LatLng(stop.lat!, stop.lng!));
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = isWide(context);
    if (wide) {
      return Scaffold(
        backgroundColor: c.surface,
        body: Row(
          children: [
            Expanded(flex: 125, child: _mapBlock(context, wide)),
            Expanded(
              flex: 75,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 30),
                child: _panel(context, wide),
              ),
            ),
          ],
        ),
      );
    }
    final mapHeight = math.max(360.0, MediaQuery.sizeOf(context).height * 0.5);
    return Scaffold(
      backgroundColor: c.canvas,
      body: SingleChildScrollView(
        controller: _scroll,
        child: Column(
          children: [
            SizedBox(height: mapHeight, child: _mapBlock(context, wide)),
            Container(
              width: double.infinity,
              color: c.surface,
              padding: EdgeInsets.fromLTRB(18, 4, 18, 35 + MediaQuery.paddingOf(context).bottom),
              child: _panel(context, wide),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- map

  List<MapMarkerData> _markers(AppColors c) {
    final located = [
      for (var i = 0; i < _stops.length; i++)
        if (_stops[i].hasLocation) (i, _stops[i]),
    ];
    return [
      for (final (i, s) in located)
        MapMarkerData(
          point: LatLng(s.lat!, s.lng!),
          label: '${i + 1}',
          color: i == 0 ? c.accent : (i == _stops.length - 1 ? c.ink : c.primary),
          icon: i == 0 ? Icons.home_outlined : null,
        ),
    ];
  }

  Widget _mapBlock(BuildContext context, bool wide) {
    final c = context.c;
    final top = MediaQuery.paddingOf(context).top + 20;
    return Stack(
      children: [
        Positioned.fill(
          child: RouteMap(
            key: _mapKey,
            markers: _markers(c),
            line: _line,
            lineIsApproximate: _lineIsApproximate,
            stopPoints: [
              for (final s in _stops)
                if (s.hasLocation) LatLng(s.lat!, s.lng!),
            ],
            largePins: true,
            fitPadding: EdgeInsets.fromLTRB(44, top + 70, 44, wide ? 70 : 90),
            controlsBottom: wide ? 24 : 48,
            attributionBottom: wide ? 4 : 30,
            onMarkerTap: (_) {},
          ),
        ),
        Positioned(
          top: top,
          left: 20,
          right: 20,
          child: Row(
            children: [
              AppIconButton(
                icon: Icons.arrow_back_rounded,
                label: 'Back to trips',
                elevated: true,
                onPressed: _backToTrips,
              ),
              const SizedBox(width: 9),
              if (wide)
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 310),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: c.shadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.heading(14.5, c.ink, weight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(_statusLine(), style: AppText.body(11.2, c.muted)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 9),
              AppIconButton(
                icon: _starred ? Icons.star_rounded : Icons.star_border_rounded,
                label: _starred ? 'Unstar trip' : 'Star trip',
                active: _starred,
                elevated: true,
                onPressed: _toggleStar,
              ),
              const SizedBox(width: 9),
              AppIconButton(
                icon: Icons.more_horiz_rounded,
                label: 'Trip actions',
                elevated: true,
                onPressed: _showActions,
              ),
            ],
          ),
        ),
        if (!wide)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 24,
            child: Container(
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: c.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _statusLine() {
    if (_loadingDetail) return 'Loading route details…';
    if (_runActive) return 'Calculating…';
    if (_runStatus == 'failed') return 'Calculation failed';
    return 'Route ready';
  }

  // --------------------------------------------------------------- panel

  Widget _statusBanner(BuildContext context) {
    final c = context.c;
    if (_runStatus == 'failed') {
      return Container(
        margin: const EdgeInsets.only(bottom: 17),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.dangerSoft, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This route could not be calculated',
                style: AppText.body(14, c.danger, weight: FontWeight.w700)),
            if (_runError != null && _runError!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_runError!, style: AppText.body(13, c.danger)),
            ],
            const SizedBox(height: 8),
            TextAction(label: 'Try again', icon: Icons.refresh_rounded, onPressed: _recalculate),
          ],
        ),
      );
    }
    if (_runActive) {
      return Container(
        margin: const EdgeInsets.only(bottom: 17),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            if (_polling)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
              )
            else
              Icon(Icons.hourglass_top_rounded, size: 18, color: c.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _polling
                    ? 'Finding the best order for your stops…'
                    : 'Taking longer than usual.',
                style: AppText.body(13.5, c.ink),
              ),
            ),
            if (!_polling) TextAction(label: 'Check again', onPressed: _poll),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _panel(BuildContext context, bool wide) {
    final c = context.c;
    final stops = _stops;
    final start = AppButton(
      label: 'Start navigation',
      icon: Icons.navigation_rounded,
      expand: true,
      onPressed: _ready && stops.length >= 2 ? _startNavigation : null,
    );
    final edit = AppButton(
      label: 'Edit stops',
      icon: Icons.content_copy_rounded,
      variant: ButtonVariant.secondary,
      expand: true,
      onPressed: _edit,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loadingDetail || _runActive || _runStatus == 'failed') ...[
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: _loadingDetail
                  ? Padding(
                      padding: const EdgeInsets.all(6),
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                    )
                  : Icon(Icons.auto_awesome_rounded, size: 17, color: c.primary),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                _loadingDetail
                    ? 'LOADING…'
                    : _runActive
                        ? 'CALCULATING…'
                        : _runStatus == 'failed'
                            ? 'NOT CALCULATED'
                            : 'ROUTE READY',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(11.2, c.primary, weight: FontWeight.w800, letterSpacing: 1.1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ],
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title, style: AppText.heading(wide ? 28 : 23, c.ink, height: 1.14)),
                  const SizedBox(height: 5),
                  Text(
                    stops.isNotEmpty
                        ? (_ready ? 'Best route for ${stops.length} stops' : '${stops.length} stops')
                        : 'Loading stop order…',
                    style: AppText.body(15, c.muted),
                  ),
                ],
              ),
            ),
            if (_savedPercent != null && _ready) ...[
              const SizedBox(width: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(_savedPercent!, style: AppText.heading(23, c.accent)),
                    Text('shorter route',
                        style: AppText.body(10.4, c.accent, weight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        _statusBanner(context),
        _summary(context, stops.length),
        const SizedBox(height: 17),
        if (wide)
          Row(
            children: [
              Expanded(flex: 125, child: start),
              const SizedBox(width: 9),
              Expanded(flex: 100, child: edit),
            ],
          )
        else ...[
          start,
          const SizedBox(height: 9),
          edit,
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Flexible(child: Text('Stop order', style: AppText.heading(18, c.ink))),
            const Spacer(),
            TextAction(label: 'Run history', icon: Icons.history_rounded, onPressed: _history),
          ],
        ),
        const SizedBox(height: 7),
        Divider(height: 1, color: c.line),
        if (_loadingDetail && stops.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: c.primary),
                  const SizedBox(height: 12),
                  Text('Loading route details…', style: AppText.body(14, c.muted)),
                ],
              ),
            ),
          )
        else
          for (var i = 0; i < stops.length; i++)
            _OrderedStop(
              stop: stops[i],
              index: i,
              isLast: i == stops.length - 1,
              onTap: () => _focusStop(stops[i]),
            ),
        Divider(height: 1, color: c.line),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: AppButton(
                label: 'Recalculate',
                icon: Icons.refresh_rounded,
                variant: ButtonVariant.ghost,
                onPressed: widget.tripId == null || _runActive ? null : _recalculate,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: AppButton(
                label: 'More actions',
                icon: Icons.more_horiz_rounded,
                variant: ButtonVariant.ghost,
                onPressed: _showActions,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summary(BuildContext context, int stopCount) {
    final c = context.c;
    final cells = [
      (Icons.map_outlined, 'Total distance', _distance),
      (Icons.schedule_rounded, 'Estimated time', _time),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < cells.length; i++)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: i == 0
                      ? null
                      : BoxDecoration(border: Border(left: BorderSide(color: c.line))),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cells[i].$1, size: 22, color: c.primary),
                      const SizedBox(height: 8),
                      Text(cells[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(10.4, c.muted)),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(cells[i].$3,
                            maxLines: 1,
                            style: AppText.body(13, c.ink, weight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrderedStop extends StatelessWidget {
  const _OrderedStop({
    required this.stop,
    required this.index,
    required this.isLast,
    required this.onTap,
  });

  final Stop stop;
  final int index;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isStart = index == 0;
    final isEnd = isLast && index > 0;
    final fill = isStart ? c.accent : (isEnd ? c.ink : Colors.transparent);
    final border = isStart ? c.accent : (isEnd ? c.ink : c.primary);
    final textColor = (isStart || isEnd) ? (isEnd ? c.canvas : Colors.white) : c.primary;

    return InkWell(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 38,
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  children: [
                    Container(
                      width: 29,
                      height: 29,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: fill,
                        shape: BoxShape.circle,
                        border: Border.all(color: border, width: 2),
                      ),
                      child: isStart
                          ? const Icon(Icons.home_outlined, size: 14, color: Colors.white)
                          : Text('${index + 1}',
                              style: AppText.body(11.5, textColor, weight: FontWeight.w800)),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: DottedLine(color: c.line),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 14, 0, isLast ? 14 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.name, style: AppText.body(14.5, c.ink, weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(stop.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(12, c.muted)),
                    if (index > 0 && stop.legSummary != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${stop.legSummary} from previous stop',
                        style: AppText.body(11, c.primary, weight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 22),
              child: Icon(Icons.chevron_right_rounded, color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}
