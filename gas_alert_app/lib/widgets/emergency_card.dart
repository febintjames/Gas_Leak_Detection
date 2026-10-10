import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

/// Emergency numbers in India
const emergencyNumbers = [
  (number: '1906', label: 'LPG gas emergency'),
  (number: '101', label: 'Fire brigade'),
  (number: '112', label: 'National emergency'),
];

Future<void> callNumber(String number) =>
    launchUrl(Uri(scheme: 'tel', path: number));

/// "What to do now" steps and call buttons, shown while gas is detected
class EmergencyCard extends StatelessWidget {
  const EmergencyCard({super.key});

  static const _steps = [
    (Icons.flash_off_rounded, 'Do not switch lights or appliances on or off'),
    (Icons.local_fire_department_rounded, 'No flames, lighters or matches'),
    (Icons.window_rounded, 'Open doors and windows'),
    (Icons.propane_tank_rounded, 'Turn off the cylinder regulator if it is safe'),
    (Icons.directions_run_rounded, 'Leave the area and call for help from outside'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      color: GldColors.danger.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: GldColors.danger.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Do this now',
              style: text.titleMedium?.copyWith(
                color: GldColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final (icon, label) in _steps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: GldColors.danger),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label, style: text.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: GldColors.danger,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => callNumber(emergencyNumbers[0].number),
                icon: const Icon(Icons.call_rounded),
                label: Text(
                  'Call ${emergencyNumbers[0].label} · ${emergencyNumbers[0].number}',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final e in emergencyNumbers.skip(1)) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => callNumber(e.number),
                      child: Text('${e.label} ${e.number}', textAlign: TextAlign.center),
                    ),
                  ),
                  if (e != emergencyNumbers.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
