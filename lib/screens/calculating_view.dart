import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/misc.dart';

/// "Finding the best order for N stops…" loading screen.
class CalculatingView extends StatefulWidget {
  const CalculatingView({super.key, required this.stopCount, required this.onBack});

  final int stopCount;
  final VoidCallback onBack;

  @override
  State<CalculatingView> createState() => _CalculatingViewState();
}

class _CalculatingViewState extends State<CalculatingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final animWidth = math.min(420.0, screenWidth * 0.9);
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            children: [
              const Align(alignment: Alignment.centerLeft, child: Brand()),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: animWidth,
                          height: 280,
                          child: _animation(c),
                        ),
                        const SizedBox(height: 10),
                        const Eyebrow('Optimising your route'),
                        const SizedBox(height: 7),
                        Text(
                          'Finding the best order\nfor ${widget.stopCount} stops…',
                          textAlign: TextAlign.center,
                          style: AppText.heading(30, c.ink, height: 1.14),
                        ),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Text(
                            'Comparing road distance and travel time across Lagos. This usually takes a few seconds.',
                            textAlign: TextAlign.center,
                            style: AppText.body(15, c.muted, height: 1.6),
                          ),
                        ),
                        const SizedBox(height: 25),
                        _progress(c, screenWidth),
                        const SizedBox(height: 13),
                        AppButton(
                          label: "Keep working — tell me when it's ready",
                          variant: ButtonVariant.ghost,
                          onPressed: widget.onBack,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progress(AppColors c, double screenWidth) {
    return Container(
      width: math.min(360.0, screenWidth * 0.8),
      height: 6,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = (math.sin(_ctrl.value * 2 * math.pi - math.pi / 2) + 1) / 2;
          return Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.55 + 0.33 * t,
              child: Container(
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _animation(AppColors c) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final pulse = 1 + 0.1 * math.sin(_ctrl.value * 2 * math.pi).abs();
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CalcPainter(
                      phase: _ctrl.value * 44,
                      road: c.soft,
                      route: c.primary,
                    ),
                  ),
                ),
                Positioned(left: w * 0.07, bottom: h * 0.11, child: _pin('1', c.accent)),
                Positioned(left: w * 0.41, top: h * 0.48, child: _pin('2', c.primary)),
                Positioned(right: w * 0.07, top: h * 0.12, child: _pin('3', c.primary)),
                Positioned(
                  left: w * 0.58,
                  top: h * 0.31,
                  child: Transform.scale(
                    scale: pulse,
                    child: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: c.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.pedal_bike_rounded, size: 22, color: c.primary),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _pin(String label, Color color) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Text(label, style: AppText.body(11, Colors.white, weight: FontWeight.w800)),
    );
  }
}

final Path _calcPath = parseSvgPathData('M25 185C60 120 90 190 130 125s75-100 150-80');

class _CalcPainter extends CustomPainter {
  _CalcPainter({required this.phase, required this.road, required this.route});

  final double phase;
  final Color road;
  final Color route;

  @override
  void paint(Canvas canvas, Size size) {
    // Fit the 320x220 drawing inside the box (SVG "meet" behaviour).
    final scale = math.min(size.width / 320, size.height / 220);
    canvas.save();
    canvas.translate((size.width - 320 * scale) / 2, (size.height - 220 * scale) / 2);
    canvas.scale(scale);

    canvas.drawPath(
      _calcPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 28
        ..color = road,
    );
    canvas.drawPath(
      dashPathOf(_calcPath, 12, 10, phase),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 6
        ..color = route,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CalcPainter old) =>
      old.phase != phase || old.road != road || old.route != route;
}
