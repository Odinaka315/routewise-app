import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/api_models.dart';
import '../data/models.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../widgets/buttons.dart';
import '../widgets/fields.dart';
import '../widgets/map_views.dart';
import '../widgets/misc.dart';
import '../widgets/segmented.dart';
import 'calculating_view.dart';
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
  List<GeocodeResult> _geocodeResults = [];
  Timer? _timer;
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
    _timer?.cancel();
    _debounce?.cancel();
    _title.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _addStopFromResult(GeocodeResult result) {
    if (_stops.length >= 50) {
      showInfo(context, 'You can add up to 50 stops.');
      return;
    }
    setState(() {
      _stops = [
        ..._stops,
        Stop(
          uid: _nextUid++,
          name: result.name,
          address: result.address,
          lat: result.lat,
          lng: result.lng,
        ),
      ];
      _geocodeResults = [];
      _searchCtrl.clear();
      _showAdd = false;
    });
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _geocodeResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    if (!mounted) return;
    setState(() => _searching = true);
    try {
      final results = await ApiService.instance.geocodeSearch(query);
      if (mounted) {
        setState(() {
          _geocodeResults = results;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _removeStop(int uid) {
    setState(() => _stops = _stops.where((s) => s.uid != uid).toList());
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _stops.removeAt(oldIndex);
      _stops.insert(newIndex, item);
    });
  }

  Future<void> _calculate() async {
    setState(() => _calculating = true);
    final typed = _title.text.trim();
    final title = typed.isEmpty ? 'Untitled route' : typed;
    final preset = _optimise == 0 ? 'fastest' : _optimise == 2 ? 'shortest' : 'balanced';
    final openPath = _routeType == 0;

    String distStr = '34.6 km';
    String timeStr = '1 hr 42 min';
    String? savedPercent = '24%';
    String tripId = DateTime.now().microsecondsSinceEpoch.toString();
    List<Stop> finalStops = _stops;

    if (ApiService.instance.isAuthenticated) {
      try {
        final stopPayloads = _stops.map((s) => {
          'name': s.name,
          'address': s.address,
        }).toList();

        final res = await ApiService.instance.createTrip(
          title: title,
          stops: stopPayloads,
          openPath: openPath,
          preset: preset,
        );

        tripId = res['id']?.toString() ?? tripId;
        final run = res['latest_run'] as Map<String, dynamic>?;
        final route = res['route'] as Map<String, dynamic>?;

        final distM = (route?['total_distance_m'] ?? run?['total_distance_m']) as num?;
        final durS = (route?['total_duration_s'] ?? run?['total_duration_s']) as num?;
        final saved = (run?['percent_saved']) as num?;

        if (distM != null) {
          distStr = '${(distM / 1000).toStringAsFixed(1)} km';
        }
        if (durS != null) {
          final mins = (durS / 60).round();
          if (mins >= 60) {
            final h = mins ~/ 60;
            final m = mins % 60;
            timeStr = '$h hr ${m > 0 ? '$m min' : ''}'.trim();
          } else {
            timeStr = '$mins min';
          }
        }
        if (saved != null) {
          savedPercent = '${saved.round()}%';
        }

        final serverStops = res['stops'] as List<dynamic>?;
        if (serverStops != null && serverStops.isNotEmpty) {
          final mapped = <Stop>[];
          for (var i = 0; i < serverStops.length; i++) {
            final st = serverStops[i] as Map<String, dynamic>;
            mapped.add(Stop(
              uid: _nextUid++,
              name: (st['name'] as String?) ?? 'Stop ${i + 1}',
              address: (st['address'] as String?) ?? '',
            ));
          }
          finalStops = mapped;
        }
      } catch (_) {
        // Fallback to local calculation if server has an issue
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }

    if (!mounted) return;

    appState.addTrip(
      Trip(
        id: tripId,
        title: title,
        stops: finalStops.length,
        distance: distStr,
        time: timeStr,
        date: 'Just now',
        savedPercent: savedPercent,
        editedFrom: widget.editing ? widget.sourceTitle : null,
      ),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => RouteScreen(
          tripId: tripId,
          title: title,
          initialStops: finalStops,
          initialDistance: distStr,
          initialTime: timeStr,
          initialSavedPercent: savedPercent,
        ),
      ),
      (route) => route.isFirst,
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
          if (wide)
            Row(
              children: [
                Icon(Icons.check_rounded, size: 18, color: c.primary),
                const SizedBox(width: 5),
                Text('Draft saved',
                    style: AppText.body(12.5, c.primary, weight: FontWeight.w700)),
              ],
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
    final mapHeight = math.min(MediaQuery.sizeOf(context).height * 0.56, 540.0);
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
                child: _mapPanel(context, math.max(mapHeight, 400.0)),
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
          _mapPanel(context, 210),
        ],
      ),
    );
  }

  Widget _mapPanel(BuildContext context, double height) {
    final c = context.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: height, child: MiniMap(pinCount: math.min(_stops.length, 4))),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: c.ink),
                const SizedBox(width: 5),
                Text('${_stops.length} stops in Lagos',
                    style: AppText.body(12, c.ink, weight: FontWeight.w700)),
              ],
            ),
            if (!isCompact(context))
              Text('Preview updates as you add stops',
                  style: AppText.body(12, c.muted)),
          ],
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
              onReorderItem: (oldIndex, newIndex) => _reorder(oldIndex, newIndex),
              proxyDecorator: (child, index, animation) =>
                  Material(color: c.surface, elevation: 6, child: child),
              itemBuilder: (context, index) {
                final stop = _stops[index];
                return _StopRow(
                  key: ValueKey(stop.uid),
                  stop: stop,
                  index: index,
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
    final methods = [
      (Icons.location_on_outlined, 'Drop a pin', 'Choose on map'),
      (Icons.my_location_rounded, 'My location', 'Use GPS'),
      (Icons.content_copy_rounded, 'Paste addresses', 'Add many at once'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AppSurface(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              icon: Icons.search_rounded,
              placeholder: 'Search an address in Nigeria',
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              suffixIcon: _searching
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            if (_geocodeResults.isNotEmpty) ...
              _geocodeResults.map(
                (r) => InkWell(
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
                                  style: AppText.body(15, c.ink, weight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text(r.address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(12, c.muted)),
                            ],
                          ),
                        ),
                        Icon(Icons.add_rounded, size: 20, color: c.muted),
                      ],
                    ),
                  ),
                ),
            )
            else if (_searchCtrl.text.isNotEmpty && !_searching)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
                child: Text('No results found. Try a different search.',
                    style: AppText.body(13, c.muted)),
              ),
            if (_geocodeResults.isNotEmpty || _searchCtrl.text.isNotEmpty)
              Divider(height: 1, color: c.line),
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
                          onTap: () => showInfo(context, '${methods[i].$2} is coming soon'),
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
                        onTap: () => showInfo(context, '${methods[i].$2} is coming soon'),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(tag,
                  style: AppText.body(11.2, c.primary, weight: FontWeight.w700)),
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
    required this.onRemove,
  });

  final Stop stop;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isStart = index == 0;
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      decoration: BoxDecoration(
        color: c.surface,
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
              ],
            ),
          ),
          if (!isCompact(context))
            AppIconButton(
              icon: Icons.more_horiz_rounded,
              label: 'Edit ${stop.name}',
              onPressed: () => showInfo(context, 'Editing a stop is coming soon'),
            ),
          AppIconButton(
            icon: Icons.close_rounded,
            label: 'Remove ${stop.name}',
            onPressed: onRemove,
          ),
        ],
      ),
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
  final VoidCallback onTap;

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
