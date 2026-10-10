import 'package:flutter/material.dart';

import '../models.dart';
import '../services/alert_service.dart';
import '../services/device_service.dart';
import '../services/session.dart';
import '../theme.dart';
import '../utils/time_format.dart';
import '../widgets/emergency_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = AlertService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: alerts,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _SectionHeader('Account'),
            const _AccountCard(),
            const _SectionHeader('Alerts'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_rounded),
                    title: const Text('Push notifications'),
                    subtitle: const Text(
                      'Alert this phone when gas is detected',
                    ),
                    value: alerts.alertsEnabled,
                    onChanged: alerts.setAlertsEnabled,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(
                      alerts.permissionAllowed == false
                          ? Icons.notifications_off_rounded
                          : Icons.verified_rounded,
                      color: alerts.permissionAllowed == false
                          ? GldColors.danger
                          : GldColors.safe,
                    ),
                    title: const Text('Notification permission'),
                    subtitle: Text(switch (alerts.permissionAllowed) {
                      true => 'Allowed',
                      false =>
                        'Blocked: allow it in phone Settings → Apps → GLD → Notifications',
                      null => 'Checking…',
                    }),
                  ),
                ],
              ),
            ),
            const _SectionHeader('Detector'),
            const _DetectorCard(),
            const _SectionHeader('Emergency numbers'),
            Card(
              child: Column(
                children: [
                  for (final e in emergencyNumbers)
                    ListTile(
                      leading: const Icon(
                        Icons.call_rounded,
                        color: GldColors.danger,
                      ),
                      title: Text(e.label),
                      subtitle: Text(e.number),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => callNumber(e.number),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'GLD · Gas Leak Detection · v1.0',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'This phone will stop getting gas alerts until someone signs in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) await Session.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = Session.instance.user;
    if (user == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: scheme.primary,
          child: Text(
            user.name[0].toUpperCase(),
            style: TextStyle(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${user.role} · @${user.username}'),
        trailing: OutlinedButton(
          onPressed: () => _confirmSignOut(context),
          child: const Text('Sign out'),
        ),
      ),
    );
  }
}

class _DetectorCard extends StatefulWidget {
  const _DetectorCard();

  @override
  State<_DetectorCard> createState() => _DetectorCardState();
}

class _DetectorCardState extends State<_DetectorCard> {
  final _state = DeviceService.watchState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: StreamBuilder<DeviceState>(
        stream: _state,
        builder: (context, snap) {
          final s = snap.data;
          final now = DateTime.now();
          final online = s?.isOnline(now) ?? false;
          return Column(
            children: [
              ListTile(
                leading: Icon(
                  online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: online ? GldColors.safe : GldColors.offline,
                ),
                title: Text('Detector $deviceId'),
                subtitle: Text(
                  s?.updatedAt == null
                      ? 'No data yet'
                      : '${online ? 'Online' : 'Offline'} · last update ${timeAgo(s!.updatedAt!, now)}',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Alarm level'),
                subtitle: Text(
                  s == null
                      ? '—'
                      : 'Gas level ${s.threshold} or more triggers an alert',
                ),
              ),
              const ExpansionTile(
                shape: Border(),
                leading: Icon(Icons.router_rounded),
                title: Text('Change the detector\'s WiFi'),
                childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Hold the BOOT button on the detector for 3 seconds.\n'
                    '2. On this phone, join the WiFi "GasDetector-Setup" (password gas12345).\n'
                    '3. Open 192.168.4.1 if the setup page does not open by itself.\n'
                    '4. Tap Configure WiFi, pick your network, enter its password, Save.\n'
                    '5. Switch this phone back to your normal WiFi.',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
