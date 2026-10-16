import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import 'buttons.dart';

// The design uses an illustrated map (SVG paths), not a real map. These
// widgets paint the same illustration. To use a real map, replace them with
// google_maps_flutter / flutter_map and keep the same pin styling.

class _MapData {
  _MapData({
    required this.width,
    required this.height,
    required List<String> roadPaths,
    String? waterPath,
    required String routePath,
  })  : roads = roadPaths.map(parseSvgPathData).toList(),
        water = waterPath == null ? null : parseSvgPathData(waterPath),
        route = parseSvgPathData(routePath);

  final double width;
  final double height;
  final List<Path> roads;
  final Path? water;
  final Path route;
}

final _MapData _miniMapData = _MapData(
  width: 600,
  height: 380,
  roadPaths: const [
    'M-20 80C90 120 150 60 260 100s170 30 370-10',
    'M40 380C80 260 160 250 220 130S360 30 420-30',
    'M-30 290c120-10 150 50 260 20s210-80 400-30',
    'M100-20c20 110 50 180 180 230s170 90 190 190',
    'M500-20c-80 100-80 160-30 220s20 120-20 200',
  ],
  routePath: 'M90 280C140 240 170 260 205 205S270 135 325 165s70 0 105-65',
);

final _MapData _resultMapData = _MapData(
  width: 900,
  height: 700,
  roadPaths: const [
    'M-20 100C130 160 220 40 390 130s310 20 560-20',
    'M90 720C100 500 230 460 310 260S520 10 620-30',
    'M-50 520c180-20 240 90 420 20s320-130 600-50',
    'M170-30c20 190 70 300 280 390s210 180 250 380',
    'M780-20c-150 190-120 300-40 390s20 230-70 370',
    'M-30 320c180 10 260-80 400-80s280 90 560 10',
  ],
  waterPath: 'M-30 660c190-90 270 20 430-40s310-10 530-100v210H-30Z',
  routePath: 'M130 555C210 480 260 525 315 405S410 245 510 300s120-30 185-145',
);

class _MapPainter extends CustomPainter {
  _MapPainter(this.data, this.routeColor);

  final _MapData data;
  final Color routeColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.mapBg);
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // Same behaviour as SVG preserveAspectRatio="xMidYMid slice".
    final scale = math.max(size.width / data.width, size.height / data.height);
    canvas.translate(
      (size.width - data.width * scale) / 2,
      (size.height - data.height * scale) / 2,
    );
    canvas.scale(scale);

    final road = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.mapRoad;
    for (var i = 0; i < data.roads.length; i++) {
      road.strokeWidth = i.isEven ? 7 : 3;
      canvas.drawPath(data.roads[i], road);
    }

    if (data.water != null) {
      canvas.drawPath(
        data.water!,
        Paint()..color = AppColors.mapWater.withValues(alpha: 0.75),
      );
    }

    final routeShadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 13
      ..color = Colors.white;
    canvas.drawPath(data.route, routeShadow);
    final routeLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7
      ..color = routeColor;
    canvas.drawPath(data.route, routeLine);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.data != data || old.routeColor != routeColor;
}

/// Teardrop map marker (rotated square with three round corners).
class MapPin extends StatelessWidget {
  const MapPin({
    super.key,
    required this.label,
    required this.color,
    this.size = 29,
    this.icon,
  });

  final String label;
  final Color color;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final r = Radius.circular(size / 2);
    return Transform.rotate(
      angle: -math.pi / 4,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.white, width: 3),
          borderRadius: BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomRight: r,
            bottomLeft: const Radius.circular(8),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x38000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Transform.rotate(
          angle: math.pi / 4,
          child: icon != null
              ? Icon(icon, size: 15, color: Colors.white)
              : Text(
                  label,
                  style: AppText.body(size > 32 ? 12.5 : 11, Colors.white,
                      weight: FontWeight.w800, height: 1),
                ),
        ),
      ),
    );
  }
}

class _MapLabel {
  const _MapLabel(this.text, this.dx, this.dy);

  final String text;
  final double dx;
  final double dy;
}

