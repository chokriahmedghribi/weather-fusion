import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'city_search_screen.dart';

/// Permission explanation + short privacy policy.
/// Shown once before any permission prompt, and later from Settings.
class PrivacyScreen extends ConsumerWidget {
  final bool onboarding;
  const PrivacyScreen({super.key, this.onboarding = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);

    Widget point(IconData icon, String key) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(s.t(key))),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.t('privacy_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(s.t('privacy_intro'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            point(Icons.my_location, 'privacy_location'),
            point(Icons.cloud_outlined, 'privacy_sharing'),
            point(Icons.phone_android, 'privacy_storage'),
            point(Icons.sensors, 'privacy_sensors'),
            point(Icons.block, 'privacy_none'),
            if (onboarding) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.my_location),
                label: Text(s.t('allow_location')),
                // The OS permission dialog appears on the first refresh.
                onPressed: () => ref.read(settingsProvider.notifier).useGps(),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.location_city),
                label: Text(s.t('enter_city_instead')),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const CitySearchScreen(popOnDone: true))),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
