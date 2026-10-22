import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'buttons.dart';
import '../utils/polyline.dart';
import 'map_views.dart';

/// One pin on a [RouteMap].
class MapMarkerData {
  const MapMarkerData({
    required this.point,
    required this.label,
    required this.color,
    this.icon,
    this.dimmed = false,
    this.emphasised = false,
  });

  final LatLng point;

  /// Text inside the pin (usually the stop number). Ignored when [icon] is set.
  final String label;
  final Color color;
  final IconData? icon;

  /// Faded pin, used for stops that are already done.
  final bool dimmed;

  /// Slightly larger pin, drawn on top (the stop you are heading to).
  final bool emphasised;
}

class _TileStyle {
  const _TileStyle(
    this.name,
    this.url,
    this.attribution, {
    this.subdomains = const ['a', 'b', 'c'],
  });

  final String name;
  final String url;
  final String attribution;
  final List<String> subdomains;
}

List<_TileStyle> _tileStyles() {
  const token = AppConfig.mapboxToken;
  if (token.isNotEmpty) {
    return const [
      _TileStyle(
        'Standard',
        'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}?access_token=$token',
        '© Mapbox © OpenStreetMap',
      ),
      _TileStyle(
        'Satellite',
        'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/256/{z}/{x}/{y}?access_token=$token',
        '© Mapbox © OpenStreetMap © Maxar',
      ),
    ];
  }
  return const [
    _TileStyle(
      'Standard',
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      '© OpenStreetMap contributors',
    ),
    _TileStyle(
      'Light',
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
      '© OpenStreetMap contributors © CARTO',
      subdomains: ['a', 'b', 'c', 'd'],
    ),
  ];
}

/// Colours for the legs of a route (stop 1 -> 2 is the first colour, and so on).
const List<Color> legColors = [
  Color(0xFF0D684F), // green
  Color(0xFF3D77D3), // blue
  Color(0xFFF36F4B), // coral
  Color(0xFF8E5BD0), // purple
  Color(0xFFE0A100), // amber
  Color(0xFFD6458F), // pink
  Color(0xFF0891B2), // cyan
  Color(0xFFB4532A), // brown
  Color(0xFF5B8C00), // lime
  Color(0xFF4F46E5), // indigo
];

/// The base map tiles, shared by every map in the app so they look the same.
TileLayer buildBaseTileLayer([int styleIndex = 0]) {
  final styles = _tileStyles();
  final style = styles[styleIndex % styles.length];
  return TileLayer(
    urlTemplate: style.url,
    subdomains: style.subdomains,
    userAgentPackageName: AppConfig.mapUserAgent,
    maxNativeZoom: 19,
  );
}

/// The credit line the tile provider requires on screen.
String baseTileAttribution([int styleIndex = 0]) {
  final styles = _tileStyles();
  return styles[styleIndex % styles.length].attribution;
}

/// A real, pannable and zoomable map that shows the rider's stops and, when
/// available, the road route between them.
///
/// Tiles come from OpenStreetMap / CARTO, or from Mapbox when the app is built
/// with `--dart-define=MAPBOX_TOKEN=pk...` (see [AppConfig.mapboxToken]).
class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.markers,
    this.line = const [],
    this.lineIsApproximate = false,
    this.stopPoints = const [],
    this.largePins = false,
    this.fitPadding = const EdgeInsets.all(48),
    this.radius = 0,
    this.controlsBottom = 14,
    this.attributionBottom = 4,
    this.onMarkerTap,
  });

  final List<MapMarkerData> markers;

  /// The route to draw. Leave empty to draw only the pins.
  final List<LatLng> line;

  /// True when [line] is just straight lines between stops (no road geometry).
  final bool lineIsApproximate;

  /// The stops in visiting order. When given, each leg of [line] gets its own colour.
  final List<LatLng> stopPoints;

  final bool largePins;
  final EdgeInsets fitPadding;
  final double radius;
  final double controlsBottom;
  final double attributionBottom;
  final ValueChanged<int>? onMarkerTap;

  @override
  State<RouteMap> createState() => RouteMapState();
}

class RouteMapState extends State<RouteMap> {
  final MapController _controller = MapController();
  final List<_TileStyle> _styles = _tileStyles();
  bool _ready = false;
  int _styleIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<LatLng> get _fitPoints =>
      widget.line.length >= 2 ? widget.line : widget.markers.map((m) => m.point).toList();

  static bool _canFit(List<LatLng> points) {
    if (points.length < 2) return false;
    final first = points.first;
    return points.any(
      (p) =>
          (p.latitude - first.latitude).abs() > 1e-6 ||
          (p.longitude - first.longitude).abs() > 1e-6,
    );
  }

  static int _signature(List<LatLng> points) =>
      Object.hashAll(points.map((p) => Object.hash(p.latitude, p.longitude)));

