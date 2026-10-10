import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/alarm_service.dart';
import '../services/device_service.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../utils/time_format.dart';
import '../widgets/emergency_card.dart';
import '../widgets/gas_gauge.dart';
import '../widgets/status_hero.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Stream<DeviceState> _state = DeviceService.watchState();
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    // Refresh "updated x ago" and the online check even when no new data arrives
    _tick = Timer.periodic(const Duration(seconds: 15), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  void _retry() => setState(() => _state = DeviceService.watchState());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DeviceState>(
      stream: _state,
      builder: (context, snap) {
        final now = DateTime.now();
        final state = snap.data;
        final online = state?.isOnline(now) ?? false;
        final status = !online
            ? GldStatus.offline
            : state!.gas
                ? GldStatus.leak
                : GldStatus.safe;

        return Scaffold(
          appBar: AppBar(
            title: const _Brand(),
            actions: [
              _OnlineChip(online: online),
              const SizedBox(width: 16),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (snap.hasError) ...[
                _ErrorCard(error: snap.error, onRetry: _retry),
                const SizedBox(height: 16),
              ],
              StatusHero(
                status: status,
                subtitle: _subtitle(state, online, snap.connectionState, now),
              ),
              const _StopAlarmButton(),
              if (status == GldStatus.leak) ...[
                const SizedBox(height: 16),
                const EmergencyCard(),
              ],
              const SizedBox(height: 16),
              _GasLevelCard(state: state),
              const SizedBox(height: 16),
              _SafetySystemCard(state: state, online: online),
            ],
          ),
        );
      },
    );
  }

  String _subtitle(DeviceState? s, bool online, ConnectionState c, DateTime now) {
    if (s == null) {
      return c == ConnectionState.waiting
          ? 'Connecting to your detector…'
          : 'No data yet. Switch on the detector.';
    }
    final seen = s.updatedAt == null ? null : timeAgo(s.updatedAt!, now);
    if (!online) {
      if (seen == null) return 'No data yet. Switch on the detector.';
      return s.gas
          ? 'Last reading showed a GAS LEAK ($seen). Check your home!'
          : 'Last seen $seen. Check the detector\'s power and WiFi.';
    }
    return s.gas
        ? 'Exhaust fan is ON and the gas valve is closed.'
        : 'Gas level is normal · updated $seen';
  }
}

/// Shown only while the siren is playing
class _StopAlarmButton extends StatelessWidget {
  const _StopAlarmButton();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AlarmService.instance,
      builder: (context, _) {
        if (!AlarmService.instance.isPlaying) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            onPressed: AlarmService.instance.stop,
            icon: const Icon(Icons.volume_off_rounded, size: 26),
            label: const Text('Stop alarm'),
          ),
        );
      },
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.sensors_rounded, color: scheme.onPrimary),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GLD', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(
              'Gas Leak Detection',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

class _OnlineChip extends StatelessWidget {
  const _OnlineChip({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? GldColors.safe : GldColors.offline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            online ? 'Online' : 'Offline',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _GasLevelCard extends StatelessWidget {
  const _GasLevelCard({required this.state});

  final DeviceState? state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final value = state?.value ?? 0;
    final threshold = state?.threshold ?? 400;
    final color = value >= threshold
        ? GldColors.danger
        : value >= threshold * 0.7
            ? GldColors.warning
            : GldColors.safe;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gas level', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text(
              'MQ-2 sensor reading',
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Center(child: GasGauge(value: value, threshold: threshold, color: color)),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend(color: GldColors.safe, label: 'Normal'),
                SizedBox(width: 16),
                _Legend(color: GldColors.warning, label: 'Rising'),
                SizedBox(width: 16),
                _Legend(color: GldColors.danger, label: 'Leak'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SafetySystemCard extends StatelessWidget {
  const _SafetySystemCard({required this.state, required this.online});

  final DeviceState? state;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final gas = state?.gas ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Safety system', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text(
              'Switched automatically by the detector',
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _DeviceTile(
                  icon: Icons.mode_fan_off_rounded,
                  activeIcon: Icons.air_rounded,
                  label: 'Exhaust fan',
                  value: online ? (gas ? 'ON' : 'OFF') : '—',
                  active: online && gas,
                ),
                const SizedBox(width: 8),
                _DeviceTile(
                  icon: Icons.lock_open_rounded,
                  activeIcon: Icons.lock_rounded,
                  label: 'Gas valve',
                  value: online ? (gas ? 'Closed' : 'Open') : '—',
                  active: online && gas,
                ),
                const SizedBox(width: 8),
                _DeviceTile(
                  icon: Icons.lightbulb_rounded,
                  activeIcon: Icons.lightbulb_outline_rounded,
                  label: 'Light',
                  value: online ? (gas ? 'OFF' : 'ON') : '—',
                  active: online && gas,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One output of the detector. "active" = switched by the safety response.
class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.value,
    required this.active,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = active ? GldColors.danger : scheme.primary;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(active ? activeIcon : icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: text.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(
              value,
              style: text.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (:title, :hint) = describeError(error);
    return Card(
      color: GldColors.warning.withValues(alpha: 0.12),
      child: ListTile(
        leading: const Icon(Icons.error_outline_rounded, color: GldColors.warning),
        title: Text(title),
        subtitle: Text(hint),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
    );
  }
}
