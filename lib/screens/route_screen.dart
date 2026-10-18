import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/buttons.dart';
import '../widgets/map_views.dart';
import '../widgets/misc.dart';
import 'history_screen.dart';
import 'plan_screen.dart';

/// Result of a route calculation: map + summary + ordered stops.
/// When opened from the Trips list, loads the full trip detail (stops with
/// leg distances / times) from the backend.  Falls back gracefully if the
/// network is unavailable.
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
  });

  /// Backend trip UUID. When present, trip detail is fetched on mount.
  final String? tripId;
  final String title;

  /// Stops already resolved by the caller (e.g. after creating a new trip).
  final List<Stop> initialStops;

  /// Summary values shown immediately while the detail loads.
  final String? initialDistance;
  final String? initialTime;
  final String? initialSavedPercent;
  final bool initialStarred;

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  late bool _starred;
  late String _distance;
  late String _time;
  String? _savedPercent;
  List<Stop> _stops = [];
  bool _loadingDetail = false;
  int _nextUid = 1000;

  @override
  void initState() {
    super.initState();
    _starred = widget.initialStarred;
    _distance = widget.initialDistance ?? '—';
    _time = widget.initialTime ?? '—';
    _savedPercent = widget.initialSavedPercent;
    _stops = List<Stop>.of(widget.initialStops);

    if (widget.tripId != null) {
      _fetchDetail(widget.tripId!);
    }
  }

  Future<void> _fetchDetail(String tripId) async {
    setState(() => _loadingDetail = true);
    try {
      final data = await ApiService.instance.getTrip(tripId);

      final routeData = data['route'] as Map<String, dynamic>?;
      final latestRun = data['latest_run'] as Map<String, dynamic>?;

      final distM = (routeData?['total_distance_m'] ?? latestRun?['total_distance_m']) as num?;
      final durS = (routeData?['total_duration_s'] ?? latestRun?['total_duration_s']) as num?;
      final saved = routeData?['percent_saved'] as num?;

      String newDist = _distance;
      String newTime = _time;
      String? newSaved = _savedPercent;

      if (distM != null) {
        newDist = '${(distM / 1000).toStringAsFixed(1)} km';
      }
      if (durS != null) {
        final mins = (durS / 60).round();
        if (mins >= 60) {
          final h = mins ~/ 60;
          final m = mins % 60;
          newTime = '$h hr ${m > 0 ? '$m min' : ''}'.trim();
        } else {
          newTime = '$mins min';
        }
      }
      if (saved != null) newSaved = '${saved.round()}%';

      final List<Stop> newStops = [];

      // Try to use the optimised stop order from route.stops (RouteStopOut)
      final routeStops = routeData?['stops'] as List<dynamic>?;
      if (routeStops != null && routeStops.isNotEmpty) {
        for (final s in routeStops) {
          if (s is Map<String, dynamic>) {
            newStops.add(Stop(
              uid: _nextUid++,
              name: (s['name'] as String?) ?? 'Stop',
              address: (s['address'] as String?) ?? '',
              legDistanceM: (s['leg_distance_m'] as num?)?.toDouble(),
              legDurationS: (s['leg_duration_s'] as num?)?.toDouble(),
              lat: (s['lat'] as num?)?.toDouble(),
              lng: (s['lng'] as num?)?.toDouble(),
            ));
          }
        }
      } else {
        // Fallback: use input stops (StopOut)
        final inputStops = data['stops'] as List<dynamic>?;
        if (inputStops != null) {
          for (final s in inputStops) {
            if (s is Map<String, dynamic>) {
              newStops.add(Stop(
                uid: _nextUid++,
                name: (s['name'] as String?) ?? 'Stop',
                address: (s['address'] as String?) ?? '',
                lat: (s['lat'] as num?)?.toDouble(),
                lng: (s['lng'] as num?)?.toDouble(),
              ));
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _distance = newDist;
        _time = newTime;
        _savedPercent = newSaved;
        if (newStops.isNotEmpty) _stops = newStops;
        _starred = (data['is_starred'] as bool?) ?? _starred;
        _loadingDetail = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  void _backToTrips() => Navigator.of(context).popUntil((r) => r.isFirst);

  void _edit() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanScreen(
          editing: true,
          sourceTitle: widget.title,
          initialStops: _stops,
        ),
      ),
    );
  }

  void _history() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => HistoryScreen(
                title: widget.title,
                tripId: widget.tripId,
              )),
    );
  }

  void _toggleStar() {
    final nextStar = !_starred;
    setState(() => _starred = nextStar);
    if (widget.tripId != null) {
      ApiService.instance
          .patchTrip(widget.tripId!, isStarred: nextStar)
          .then((_) => appState.refreshTrips())
          .catchError((_) {
        if (mounted) setState(() => _starred = !nextStar);
      });
    }
  }

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
    final mapHeight = math.max(390.0, MediaQuery.sizeOf(context).height * 0.54);
    return Scaffold(
      backgroundColor: c.canvas,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: mapHeight, child: _mapBlock(context, wide)),
            Container(
              width: double.infinity,
              color: c.surface,
              padding: EdgeInsets.fromLTRB(
                18,
                4,
                18,
                35 + MediaQuery.paddingOf(context).bottom,
              ),
              child: _panel(context, wide),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- map

  Widget _mapBlock(BuildContext context, bool wide) {
    final c = context.c;
    final top = MediaQuery.paddingOf(context).top + 20;
    return Stack(
      children: [
        Positioned.fill(
          child: ResultMap(
            stopCount: _stops.isNotEmpty ? _stops.length : 1,
            controlsBottom: wide ? 24 : 48,
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
                          Text(widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.heading(14.5, c.ink, weight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            _loadingDetail ? 'Loading route details…' : 'Route ready',
                            style: AppText.body(11.2, c.muted),
                          ),
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
                onPressed: () => showInfo(context, 'Trip actions are coming soon'),
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

  // ---------------------------------------------------------------- panel

  Widget _panel(BuildContext context, bool wide) {
    final c = context.c;
    final stops = _stops;
    final start = AppButton(
      label: 'Start navigation',
      icon: Icons.arrow_forward_rounded,
      expand: true,
      onPressed: () => showInfo(context, 'Navigation is not connected yet'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('SUGGESTED',
            style: AppText.body(9, Colors.white.withValues(alpha: 0.8))),
      ),
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: c.primary),
                    )
                  : Icon(Icons.auto_awesome_rounded, size: 17, color: c.primary),
            ),
            const SizedBox(width: 9),
            Text(
              _loadingDetail ? 'LOADING…' : 'ROUTE READY',
              style: AppText.body(11.2, c.primary,
                  weight: FontWeight.w800, letterSpacing: 1.1),
            ),
          ],
        ),
        const SizedBox(height: 19),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: AppText.heading(wide ? 28 : 23, c.ink, height: 1.14)),
                  const SizedBox(height: 5),
                  Text(
                    stops.isNotEmpty
                        ? 'Best route for ${stops.length} stops'
                        : 'Loading stop order…',
                    style: AppText.body(15, c.muted),
                  ),
                ],
              ),
            ),
            if (_savedPercent != null) ...[
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
        const SizedBox(height: 25),
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
        const SizedBox(height: 29),
        Row(
          children: [
            Text('Stop order', style: AppText.heading(18, c.ink)),
            const SizedBox(width: 8),
            const CountBadge('Optimised'),
            const Spacer(),
            TextAction(
              label: 'Run history',
              icon: Icons.history_rounded,
              onPressed: _history,
            ),
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
            _OrderedStop(stop: stops[i], index: i, isLast: i == stops.length - 1),
        Divider(height: 1, color: c.line),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppButton(
              label: 'Recalculate',
              icon: Icons.history_rounded,
              variant: ButtonVariant.ghost,
              onPressed: _history,
            ),
            AppButton(
              label: 'More actions',
              icon: Icons.more_horiz_rounded,
              variant: ButtonVariant.ghost,
              onPressed: () => showInfo(context, 'More actions are coming soon'),
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
      (Icons.location_on_outlined, 'Stops', '${stopCount > 0 ? stopCount : '—'} stops'),
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
                  decoration: i == 0
                      ? null
                      : BoxDecoration(border: Border(left: BorderSide(color: c.line))),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cells[i].$1, size: 22, color: c.primary),
                      const SizedBox(height: 8),
                      Text(cells[i].$2, style: AppText.body(10.4, c.muted)),
                      const SizedBox(height: 3),
                      Text(cells[i].$3,
                          textAlign: TextAlign.center,
                          style: AppText.body(13, c.ink, weight: FontWeight.w700)),
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
  const _OrderedStop({required this.stop, required this.index, required this.isLast});

  final Stop stop;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isStart = index == 0;
    final isEnd = isLast && index > 0;
    final fill = isStart ? c.accent : (isEnd ? c.ink : Colors.transparent);
    final border = isStart ? c.accent : (isEnd ? c.ink : c.primary);
    final textColor = (isStart || isEnd) ? (isEnd ? c.canvas : Colors.white) : c.primary;

    return IntrinsicHeight(
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
                  Text(stop.name,
                      style: AppText.body(14.5, c.ink, weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(stop.address,
                      maxLines: 1,
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
    );
  }
}
