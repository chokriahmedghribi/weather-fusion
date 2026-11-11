import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/units.dart';
import '../state/providers.dart';
import 'city_search_screen.dart';
import 'privacy_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final sources = ref.watch(weatherSourcesProvider);
    final theme = Theme.of(context);

    Widget header(String key) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(s.t(key),
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
        );

    Widget segmented<T>(Map<T, String> options, T selected, void Function(T) onChanged) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: [
                for (final e in options.entries)
                  ButtonSegment<T>(value: e.key, label: Text(e.value)),
              ],
              selected: {selected},
              onSelectionChanged: (v) => onChanged(v.first),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.t('settings'))),
      body: ListView(
        children: [
          header('set_temperature'),
          segmented<TempUnit>(
            const {TempUnit.celsius: '°C', TempUnit.fahrenheit: '°F'},
            settings.tempUnit,
            notifier.setTempUnit,
          ),
          header('set_wind'),
          segmented<WindUnit>(
            {for (final u in WindUnit.values) u: s.t('unit_${u.name}')},
            settings.windUnit,
            notifier.setWindUnit,
          ),
          header('set_language'),
          segmented<String>(
            const {'ar': 'العربية', 'en': 'English'},
            settings.localeCode,
            notifier.setLocale,
          ),
          header('set_theme'),
          segmented<ThemeMode>(
            {
              ThemeMode.system: s.t('theme_system'),
              ThemeMode.light: s.t('theme_light'),
              ThemeMode.dark: s.t('theme_dark'),
            },
            settings.themeMode,
            notifier.setThemeMode,
          ),
          header('set_sources'),
          for (final src in sources)
            SwitchListTile(
              title: Text(src.displayName),
              subtitle: src.isConfigured ? null : Text(s.t('source_needs_key')),
              value: src.isConfigured && settings.enabledSources.contains(src.id),
              onChanged: src.isConfigured
                  ? (v) => notifier.toggleSource(src.id, v)
                  : null,
            ),
          header('set_location'),
          ListTile(
            leading: Icon(settings.useGps ? Icons.my_location : Icons.location_city),
            title: Text(settings.useGps
                ? s.t('my_location')
                : (settings.manualPlace?.name ?? s.na)),
            subtitle: Text(s.t('change_location')),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const CitySearchScreen())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(s.t('privacy_title')),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
          ),
        ],
      ),
    );
  }
}
