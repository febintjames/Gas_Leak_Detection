import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Arc gauge for the MQ-2 reading. The alarm level sits at the top of the arc.
class GasGauge extends StatelessWidget {
  const GasGauge({
    super.key,
    required this.value,
    required this.threshold,
    required this.color,
  });

  final int value;
  final int threshold;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final scaleMax = threshold * 2;
    final fraction = scaleMax <= 0 ? 0.0 : (value / scaleMax).clamp(0.0, 1.0);

    return SizedBox(
      width: 190,
      height: 190,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fraction),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, f, _) => CustomPaint(
          painter: _GaugePainter(
            fraction: f,
            color: color,
            track: scheme.surfaceContainerHighest,
            tick: scheme.onSurfaceVariant,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: text.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  'alarm at $threshold',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.tick,
  });

  final double fraction;
  final Color color;
  final Color track;
  final Color tick;

  static const _start = 0.75 * math.pi; // 135 degrees: bottom left
  static const _sweep = 1.5 * math.pi; // 270 degrees around to bottom right
  static const _stroke = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final arcRect = (Offset.zero & size).deflate(_stroke);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, _start, _sweep, false, arc..color = track);
    if (fraction > 0) {
      canvas.drawArc(arcRect, _start, _sweep * fraction, false, arc..color = color);
    }

    // Alarm level mark at the middle of the scale
    final angle = _start + _sweep * 0.5;
    final dir = Offset(math.cos(angle), math.sin(angle));
    final center = arcRect.center;
    final r = arcRect.width / 2;
    canvas.drawLine(
      center + dir * (r - _stroke),
      center + dir * (r + _stroke),
      Paint()
        ..color = tick
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}
