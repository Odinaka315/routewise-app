import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// "Routewise" logo: coral mark + wordmark.
class Brand extends StatelessWidget {
  const Brand({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = color ?? c.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.alt_route_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 10),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Route', style: AppText.heading(20, fg)),
              TextSpan(
                text: 'wise',
                style: AppText.heading(20, fg.withValues(alpha: 0.72),
                    weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small uppercase label above page titles.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppText.body(
        11,
        color ?? context.c.primary,
        weight: FontWeight.w800,
        letterSpacing: 1.45,
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, this.failed = false});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = failed ? c.danger : c.primary;
    final bg = failed ? c.dangerSoft : c.primarySoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            failed ? 'Failed' : 'Ready',
            style: AppText.body(11.5, fg, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: AppText.body(12, c.muted, weight: FontWeight.w700)),
    );
  }
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({super.key, required this.initials, this.size = 38});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.avatarBg,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: AppText.body(size * 0.36, AppColors.avatarFg, weight: FontWeight.w800),
      ),
    );
  }
}

/// Bordered, rounded card. Pass [onTap] to make it tappable (with ripple).
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 18,
    this.padding,
    this.color,
    this.borderColor,
    this.shadow = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow ? c.shadowSm : null,
      ),
      child: Material(
        color: color ?? c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: r,
          side: BorderSide(color: borderColor ?? c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: padding == null ? child : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

/// Wraps [child] with a dashed rounded border.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    required this.color,
    this.radius = 12,
    this.dash = 6,
    this.gap = 4,
    this.strokeWidth = 1.2,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedRRectPainter(color, radius, dash, gap, strokeWidth),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter(this.color, this.radius, this.dash, this.gap, this.strokeWidth);

  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dash != dash ||
      old.gap != gap ||
      old.strokeWidth != strokeWidth;
}

/// Vertical dotted connector used in the stop timeline. Give it a [height],
/// or place it inside an `Expanded` to fill the available height.
class DottedLine extends StatelessWidget {
  const DottedLine({super.key, this.height, required this.color});

  final double? height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 2,
      height: height,
      child: CustomPaint(painter: _DotsPainter(color)),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double y = 1; y < size.height; y += 4.5) {
      canvas.drawCircle(Offset(size.width / 2, y), 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => old.color != color;
}

/// Dashes [source] with the given dash / gap lengths. [phase] shifts the
/// dashes along the path (used to animate the "calculating" route).
Path dashPathOf(Path source, double dash, double gap, double phase) {
  final out = Path();
  final period = dash + gap;
  for (final metric in source.computeMetrics()) {
    double d = -period + (phase % period);
    while (d < metric.length) {
      final start = math.max(d, 0.0);
      final end = math.min(d + dash, metric.length);
      if (end > start) {
        out.addPath(metric.extractPath(start, end), Offset.zero);
      }
      d += period;
    }
  }
  return out;
}
