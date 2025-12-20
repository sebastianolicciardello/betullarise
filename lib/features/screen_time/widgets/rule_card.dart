import 'package:flutter/material.dart';
import '../../../model/screen_time_rule.dart';

class RuleCard extends StatelessWidget {
  final ScreenTimeRule rule;

  const RuleCard({super.key, required this.rule});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rule.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!rule.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Disattivata',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${rule.appPackages.length} app${rule.appPackages.length != 1 ? 's' : ''}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${rule.dailyTimeLimitMinutes} minuti al giorno',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  '${rule.penaltyPerMinuteExtra.toStringAsFixed(2)} punti/minuto extra',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // App preview (mostra le prime 3 app)
            if (rule.appPackages.isNotEmpty)
              Wrap(
                spacing: 8,
                children:
                    rule.appPackages.take(3).map((package) {
                      return Chip(
                        label: Text(
                          _getAppNameFromPackage(package),
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                      );
                    }).toList(),
              ),
            if (rule.appPackages.length > 3)
              Text(
                '+${rule.appPackages.length - 3} altre',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  String _getAppNameFromPackage(String package) {
    // Simple mapping for common apps - in a real app this would come from the service
    final packageMap = {
      'com.whatsapp': 'WhatsApp',
      'org.telegram.messenger': 'Telegram',
      'com.instagram.android': 'Instagram',
      'com.facebook.katana': 'Facebook',
      'com.google.android.youtube': 'YouTube',
      'com.spotify.music': 'Spotify',
      'com.twitter.android': 'Twitter',
      'com.tinder': 'Tinder',
      'com.netflix.mediaclient': 'Netflix',
      'com.google.android.gm': 'Gmail',
    };

    return packageMap[package] ?? package.split('.').last;
  }
}
