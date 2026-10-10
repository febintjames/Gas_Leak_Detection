import 'package:flutter/material.dart';

import '../theme.dart';

enum GldStatus { safe, leak, offline }

/// Big coloured banner at the top of the dashboard. Pulses while gas is detected.
class StatusHero extends StatefulWidget {
  const StatusHero({super.key, required this.status, required this.subtitle});

  final GldStatus status;
  final String subtitle;

  @override
  State<StatusHero> createState() => _StatusHeroState();
}

class _StatusHeroState extends State<StatusHero>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(StatusHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.status == GldStatus.leak) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, title) = switch (widget.status) {
      GldStatus.safe => (GldColors.safe, Icons.verified_user_rounded, 'All safe'),
      GldStatus.leak => (GldColors.danger, Icons.warning_rounded, 'Gas leak detected'),
      GldStatus.offline => (GldColors.offline, Icons.cloud_off_rounded, 'Detector offline'),
    };
    final text = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.25)!],
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 128,
            height: 128,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => CustomPaint(
                painter: _PulsePainter(
                  _pulse.value,
                  active: widget.status == GldStatus.leak,
                ),
                child: child,
              ),
              child: Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 48, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: text.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two rings that grow and fade around the icon
class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t, {required this.active});

  final double t;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;
    final center = size.center(Offset.zero);
    for (final offset in const [0.0, 0.5]) {
      final p = (t + offset) % 1.0;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: (1 - p) * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, 42 + p * 20, paint);
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t || old.active != active;
}