class _MapBase extends StatelessWidget {
  const _MapBase({
    required this.data,
    required this.pins,
    required this.labels,
    required this.pinSize,
    required this.largeStyle,
    this.overlay,
  });

  final _MapData data;
  final List<Offset> pins;
  final List<_MapLabel> labels;
  final double pinSize;

  /// Result map style: home icon on the first pin, dark last pin.
  final bool largeStyle;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _MapPainter(data, c.primary)),
            ),
            for (final label in labels)
              Positioned(
                left: w * label.dx,
                top: h * label.dy,
                child: Text(
                  label.text,
                  style: AppText.body(10, AppColors.mapLabel,
                      weight: FontWeight.w800, letterSpacing: 2.7),
                ),
              ),
            for (var i = 0; i < pins.length; i++)
              Positioned(
                left: pins[i].dx * w - pinSize / 2,
                top: pins[i].dy * h - pinSize / 2,
                child: MapPin(
                  label: '${i + 1}',
                  size: pinSize,
                  icon: largeStyle && i == 0 ? Icons.home_outlined : null,
                  color: i == 0
                      ? c.accent
                      : (largeStyle && i == pins.length - 1 ? c.ink : c.primary),
                ),
              ),
            if (overlay != null) overlay!,
          ],
        );
      },
    );
  }
}

/// Small preview map used on the planner and auth screens.
/// Give it a bounded height and width from the parent.
class MiniMap extends StatelessWidget {
  const MiniMap({super.key, this.radius = 22, this.pinCount = 4});

  final double radius;
  final int pinCount;

  static const List<Offset> _pins = [
    Offset(0.15, 0.73),
    Offset(0.33, 0.53),
    Offset(0.54, 0.42),
    Offset(0.72, 0.28),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.line),
        boxShadow: c.shadow,
      ),
      child: _MapBase(
        data: _miniMapData,
        pins: _pins.take(pinCount).toList(),
        labels: const [
          _MapLabel('IKEJA', 0.48, 0.18),
          _MapLabel('MARYLAND', 0.68, 0.63),
        ],
        pinSize: 29,
        largeStyle: false,
        overlay: Positioned(
          top: 14,
          right: 14,
          child: Column(
            children: [
              AppIconButton(
                icon: Icons.my_location_rounded,
                label: 'Fit all stops',
                elevated: true,
                onPressed: () => showInfo(context, 'Map controls are a placeholder'),
              ),
              const SizedBox(height: 7),
              AppIconButton(
                icon: Icons.layers_outlined,
                label: 'Map style',
                elevated: true,
                onPressed: () => showInfo(context, 'Map controls are a placeholder'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-bleed map for the route result screen.
class ResultMap extends StatelessWidget {
  const ResultMap({super.key, this.stopCount = 4, this.controlsBottom = 24});

  final int stopCount;
  final double controlsBottom;

  static const List<Offset> _pins = [
    Offset(0.14, 0.76),
    Offset(0.34, 0.57),
    Offset(0.51, 0.39),
    Offset(0.71, 0.20),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final count = math.max(2, math.min(stopCount, 4));
    return _MapBase(
      data: _resultMapData,
      pins: _pins.take(count).toList(),
      labels: const [
        _MapLabel('IKEJA', 0.48, 0.13),
        _MapLabel('MARYLAND', 0.71, 0.67),
      ],
      pinSize: 36,
      largeStyle: true,
      overlay: Positioned(
        right: 14,
        bottom: controlsBottom,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: c.surface,
              elevation: 3,
              shadowColor: Colors.black38,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => showInfo(context, 'Map styles are a placeholder'),
                child: SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.layers_outlined, size: 20, color: c.ink),
                        const SizedBox(width: 8),
                        Text('Standard', style: AppText.body(14, c.ink, weight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
            AppIconButton(
              icon: Icons.my_location_rounded,
              label: 'Fit route',
              elevated: true,
              onPressed: () => showInfo(context, 'Map controls are a placeholder'),
            ),
          ],
        ),
      ),
    );
  }
}
