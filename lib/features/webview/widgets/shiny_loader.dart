import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shiny spinning loader: a glowing ring with a gradient tail,
/// a bright spark at its head and a running highlight.
class ShinyLoader extends StatefulWidget {
  const ShinyLoader({
    super.key,
    this.size = 88,
    this.strokeWidth = 7,
    this.color = const Color(0xFFB388FF),
    this.highlightColor = Colors.white,
    this.duration = const Duration(milliseconds: 1100),
  });

  final double size;
  final double strokeWidth;
  final Color color;
  final Color highlightColor;
  final Duration duration;

  @override
  State<ShinyLoader> createState() => _ShinyLoaderState();
}

class _ShinyLoaderState extends State<ShinyLoader>
    with TickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: widget.duration)..repeat();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_spin, _pulse]),
        builder: (context, _) {
          final pulse = Curves.easeInOut.transform(_pulse.value);
          return SizedBox.square(
            dimension: widget.size,
            child: CustomPaint(
              painter: _ShinyRingPainter(
                rotation: _spin.value * 2 * math.pi,
                pulse: pulse,
                strokeWidth: widget.strokeWidth,
                color: widget.color,
                highlightColor: widget.highlightColor,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShinyRingPainter extends CustomPainter {
  _ShinyRingPainter({
    required this.rotation,
    required this.pulse,
    required this.strokeWidth,
    required this.color,
    required this.highlightColor,
  });

  final double rotation;
  final double pulse;
  final double strokeWidth;
  final Color color;
  final Color highlightColor;

  static const double _sweep = math.pi * 1.5; // arc length

  /// The arc starts a bit after angle 0 so the round cap and the blur of
  /// the tail don't cross the gradient seam (which would paint the bright
  /// end color there and produce a white streak).
  static const double _start = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2 - strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Soft background track ring.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color.withValues(alpha: 0.10),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: _sweep,
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.55),
        color,
        Color.lerp(color, highlightColor, 0.85)!,
      ],
      stops: const [0.0, 0.45, 0.85, 1.0],
    );

    // 2. Outer glow of the arc.
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth * 2.2
      ..shader = gradient.createShader(rect)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 6 * pulse);
    canvas.drawArc(rect, _start, _sweep - _start, false, glowPaint);

    // 3. Main arc.
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);
    canvas.drawArc(rect, _start, _sweep - _start, false, arcPaint);

    // 4. Thin white highlight along the inner edge of the arc.
    final shineRect = rect.deflate(strokeWidth * 0.18);
    final shinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth * 0.28
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: _sweep,
        colors: [
          highlightColor.withValues(alpha: 0),
          highlightColor.withValues(alpha: 0.9),
        ],
        stops: const [0.55, 1.0],
      ).createShader(shineRect);
    canvas.drawArc(shineRect, _start, _sweep - _start, false, shinePaint);

    // 5. Spark at the head of the arc.
    final head = Offset(
      center.dx + radius * math.cos(_sweep),
      center.dy + radius * math.sin(_sweep),
    );
    canvas.drawCircle(
      head,
      strokeWidth * (1.6 + 0.6 * pulse),
      Paint()
        ..color = highlightColor.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      head,
      strokeWidth * 0.55,
      Paint()..color = highlightColor,
    );
    _drawSparkle(canvas, head, strokeWidth * (2.2 + 1.2 * pulse));

    canvas.restore();
  }

  /// Four-pointed sparkle star.
  void _drawSparkle(Canvas canvas, Offset c, double r) {
    final t = r * 0.18;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + t, c.dy - t, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + t, c.dy + t, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - t, c.dy + t, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - t, c.dy - t, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = highlightColor.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_ShinyRingPainter old) =>
      old.rotation != rotation ||
      old.pulse != pulse ||
      old.color != color ||
      old.highlightColor != highlightColor ||
      old.strokeWidth != strokeWidth;
}
