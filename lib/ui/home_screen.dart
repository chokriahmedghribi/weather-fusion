import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n.dart';
import '../state/providers.dart';
import 'city_search_screen.dart';
import 'settings_screen.dart';
import 'widgets/confidence_card.dart';
import 'widgets/current_card.dart';
import 'widgets/details_card.dart';
import 'widgets/forecast_card.dart';
import 'widgets/wind_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(weatherControllerProvider);
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(weatherControllerProvider.notifier);
    final view = st.view;
    final now = DateTime.now();

    void openCitySearch() => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CitySearchScreen()));

    final title = view == null
        ? s.t('app_title')
        : view.bundle.place.fromGps
            ? s.t('my_location')
            : (view.bundle.place.name ?? s.t('app_title'));

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: s.t('choose_city'),
            icon: const Icon(Icons.location_city),
            onPressed: openCitySearch,
          ),
          if (st.loading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              tooltip: s.t('refresh'),
              icon: const Icon(Icons.refresh),
              onPressed: controller.refresh,
            ),
          IconButton(
            tooltip: s.t('settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            if (st.error != null)
              _ErrorBanner(
                kind: st.error!,
                s: s,
                onRetry: controller.refresh,
                onChooseCity: openCitySearch,
                onOpenAppSettings: ref.read(locationServiceProvider).openAppSettings,
                onOpenLocationSettings:
                    ref.read(locationServiceProvider).openLocationSettings,
              ),
            if (view == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 64),
                child: Center(
                  child: Text(
                    st.loading ? s.t('loading') : s.t('no_data'),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else ...[
              if (st.isStale(now) || st.offline)
                _StaleBanner(
                  text: '${s.t(st.offline ? 'offline_banner' : 'stale_banner')} '
                      '${s.t('last_update')}: ${s.ago(now.toUtc().difference(view.bundle.fetchedAt))}',
                ),
              CurrentCard(weather: view.current, s: s, tempUnit: settings.tempUnit),
              WindCard(weather: view.current, s: s, windUnit: settings.windUnit),
              ConfidenceCard(view: view, s: s, now: now),
              ForecastCard(
                nowcast: view.nowcast,
                hourly: view.hourly,
                s: s,
                tempUnit: settings.tempUnit,
                isDay: view.current.isDay ?? true,
              ),
              DetailsCard(
                weather: view.current,
                stationPressureHpa: view.bundle.stationPressureHpa,
                s: s,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  final String text;
  const _StaleBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.history, color: scheme.onTertiaryContainer),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: scheme.onTertiaryContainer))),
      ]),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final AppErrorKind kind;
  final S s;
  final VoidCallback onRetry;
  final VoidCallback onChooseCity;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onOpenLocationSettings;

  const _ErrorBanner({
    required this.kind,
    required this.s,
    required this.onRetry,
    required this.onChooseCity,
    required this.onOpenAppSettings,
    required this.onOpenLocationSettings,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLocation = switch (kind) {
      AppErrorKind.locationServiceOff ||
      AppErrorKind.locationDenied ||
      AppErrorKind.locationDeniedForever ||
      AppErrorKind.locationTimeout ||
      AppErrorKind.locationUnknown ||
      AppErrorKind.noLocationChosen =>
        true,
      _ => false,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.t('err_${kind.name}'),
                  style: TextStyle(color: scheme.onErrorContainer)),
            ),
          ]),
          Wrap(
            spacing: 4,
            children: [
              if (kind == AppErrorKind.locationDeniedForever)
                TextButton(onPressed: onOpenAppSettings, child: Text(s.t('open_app_settings'))),
              if (kind == AppErrorKind.locationServiceOff)
                TextButton(
                    onPressed: onOpenLocationSettings,
                    child: Text(s.t('open_location_settings'))),
              if (isLocation)
                TextButton(onPressed: onChooseCity, child: Text(s.t('choose_city'))),
              if (kind != AppErrorKind.noLocationChosen)
                TextButton(onPressed: onRetry, child: Text(s.t('retry'))),
            ],
          ),
        ],
      ),
    );
  }
}
