import 'package:flutter/material.dart';

import '../models.dart';
import '../services/device_service.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../utils/time_format.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Stream<List<GasEvent>> _events = DeviceService.watchEvents();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: StreamBuilder<List<GasEvent>>(
        stream: _events,
        builder: (context, snap) {
          if (snap.hasError) {
            final (:title, :hint) = describeError(snap.error);
            return _Message(
              icon: Icons.error_outline_rounded,
              title: title,
              body: hint,
              action: FilledButton(
                onPressed: () => setState(() => _events = DeviceService.watchEvents()),
                child: const Text('Retry'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snap.data!;
          if (events.isEmpty) {
            return const _Message(
              icon: Icons.history_rounded,
              title: 'No gas events yet',
              body: 'Leaks and all-clears from your detector will appear here.',
            );
          }

          final now = DateTime.now();
          final items = <Widget>[_Summary(events: events, now: now)];
          String? lastDay;
          for (final e in events) {
            final day = dayLabel(e.at, now);
            if (day != lastDay) {
              items.add(_DayHeader(day));
              lastDay = day;
            }
            items.add(_EventTile(event: e));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: items,
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.events, required this.now});

  final List<GasEvent> events;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final leaks = events.where((e) => e.isLeak).toList();
    final lastWeek = leaks
        .where((e) => now.difference(e.at) < const Duration(days: 7))
        .length;
    final lastLeak = leaks.isEmpty ? 'Never' : timeAgo(leaks.first.at, now);

    return Row(
      children: [
        _Stat(label: 'Leaks this week', value: '$lastWeek'),
        const SizedBox(width: 12),
        _Stat(label: 'Last leak', value: lastLeak),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                label,
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final GasEvent event;

  @override
  Widget build(BuildContext context) {
    final color = event.isLeak ? GldColors.danger : GldColors.safe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(
              event.isLeak ? Icons.warning_rounded : Icons.check_circle_rounded,
              color: color,
            ),
          ),
          title: Text(
            event.isLeak ? 'Gas leak detected' : 'Gas cleared',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('Gas level ${event.value}'),
          trailing: Text(clockTime(event.at)),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
