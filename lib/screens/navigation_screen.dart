import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../data/models.dart';
import '../services/navigation_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/buttons.dart';
import '../widgets/misc.dart';
import '../widgets/route_map.dart';

/// Drives a delivery run, one stop at a time.
///
/// Routewise decides the order; the phone's navigation app (Google Maps or
/// Waze) gives the voice directions and live traffic. The rider taps
/// "Navigate", drives, comes back and taps "Delivered" (the app also asks when
/// they return from the navigation app), and the next stop is lined up.
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    super.key,
    required this.title,
    required this.stops,
    this.line = const [],
    this.lineIsApproximate = false,
  });

  final String title;

  /// Stops in visiting order. The first one is where the run starts.
  final List<Stop> stops;

  /// Route geometry to draw under the pins (optional).
  final List<LatLng> line;
  final bool lineIsApproximate;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> with WidgetsBindingObserver {
  final GlobalKey<RouteMapState> _mapKey = GlobalKey<RouteMapState>();
  final DraggableScrollableController _sheetCtl = DraggableScrollableController();
  double _sheetSize = 0.5; // current height of the bottom sheet, as a fraction of the screen
  double _sheetMin = 0.14;
  late final Set<int> _done = <int>{0}; // the starting point needs no delivery
  late int _current;
  bool _launched = false;

  List<Stop> get _stops => widget.stops;
  int get _total => _stops.length - 1;
  int get _deliveredCount => _done.length - 1;
  bool get _finished => _done.length >= _stops.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sheetCtl.addListener(_onSheetMoved);
    _current = _stops.length > 1 ? 1 : 0;
    if (_stops.length <= 1) _done.add(0);
  }

  @override
  void dispose() {
    _sheetCtl.removeListener(_onSheetMoved);
    _sheetCtl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the navigation app: ask whether the rider has arrived.
    if (state == AppLifecycleState.resumed && _launched && !_finished) {
      _launched = false;
      final stop = _stops[_current];
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 15),
            content: Text('Arrived at ${stop.name}?'),
            action: SnackBarAction(label: 'Delivered', onPressed: _markDelivered),
          ),
        );
    }
  }

  int? _nextPending(int from) {
    for (var step = 1; step <= _stops.length; step++) {
      final i = (from + step) % _stops.length;
      if (!_done.contains(i)) return i;
    }
    return null;
  }

  void _markDelivered() {
    if (!mounted || _finished || _done.contains(_current)) return;
    setState(() {
      _done.add(_current);
      final next = _nextPending(_current);
      if (next != null) _current = next;
    });
    _focusCurrent();
  }

  void _skip() {
    final next = _nextPending(_current);
    if (next == null || next == _current) return;
    setState(() => _current = next);
    _focusCurrent();
  }

  void _select(int index) {
    if (_done.contains(index)) return;
    setState(() => _current = index);
    _focusCurrent();
  }

  void _restart() {
    setState(() {
      _done
        ..clear()
        ..add(0);
      _current = _stops.length > 1 ? 1 : 0;
    });
    _mapKey.currentState?.fitAll();
  }

  void _focusCurrent() {
    final stop = _stops[_current];
    if (stop.hasLocation) {
      _mapKey.currentState?.focusOn(LatLng(stop.lat!, stop.lng!), zoom: 15);
    }
  }

  Future<void> _navigate(Uri? uri, String appName) async {
    if (uri == null) {
      showInfo(context, '$appName needs an exact location for this stop. Use Google Maps instead.');
      return;
    }
    final opened = await NavigationService.open(uri);
    if (!mounted) return;
    if (opened) {
      _launched = true;
    } else {
      showInfo(context, 'Could not open $appName. Is it installed?');
    }
  }

  Future<void> _copyAddress(Stop stop) async {
    final text = stop.address.isNotEmpty ? stop.address : stop.name;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showInfo(context, 'Address copied');
  }

  // ------------------------------------------------------------------ map

  ({List<MapMarkerData> markers, List<int> stopIndexes}) _markers(AppColors c) {
    final markers = <MapMarkerData>[];
    final indexes = <int>[];
    for (var i = 0; i < _stops.length; i++) {
      final stop = _stops[i];
      if (!stop.hasLocation) continue;
      final isCurrent = i == _current && !_finished;
      final isDone = _done.contains(i);
      markers.add(
        MapMarkerData(
          point: LatLng(stop.lat!, stop.lng!),
          label: '${i + 1}',
          color: i == 0 ? c.accent : (isCurrent ? c.blue : c.primary),
          icon: i == 0 ? Icons.home_outlined : (isDone ? Icons.check_rounded : null),
          dimmed: isDone && i != 0,
          emphasised: isCurrent,
        ),
      );
      indexes.add(i);
    }
    return (markers: markers, stopIndexes: indexes);
  }

  Widget _map(
    BuildContext context,
    bool wide, {
    double controlsBottom = 14,
    double fitBottom = 50,
  }) {
    final c = context.c;
    final data = _markers(c);
    return Stack(
      children: [
        Positioned.fill(
          child: RouteMap(
            key: _mapKey,
            markers: data.markers,
            line: widget.line,
            lineIsApproximate: widget.lineIsApproximate,
            largePins: true,
            fitPadding: EdgeInsets.fromLTRB(40, 90, 40, fitBottom),
            controlsBottom: controlsBottom,
            onMarkerTap: (i) => _select(data.stopIndexes[i]),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                AppIconButton(
                  icon: Icons.arrow_back_rounded,
                  label: 'Back to route',
                  elevated: true,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: c.shadowSm,
                    ),
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.heading(14, c.ink, weight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- panel

  Widget _panel(BuildContext context) {
    final c = context.c;
    if (_stops.length < 2) {
      return Text('This route needs at least two stops to navigate.',
          style: AppText.body(15, c.muted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Eyebrow(_finished ? 'Run complete' : 'Next stop'),
            const Spacer(),
            Text('$_deliveredCount of $_total done',
                style: AppText.body(12.5, c.muted, weight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _total == 0 ? 1 : _deliveredCount / _total,
            minHeight: 6,
            color: c.primary,
            backgroundColor: c.soft,
          ),
        ),
        const SizedBox(height: 18),
        if (_finished) _finishedCard(context) else _currentCard(context),
        const SizedBox(height: 26),
        Text('All stops', style: AppText.heading(17, c.ink)),
        const SizedBox(height: 6),
        Divider(height: 1, color: c.line),
        for (var i = 0; i < _stops.length; i++) _stopTile(context, i),
      ],
    );
  }

  Widget _currentCard(BuildContext context, {bool showInfoCard = true}) {
    final c = context.c;
    final stop = _stops[_current];
    final waze = NavigationService.wazeTo(stop);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!showInfoCard) ...[
          if (stop.address.isNotEmpty)
            Text(stop.address, style: AppText.body(14, c.muted, height: 1.4)),
          if (stop.legSummary != null) ...[
            const SizedBox(height: 6),
            Text('${stop.legSummary} from previous stop',
                style: AppText.body(12.5, c.primary, weight: FontWeight.w700)),
          ],
        ] else AppSurface(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.blue, shape: BoxShape.circle),
                child: Text('${_current + 1}',
                    style: AppText.body(14, Colors.white, weight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.name, style: AppText.heading(19, c.ink, height: 1.2)),
                    if (stop.address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(stop.address, style: AppText.body(13.5, c.muted)),
                    ],
                    if (stop.legSummary != null) ...[
                      const SizedBox(height: 8),
                      Text('${stop.legSummary} from previous stop',
                          style: AppText.body(12, c.primary, weight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppButton(
          label: 'Navigate in Google Maps',
          icon: Icons.navigation_rounded,
          expand: true,
          onPressed: () => _navigate(NavigationService.googleMapsTo(stop), 'Google Maps'),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Waze',
                icon: Icons.alt_route_rounded,
                variant: ButtonVariant.secondary,
                expand: true,
                onPressed: waze == null ? null : () => _navigate(waze, 'Waze'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: AppButton(
                label: 'Copy address',
                icon: Icons.content_copy_rounded,
                variant: ButtonVariant.secondary,
                expand: true,
                onPressed: () => _copyAddress(stop),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Delivered',
                icon: Icons.check_rounded,
                variant: ButtonVariant.secondary,
                expand: true,
                onPressed: _markDelivered,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: AppButton(
                label: 'Skip for now',
                icon: Icons.skip_next_rounded,
                variant: ButtonVariant.ghost,
                expand: true,
                onPressed: _nextPending(_current) == null || _nextPending(_current) == _current
                    ? null
                    : _skip,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Directions open in your navigation app. Come back here when you arrive.',
          style: AppText.body(12, c.muted, height: 1.4),
        ),
      ],
    );
  }

  Widget _finishedCard(BuildContext context) {
    final c = context.c;
    return AppSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.primarySoft, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, color: c.primary, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('All $_total stops delivered',
                    style: AppText.heading(18, c.ink, height: 1.2)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Back to route',
            expand: true,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Start over',
            variant: ButtonVariant.ghost,
            expand: true,
            onPressed: _restart,
          ),
        ],
      ),
    );
  }

  Widget _stopTile(BuildContext context, int index) {
    final c = context.c;
    final stop = _stops[index];
    final done = _done.contains(index);
    final current = index == _current && !_finished;
    final isStart = index == 0;
    return InkWell(
      onTap: done ? null : () => _select(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isStart
                    ? c.accent
                    : (done ? c.primarySoft : (current ? c.blue : c.soft)),
                shape: BoxShape.circle,
              ),
              child: isStart
                  ? const Icon(Icons.home_outlined, size: 14, color: Colors.white)
                  : (done
                      ? Icon(Icons.check_rounded, size: 16, color: c.primary)
                      : Text('${index + 1}',
                          style: AppText.body(11.5, current ? Colors.white : c.ink,
                              weight: FontWeight.w800))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(14, done ? c.muted : c.ink,
                        weight: current ? FontWeight.w800 : FontWeight.w600),
                  ),
                  if (stop.address.isNotEmpty)
                    Text(
                      stop.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(12, c.muted),
                    ),
                ],
              ),
            ),
            if (isStart)
              Text('START', style: AppText.body(10.5, c.accent, weight: FontWeight.w800)),
            if (current)
              Icon(Icons.navigation_rounded, size: 18, color: c.blue),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- sheet

  void _onSheetMoved() {
    if (!_sheetCtl.isAttached) return;
    final size = _sheetCtl.size;
    if ((size - _sheetSize).abs() > 0.004 && mounted) setState(() => _sheetSize = size);
  }

  /// Tap the grab handle: collapse the sheet to reveal the map, or bring it back.
  void _toggleSheet() {
    if (!_sheetCtl.isAttached) return;
    final collapse = _sheetCtl.size > _sheetMin + 0.15;
    _sheetCtl.animateTo(
      collapse ? _sheetMin : 0.5,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  /// The always-visible strip of the sheet: where to go next, and a one-tap
  /// way to start the directions even while the map is nearly full screen.
  Widget _peek(BuildContext context) {
    final c = context.c;
    if (_stops.length < 2) {
      return Text('Needs at least two stops', style: AppText.body(15, c.muted));
    }
    if (_finished) {
      return Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.primarySoft, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, color: c.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('All $_total stops delivered',
                style: AppText.heading(17, c.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      );
    }
    final stop = _stops[_current];
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.blue, shape: BoxShape.circle),
          child: Text('${_current + 1}',
              style: AppText.body(15, Colors.white, weight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stop.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.heading(17, c.ink, height: 1.2)),
              const SizedBox(height: 2),
              Text('Next stop · $_deliveredCount of $_total done',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(12.5, c.muted)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: c.primary,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Tooltip(
            message: 'Navigate in Google Maps',
            child: InkWell(
              onTap: () => _navigate(NavigationService.googleMapsTo(stop), 'Google Maps'),
              child: const SizedBox(
                width: 46,
                height: 46,
                child: Icon(Icons.navigation_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sheet(BuildContext context, double height) {
    final c = context.c;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Smallest the sheet can get: handle + the "next stop" strip.
    _sheetMin = math.max(0.1, math.min(0.3, (96 + bottomInset) / height));
    final radius = const BorderRadius.vertical(top: Radius.circular(24));
    return DraggableScrollableSheet(
      controller: _sheetCtl,
      initialChildSize: math.max(_sheetSize, _sheetMin),
      minChildSize: _sheetMin,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.5],
      builder: (context, scroll) => DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(color: Color(0x2E000000), blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: ListView(
            controller: scroll,
            padding: EdgeInsets.fromLTRB(18, 0, 18, 24 + bottomInset),
            children: [
              InkWell(
                onTap: _toggleSheet,
                child: SizedBox(
                  height: 28,
                  child: Center(
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
              ),
              _peek(context),
              if (_stops.length >= 2) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _total == 0 ? 1 : _deliveredCount / _total,
                    minHeight: 6,
                    color: c.primary,
                    backgroundColor: c.soft,
                  ),
                ),
                const SizedBox(height: 16),
                if (_finished)
                  _finishedCard(context)
                else
                  _currentCard(context, showInfoCard: false),
                const SizedBox(height: 26),
                Text('All stops', style: AppText.heading(17, c.ink)),
                const SizedBox(height: 6),
                Divider(height: 1, color: c.line),
                for (var i = 0; i < _stops.length; i++) _stopTile(context, i),
              ],
            ],
          ),
        ),
      ),
    );
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
            Expanded(flex: 6, child: _map(context, wide)),
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
                child: _panel(context),
              ),
            ),
          ],
        ),
      );
    }
    // Phone: the map fills the screen and the details sit in a sheet that can
    // be dragged down (map almost full screen) or up (details).
    return Scaffold(
      backgroundColor: c.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final controlsBottom = math.min(_sheetSize * height + 14, height - 280);
          return Stack(
            children: [
              Positioned.fill(
                child: _map(
                  context,
                  wide,
                  controlsBottom: math.max(14, controlsBottom),
                  fitBottom: height * 0.5 + 20,
                ),
              ),
              Positioned.fill(child: _sheet(context, height)),
            ],
          );
        },
      ),
    );
  }
}