  @override
  void didUpdateWidget(covariant RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.line.length >= 2
        ? oldWidget.line
        : oldWidget.markers.map((m) => m.point).toList();
    if (_signature(before) != _signature(_fitPoints)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) fitAll();
      });
    }
  }

  /// Zoom so every stop (and the whole route) is visible.
  void fitAll() {
    if (!_ready) return;
    final points = _fitPoints;
    if (points.isEmpty) {
      _controller.move(LatLng(AppConfig.defaultLat, AppConfig.defaultLng), 11);
    } else if (!_canFit(points)) {
      _controller.move(points.first, 15);
    } else {
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: widget.fitPadding,
          maxZoom: 17,
        ),
      );
    }
  }

  /// Centre the map on one place (for example when a stop is tapped in a list).
  void focusOn(LatLng point, {double zoom = 16}) {
    if (!_ready) return;
    _controller.move(point, zoom);
  }

  void _zoomBy(double delta) {
    if (!_ready) return;
    final camera = _controller.camera;
    _controller.move(camera.center, math.max(3.0, math.min(19.0, camera.zoom + delta)));
  }

  List<Polyline> _polylines(AppColors c) {
    final legs = widget.stopPoints.length >= 3
        ? splitLineByStops(widget.line, widget.stopPoints)
        : [widget.line];
    final multi = legs.length > 1;
    return [
      for (var i = 0; i < legs.length; i++)
        Polyline(
          points: legs[i],
          strokeWidth: 5,
          color: multi
              ? legColors[i % legColors.length].withValues(alpha: widget.lineIsApproximate ? 0.6 : 1)
              : (widget.lineIsApproximate ? c.primary.withValues(alpha: 0.55) : c.primary),
          borderStrokeWidth: 2.5,
          borderColor: Colors.white,
        ),
    ];
  }

  Marker _marker(MapMarkerData m, int index) {
    final base = widget.largePins ? 36.0 : 29.0;
    final size = base * (m.emphasised ? 1.25 : 1.0);
    Widget pin = MapPin(label: m.label, color: m.color, size: size, icon: m.icon);
    if (m.dimmed) pin = Opacity(opacity: 0.5, child: pin);
    final onTap = widget.onMarkerTap;
    if (onTap != null) {
      pin = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: pin,
      );
    }
    // The pin is a teardrop whose tip points down. Its tip sits ~0.7 x size
    // below its centre, so lift it by that much and the tip lands exactly on
    // the coordinate.
    return Marker(
      point: m.point,
      width: size * 3,
      height: size * 3,
      child: Transform.translate(
        offset: Offset(0, -size * 0.7),
        child: Center(child: pin),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = _styles[_styleIndex % _styles.length];
    final points = _fitPoints;
    final canFit = _canFit(points);
    final center = points.isNotEmpty
        ? points.first
        : LatLng(AppConfig.defaultLat, AppConfig.defaultLng);

    // Draw the emphasised pin last so it is never hidden by its neighbours.
    final order = List<int>.generate(widget.markers.length, (i) => i)
      ..sort((a, b) {
        final ea = widget.markers[a].emphasised ? 1 : 0;
        final eb = widget.markers[b].emphasised ? 1 : 0;
        return ea != eb ? ea - eb : a - b;
      });

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 330;
          return Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: points.length == 1 ? 15 : 11,
                    initialCameraFit: canFit
                        ? CameraFit.bounds(
                            bounds: LatLngBounds.fromPoints(points),
                            padding: widget.fitPadding,
                            maxZoom: 17,
                          )
                        : null,
                    minZoom: 3,
                    maxZoom: 19,
                    backgroundColor: AppColors.mapBg,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onMapReady: () => _ready = true,
                  ),
                  children: [
                    buildBaseTileLayer(_styleIndex),
                    if (widget.line.length >= 2)
                      PolylineLayer(polylines: _polylines(c)),
                    MarkerLayer(
                      markers: [for (final i in order) _marker(widget.markers[i], i)],
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 8,
                bottom: widget.attributionBottom,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      style.attribution,
                      style: AppText.body(9.5, const Color(0xFF333333)),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                bottom: widget.controlsBottom,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconButton(
                      icon: Icons.layers_outlined,
                      label: 'Map style: ${style.name}. Tap to change',
                      elevated: true,
                      onPressed: () => setState(() => _styleIndex++),
                    ),
                    const SizedBox(height: 7),
                    AppIconButton(
                      icon: Icons.center_focus_strong_rounded,
                      label: 'Fit all stops',
                      elevated: true,
                      onPressed: fitAll,
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 7),
                      AppIconButton(
                        icon: Icons.add_rounded,
                        label: 'Zoom in',
                        elevated: true,
                        onPressed: () => _zoomBy(1),
                      ),
                      const SizedBox(height: 7),
                      AppIconButton(
                        icon: Icons.remove_rounded,
                        label: 'Zoom out',
                        elevated: true,
                        onPressed: () => _zoomBy(-1),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
