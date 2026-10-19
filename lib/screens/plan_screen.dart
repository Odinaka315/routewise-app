import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../data/api_models.dart';
import '../data/models.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/buttons.dart';
import '../widgets/fields.dart';
import '../widgets/misc.dart';
import '../widgets/route_map.dart';
import '../widgets/segmented.dart';
import 'calculating_view.dart';
import 'pin_picker_screen.dart';
import 'route_screen.dart';

const List<String> _optimiseLabels = ['Fastest', 'Balanced', 'Shortest'];
const List<String> _typeLabels = ['One-way', 'Return to start'];

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    this.editing = false,
    this.sourceTitle = 'Monday mainland run',
    this.initialStops,
  });

  /// Editing a copy of an existing route.
  final bool editing;
  final String sourceTitle;
  final List<Stop>? initialStops;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late final TextEditingController _title;
  late final TextEditingController _searchCtrl;
  late List<Stop> _stops;
  late int _optimise;
  late int _routeType;
  int _nextUid = 1000;
  bool _showAdd = false;
  bool _calculating = false;
  bool _searching = false;
  bool _locating = false;
  bool _resolving = false;
  int _searchSeq = 0;
  String? _searchError;
  String _searchedQuery = '';
  List<GeocodeResult> _geocodeResults = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: widget.editing
          ? '${widget.sourceTitle} · copy'
          : '${weekdayName(DateTime.now())} mainland drops',
    );
    _searchCtrl = TextEditingController();
    _stops = List<Stop>.of(widget.initialStops ?? []);
    _optimise = appState.defaultOptimise;
    _routeType = appState.defaultRouteType;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Where to centre address search: the last stop that is on the map, else Lagos.
  LatLng get _searchBias {
    for (var i = _stops.length - 1; i >= 0; i--) {
      if (_stops[i].hasLocation) return LatLng(_stops[i].lat!, _stops[i].lng!);
    }
    return LatLng(AppConfig.defaultLat, AppConfig.defaultLng);
  }

  static String _nameFromAddress(String address) {
    final first = address.split(',').first.trim();
    return first.length >= 3 ? first : address.trim();
  }

  bool _canAddMore() {
    if (_stops.length >= 50) {
      showInfo(context, 'You can add up to 50 stops.');
      return false;
    }
    return true;
  }

  void _appendStop(Stop stop) {
    setState(() => _stops = [..._stops, stop]);
  }

  void _addStopFromResult(GeocodeResult result) {
    if (!_canAddMore()) return;
    setState(() {
      _stops = [
        ..._stops,
        Stop(
          uid: _nextUid++,
          name: result.name.isNotEmpty ? result.name : _nameFromAddress(result.address),
          address: result.address,
          lat: result.lat,
          lng: result.lng,
          source: result.source,
          placeId: result.placeId,
        ),
      ];
      _geocodeResults = [];
      _searchError = null;
      _searchedQuery = '';
      _searchCtrl.clear();
      // The add panel stays open so several stops can be added in a row.
    });
  }

  /// Adds whatever the rider typed, even if search found nothing. The server
  /// tries to locate it when the route is calculated, and the rider can drop a
  /// pin on it first by editing the stop.
  void _addTyped() {
    final text = _searchCtrl.text.trim();
    if (text.length < 2 || !_canAddMore()) return;
    _debounce?.cancel();
    _searchSeq++; // ignore any search still in flight
    setState(() {
      _stops = [
        ..._stops,
        Stop(uid: _nextUid++, name: _nameFromAddress(text), address: text),
      ];
      _geocodeResults = [];
      _searching = false;
      _searchError = null;
      _searchedQuery = '';
      _searchCtrl.clear();
    });
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    final q = query.trim();
    if (q.length < 2) {
      _searchSeq++;
      setState(() {
        _geocodeResults = [];
        _searching = false;
        _searchError = null;
        _searchedQuery = '';
      });
      return;
    }
    setState(() {}); // refresh the "use as typed" row
    _debounce = Timer(const Duration(milliseconds: 500), () => _runSearch(q));
  }

  Future<void> _runSearch(String query) async {
    if (!mounted) return;
    final seq = ++_searchSeq;
    final near = _searchBias;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await ApiService.instance.geocodeSearch(
        query,
        nearLat: near.latitude,
        nearLng: near.longitude,
      );
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _geocodeResults = results;
        _searchedQuery = query;
        _searching = false;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _geocodeResults = [];
        _searchedQuery = query;
        _searching = false;
        _searchError = e.isNetworkError || e.isTimeout
            ? e.message
            : 'Address search is unavailable right now.';
      });
    } catch (_) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searching = false;
        _searchError = 'Address search is unavailable right now.';
      });
    }
  }

  Future<void> _dropPin() async {
    if (!_canAddMore()) return;
    final bias = _searchBias;
    final result = await Navigator.of(context).push<GeocodeResult>(
      MaterialPageRoute<GeocodeResult>(
        builder: (_) => PinPickerScreen(initialPoint: _stops.any((s) => s.hasLocation) ? bias : null),
      ),
    );
    if (result != null && mounted) _addStopFromResult(result);
  }

  Future<void> _useMyLocation() async {
    if (!_canAddMore()) return;
    setState(() => _locating = true);
    try {
      final point = await LocationService.current();
      if (!mounted) return;
      _appendStop(
        Stop(
          uid: _nextUid++,
          name: 'My location',
          address: 'Current GPS position',
          lat: double.parse(point.latitude.toStringAsFixed(6)),
          lng: double.parse(point.longitude.toStringAsFixed(6)),
          source: 'gps',
        ),
      );
    } on LocationException catch (e) {
      if (mounted) showInfo(context, e.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pasteAddresses() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _PasteAddressesDialog(),
    );
    if (text == null || !mounted) return;
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.length >= 2)
        .toList();
    if (lines.isEmpty) return;
    final room = 50 - _stops.length;
    if (room <= 0) {
      showInfo(context, 'You can add up to 50 stops.');
      return;
    }
    final taken = lines.take(room).toList();
    setState(() {
      _stops = [
        ..._stops,
        for (final line in taken)
          Stop(uid: _nextUid++, name: _nameFromAddress(line), address: line),
      ];
    });
    if (taken.length < lines.length) {
      showInfo(context, 'Added $room stops. The limit is 50.');
    }
    unawaited(_resolveMissing());
  }

  /// Looks up each stop that has no map position yet (pasted addresses), one
  /// after another, and puts the best match on the map.
  Future<void> _resolveMissing() async {
    if (_resolving) return;
    setState(() => _resolving = true);
    final givenUp = <int>{};
    try {
      while (mounted) {
        final index = _stops.indexWhere((s) => !s.hasLocation && !givenUp.contains(s.uid));
        if (index == -1) break;
        final stop = _stops[index];
        givenUp.add(stop.uid);
        final near = _searchBias;
        try {
          final found = await ApiService.instance.geocodeSearch(
            stop.address.isNotEmpty ? stop.address : stop.name,
            limit: 1,
            nearLat: near.latitude,
            nearLng: near.longitude,
          );
          if (!mounted) return;
          final at = _stops.indexWhere((s) => s.uid == stop.uid);
          if (found.isNotEmpty && at != -1) {
            final hit = found.first;
            final updated = [..._stops];
            updated[at] = Stop(
              uid: stop.uid,
              name: stop.name,
              address: stop.address,
              lat: hit.lat,
              lng: hit.lng,
              source: hit.source,
              placeId: hit.placeId,
            );
            setState(() => _stops = updated);
          }
        } on ApiException {
          // Search is down: leave this one for the server to locate later.
        }
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _editStop(Stop stop) async {
    final c = context.c;
    final updated = await showModalBottomSheet<Stop>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (_) => _EditStopSheet(stop: stop),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _stops = [for (final s in _stops) s.uid == updated.uid ? updated : s];
    });
  }

  void _removeStop(int uid) {
    setState(() => _stops = _stops.where((s) => s.uid != uid).toList());
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      // ReorderableListView.onReorder reports the index *before* the dragged
      // item is taken out of the list, so a move down needs one less.
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _stops.removeAt(oldIndex);
      _stops.insert(newIndex, item);
    });
  }

  Future<void> _calculate() async {
    if (_stops.length < 2) return;
    if (!ApiService.instance.isAuthenticated) {
      showInfo(context, 'Log in again to calculate a route.');
      return;
    }
    setState(() => _calculating = true);
    final typed = _title.text.trim();
    final title = typed.isEmpty ? 'Untitled route' : typed;
    final preset = _optimise == 0 ? 'fastest' : _optimise == 2 ? 'shortest' : 'balanced';
    final openPath = _routeType == 0;

    try {
      final created = await ApiService.instance.createTrip(
        title: title,
        stops: _stops.map((s) => s.toApiJson()).toList(),
        openPath: openPath,
        preset: preset,
      );
      final tripId = created['id'].toString();

      // The server answers straight away with a queued run; wait for the real
      // route (order, distance, time and road geometry).
      final detail = await ApiService.instance.waitForRun(
        tripId,
        timeout: const Duration(seconds: 45),
      );
      if (!mounted) return;

      final run = detail['latest_run'];
      if (run is Map && run['status'] == 'failed') {
        setState(() => _calculating = false);
        unawaited(appState.refreshTrips());
        await _showProblem(
          'The route could not be calculated',
          (run['error_message'] as String?) ??
              'Something went wrong while ordering your stops. Please try again.',
        );
        return;
      }

      unawaited(appState.refreshTrips());
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => RouteScreen(
            tripId: tripId,
            title: title,
            initialDetail: detail,
          ),
        ),
        (route) => route.isFirst,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _calculating = false);
      if (e.unresolved.isNotEmpty) {
        await _showProblem(
          "We couldn't find some addresses",
          '${e.unresolved.join('\n')}\n\nTap the ⋯ on each of these stops, then '
              '"Set exact spot on map" to place a pin, or fix the spelling.',
        );
      } else {
        await _showProblem('Could not calculate the route', e.message);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _calculating = false);
      await _showProblem('Could not calculate the route', 'Something went wrong. Please try again.');
    }
  }

  Future<void> _showProblem(String title, String message) {
    final c = context.c;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(title, style: AppText.heading(18, c.ink)),
        content: SingleChildScrollView(
          child: Text(message, style: AppText.body(14.5, c.muted, height: 1.45)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_calculating) {
      return CalculatingView(
        stopCount: _stops.length,
        onBack: () => Navigator.of(context).popUntil((r) => r.isFirst),
      );
    }

    final c = context.c;
    final wide = isWide(context);
    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context, wide),
            if (widget.editing) _copyBanner(context),
            Expanded(child: wide ? _wideBody(context) : _narrowBody(context)),
          ],
        ),
      ),
      bottomNavigationBar: _actionBar(context, wide),
    );
  }

  // ---------------------------------------------------------------- header

  Widget _header(BuildContext context, bool wide) {
    final c = context.c;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: wide ? 55 : 12, vertical: wide ? 24 : 16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.arrow_back_rounded,
            label: 'Back to trips',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(widget.editing ? 'Edit a copy' : 'New route'),
                const SizedBox(height: 5),
                Text(
                  widget.editing ? 'Edit route' : 'Plan your route',
                  style: AppText.heading(wide ? 25 : 22, c.ink, height: 1.14),
                ),
                if (!isCompact(context)) ...[
                  const SizedBox(height: 5),
                  Text(
                    "Add your stops. We'll find the best order.",
                    style: AppText.body(13.8, c.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _copyBanner(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: c.blueSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.content_copy_rounded, size: 20, color: c.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: "You're editing a copy. ",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: '${widget.sourceTitle} stays unchanged.'),
                ],
              ),
              style: AppText.body(14, c.blue),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- bodies

  Widget _wideBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1110),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 64,
                child: SingleChildScrollView(child: _form(context)),
              ),
              const SizedBox(width: 30),
              Expanded(
                flex: 46,
                // Size the map to the space that is really there, so a short
                // window never overflows.
                child: LayoutBuilder(
                  builder: (context, constraints) => _mapPanel(
                    context,
                    math.max(220.0, math.min(560.0, constraints.maxHeight - 50)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _narrowBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _form(context),
          const SizedBox(height: 24),
          _mapPanel(context, 280),
        ],
      ),
    );
  }

  Widget _mapPanel(BuildContext context, double height) {
    final c = context.c;
    final markers = <MapMarkerData>[
      for (var i = 0; i < _stops.length; i++)
        if (_stops[i].hasLocation)
          MapMarkerData(
            point: LatLng(_stops[i].lat!, _stops[i].lng!),
            label: '${i + 1}',
            color: i == 0 ? c.accent : c.primary,
          ),
    ];
    final pending = _stops.length - markers.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.line),
            boxShadow: c.shadow,
          ),
          child: RouteMap(markers: markers, radius: 22, fitPadding: const EdgeInsets.all(44)),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 14,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: c.ink),
                  const SizedBox(width: 5),
                  Text(
                    markers.length == 1 ? '1 stop on the map' : '${markers.length} stops on the map',
                    style: AppText.body(12, c.ink, weight: FontWeight.w700),
                  ),
                ],
              ),
              if (pending > 0)
                Text(
                  _resolving
                      ? 'Locating $pending…'
                      : '$pending not placed yet (found when you calculate)',
                  style: AppText.body(12, c.warning),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- form

  Widget _form(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Trip title',
          controller: _title,
          hint: 'Optional — you can change this later',
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Delivery stops', style: AppText.heading(18, c.ink)),
            const SizedBox(width: 9),
            CountBadge('${_stops.length} of 50'),
            const Spacer(),
            if (!isCompact(context))
              Flexible(
                child: Text(
                  'The route will be reordered automatically',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(12.5, c.muted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _stopList(context),
        const SizedBox(height: 11),
        _addButton(context),
        if (_showAdd) _addPanel(context),
        const SizedBox(height: 32),
        _options(context),
      ],
    );
  }

  Widget _stopList(BuildContext context) {
    final c = context.c;
    return AppSurface(
      child: _stops.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No stops yet. Add your first stop below.',
                  style: AppText.body(14, c.muted),
                ),
              ),
            )
          : ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _stops.length,
              onReorder: _reorder,
              proxyDecorator: (child, index, animation) =>
                  Material(color: c.surface, elevation: 6, child: child),
              itemBuilder: (context, index) {
                final stop = _stops[index];
                return _StopRow(
                  key: ValueKey(stop.uid),
                  stop: stop,
                  index: index,
                  onEdit: () => _editStop(stop),
                  onRemove: () => _removeStop(stop.uid),
                );
              },
            ),
    );
  }

  Widget _addButton(BuildContext context) {
    final c = context.c;
    return DashedBorder(
      color: c.line,
      radius: 12,
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _showAdd = !_showAdd),
          child: SizedBox(
            height: 50,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_showAdd ? Icons.close_rounded : Icons.add_rounded,
                    size: 20, color: c.ink),
                const SizedBox(width: 9),
                Text('Add a stop',
                    style: AppText.body(15, c.ink, weight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _addPanel(BuildContext context) {
    final c = context.c;
    final wide = isWide(context);
    final typed = _searchCtrl.text.trim();
    final List<(IconData, String, String, VoidCallback?)> methods = [
      (Icons.location_on_outlined, 'Drop a pin', 'Choose on map', _dropPin),
      (
        Icons.my_location_rounded,
        'My location',
        _locating ? 'Finding you…' : 'Use GPS',
        _locating ? null : _useMyLocation,
      ),
      (Icons.content_copy_rounded, 'Paste addresses', 'Add many at once', _pasteAddresses),
    ];
    final noMatch = !_searching &&
        _searchError == null &&
        typed.length >= 2 &&
        _geocodeResults.isEmpty &&
        _searchedQuery == typed;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AppSurface(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              icon: Icons.search_rounded,
              placeholder: 'Type a street, area or landmark',
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              suffixIcon: _searching
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                      ),
                    )
                  : null,
            ),
            for (final r in _geocodeResults)
              InkWell(
                onTap: () => _addStopFromResult(r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          color: c.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.location_on_outlined, size: 20, color: c.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(15, c.ink, weight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(r.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(12, c.muted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.add_rounded, size: 20, color: c.muted),
                    ],
                  ),
                ),
              ),
            if (_searchError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 12, 5, 4),
                child: Text(
                  '$_searchError You can still add the address as typed, or drop a pin.',
                  style: AppText.body(13, c.danger, height: 1.4),
                ),
              )
            else if (noMatch)
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 12, 5, 4),
                child: Text(
                  'No match for "$typed". Add it as typed, or drop a pin on the spot.',
                  style: AppText.body(13, c.muted, height: 1.4),
                ),
              ),
            if (typed.length >= 2)
              InkWell(
                onTap: _addTyped,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          color: c.soft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.keyboard_return_rounded, size: 19, color: c.ink),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Use "$typed" as typed',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(15, c.ink, weight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text('Added without a map position. We try to find it when you calculate.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(12, c.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (typed.length >= 2) Divider(height: 1, color: c.line),
            const SizedBox(height: 12),
            if (wide)
              Row(
                children: [
                  for (var i = 0; i < methods.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                        child: _MethodButton(
                          icon: methods[i].$1,
                          title: methods[i].$2,
                          subtitle: methods[i].$3,
                          onTap: methods[i].$4,
                        ),
                      ),
                    ),
                ],
              )
            else
              Column(
                children: [
                  for (var i = 0; i < methods.length; i++)
                    Padding(
                      padding: EdgeInsets.only(bottom: i == methods.length - 1 ? 0 : 8),
                      child: _MethodButton(
                        icon: methods[i].$1,
                        title: methods[i].$2,
                        subtitle: methods[i].$3,
                        onTap: methods[i].$4,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _options(BuildContext context) {
    final c = context.c;
    final tag = '${_optimiseLabels[_optimise]} · ${_typeLabels[_routeType]}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Route options', style: AppText.heading(18, c.ink)),
            const SizedBox(width: 10),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(11.2, c.primary, weight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Optimise for', style: AppText.body(13.4, c.ink, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Segmented(
          selected: _optimise,
          onChanged: (i) => setState(() => _optimise = i),
          stackBelow: 460,
          items: const [
            SegmentItem(label: 'Fastest', sub: 'Save time', icon: Icons.schedule_rounded),
            SegmentItem(label: 'Balanced', sub: 'Best overall', icon: Icons.auto_awesome_rounded),
            SegmentItem(label: 'Shortest', sub: 'Fewer km', icon: Icons.map_outlined),
          ],
        ),
        const SizedBox(height: 20),
        Text('Route type', style: AppText.body(13.4, c.ink, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Segmented(
          selected: _routeType,
          onChanged: (i) => setState(() => _routeType = i),
          items: const [
            SegmentItem(label: 'One-way', sub: 'End at last stop', icon: Icons.arrow_forward_rounded),
            SegmentItem(label: 'Return to start', sub: 'Round trip', icon: Icons.alt_route_rounded),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- action bar

  Widget _actionBar(BuildContext context, bool wide) {
    final c = context.c;
    final button = AppButton(
      label: widget.editing ? 'Save as new route' : 'Find best route',
      icon: Icons.auto_awesome_rounded,
      expand: !wide,
      onPressed: _stops.length < 2 ? null : _calculate,
    );
    return Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.97),
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: wide ? 72 : 16, vertical: 12),
          child: wide
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${_stops.length} stops ready',
                            style: AppText.body(15, c.ink, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('${_optimiseLabels[_optimise]} · ${_typeLabels[_routeType]}',
                            style: AppText.body(12, c.muted)),
                      ],
                    ),
                    const SizedBox(width: 28),
                    button,
                  ],
                )
              : button,
        ),
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    super.key,
    required this.stop,
    required this.index,
    required this.onEdit,
    required this.onRemove,
  });

  final Stop stop;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isStart = index == 0;
    return Material(
      color: c.surface,
      child: InkWell(
        onTap: onEdit,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
          decoration: BoxDecoration(
            border: index == 0 ? null : Border(top: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Icon(Icons.drag_indicator_rounded, size: 22, color: AppColors.dragHandle),
                ),
              ),
              const SizedBox(width: 9),
              Container(
                width: 29,
                height: 29,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isStart ? c.accent : c.primary,
                  shape: BoxShape.circle,
                ),
                child: isStart
                    ? const Icon(Icons.home_outlined, size: 15, color: Colors.white)
                    : Text('${index + 1}',
                        style: AppText.body(12, Colors.white, weight: FontWeight.w800)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(14, c.ink, weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(stop.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(12, c.muted)),
                    if (isStart)
                      Text('START HERE',
                          style: AppText.body(10.7, c.accent,
                              weight: FontWeight.w700, letterSpacing: 0.55)),
                    if (!stop.hasLocation)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          'Not on the map yet. Tap to set the spot.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(11, c.warning, weight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              AppIconButton(
                icon: Icons.edit_outlined,
                label: 'Edit ${stop.name}',
                onPressed: onEdit,
              ),
              AppIconButton(
                icon: Icons.close_rounded,
                label: 'Remove ${stop.name}',
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Edit a stop's name, address and exact position.
class _EditStopSheet extends StatefulWidget {
  const _EditStopSheet({required this.stop});

  final Stop stop;

  @override
  State<_EditStopSheet> createState() => _EditStopSheetState();
}

class _EditStopSheetState extends State<_EditStopSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.stop.name);
  late final TextEditingController _address = TextEditingController(text: widget.stop.address);
  late double? _lat = widget.stop.lat;
  late double? _lng = widget.stop.lng;
  late String? _source = widget.stop.source;
  late String? _placeId = widget.stop.placeId;

  bool get _hasLocation => _lat != null && _lng != null;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.of(context).push<GeocodeResult>(
      MaterialPageRoute<GeocodeResult>(
        builder: (_) => PinPickerScreen(
          initialPoint: _hasLocation ? LatLng(_lat!, _lng!) : null,
          initialName: _name.text.trim(),
          initialAddress: _address.text.trim(),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _lat = result.lat;
      _lng = result.lng;
      _source = 'manual_pin';
      _placeId = null;
      if (_name.text.trim().isEmpty) _name.text = result.name;
      if (_address.text.trim().isEmpty) _address.text = result.address;
    });
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showInfo(context, 'Give the stop a name.');
      return;
    }
    Navigator.of(context).pop(
      Stop(
        uid: widget.stop.uid,
        name: name,
        address: _address.text.trim(),
        lat: _lat,
        lng: _lng,
        source: _source,
        placeId: _placeId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Edit stop', style: AppText.heading(18, c.ink)),
            const SizedBox(height: 16),
            AppTextField(label: 'Name', controller: _name),
            const SizedBox(height: 14),
            AppTextField(label: 'Address or landmark', controller: _address),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  _hasLocation ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                  size: 18,
                  color: _hasLocation ? c.primary : c.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _hasLocation
                        ? 'Position set (${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)})'
                        : 'No map position yet. Set the exact spot to be sure.',
                    style: AppText.body(13, _hasLocation ? c.muted : c.warning),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppButton(
              label: _hasLocation ? 'Change spot on map' : 'Set exact spot on map',
              icon: Icons.location_on_outlined,
              variant: ButtonVariant.secondary,
              expand: true,
              onPressed: _pickOnMap,
            ),
            const SizedBox(height: 10),
            AppButton(label: 'Save', expand: true, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

/// One address per line.
class _PasteAddressesDialog extends StatefulWidget {
  const _PasteAddressesDialog();

  @override
  State<_PasteAddressesDialog> createState() => _PasteAddressesDialogState();
}

class _PasteAddressesDialogState extends State<_PasteAddressesDialog> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AlertDialog(
      backgroundColor: c.surface,
      title: Text('Paste addresses', style: AppText.heading(18, c.ink)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Put one address on each line.', style: AppText.body(13.5, c.muted)),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 5,
              maxLines: 10,
              keyboardType: TextInputType.multiline,
              style: AppText.body(14.5, c.ink),
              decoration: InputDecoration(
                hintText: '12 Adeola Odeku St, Victoria Island\n5 Allen Avenue, Ikeja',
                hintStyle: AppText.body(14, AppColors.placeholder),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: const Text('Add stops'),
        ),
      ],
    );
  }
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: c.soft,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: c.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(12, c.ink, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(12, c.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
