import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/l10n.dart';
import '../core/units.dart';
import '../fusion/fusion_engine.dart';
import '../models/app_settings.dart';
import '../models/fused_weather.dart';
import '../models/geo.dart';
import '../models/nowcast.dart';
import '../models/weather_bundle.dart';
import '../nowcast/nowcast_engine.dart';
import '../nowcast/pressure_trend.dart';
import '../repositories/settings_repository.dart';
import '../repositories/weather_repository.dart';
import '../services/barometer_service.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/sources/met_norway_source.dart';
import '../services/sources/open_meteo_source.dart';
import '../services/sources/open_weather_source.dart';
import '../services/sources/weather_source.dart';

// ---------------------------------------------------------------- services

/// Overridden in main() with the real instance.
final sharedPrefsProvider = Provider<SharedPreferences>(
    (ref) => throw UnimplementedError('sharedPrefsProvider not overridden'));

final dioProvider = Provider<Dio>((ref) => Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      responseType: ResponseType.json,
    )));

/// THE place to register a new weather source.
final weatherSourcesProvider = Provider<List<WeatherSource>>((ref) {
  final dio = ref.watch(dioProvider);
  return [
    OpenMeteoSource(dio),
    MetNorwaySource(dio),
    OpenWeatherSource(dio),
  ];
});

final locationServiceProvider = Provider((ref) => LocationService());
final connectivityServiceProvider = Provider((ref) => ConnectivityService());
final barometerServiceProvider =
    Provider((ref) => BarometerService(ref.watch(sharedPrefsProvider)));
final geocodingServiceProvider =
    Provider((ref) => GeocodingService(ref.watch(dioProvider)));
final weatherRepositoryProvider = Provider((ref) => WeatherRepository(
      ref.watch(weatherSourcesProvider),
      CacheService(ref.watch(sharedPrefsProvider)),
    ));
final settingsRepositoryProvider =
    Provider((ref) => SettingsRepository(ref.watch(sharedPrefsProvider)));

// ---------------------------------------------------------------- settings

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsRepositoryProvider).load();

  void _set(AppSettings s) {
    state = s;
    ref.read(settingsRepositoryProvider).save(s);
  }

  void setTempUnit(TempUnit u) => _set(state.copyWith(tempUnit: u));
  void setWindUnit(WindUnit u) => _set(state.copyWith(windUnit: u));
  void setLocale(String code) => _set(state.copyWith(localeCode: code));
  void setThemeMode(ThemeMode m) => _set(state.copyWith(themeMode: m));

  void toggleSource(String id, bool enabled) {
    final next = {...state.enabledSources};
    enabled ? next.add(id) : next.remove(id);
    _set(state.copyWith(enabledSources: next));
  }

  /// The user explicitly chose GPS (this is what triggers the OS prompt).
  void useGps() => _set(state.copyWith(useGps: true, onboardingDone: true));

  void useManualPlace(Place p) => _set(
      state.copyWith(useGps: false, manualPlace: p, onboardingDone: true));
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

final stringsProvider =
    Provider<S>((ref) => S(ref.watch(settingsProvider.select((s) => s.localeCode))));

// ----------------------------------------------------------------- weather

enum AppErrorKind {
  noNetwork,
  locationServiceOff,
  locationDenied,
  locationDeniedForever,
  locationTimeout,
  locationUnknown,
  noLocationChosen,
  noSourcesEnabled,
  allSourcesFailed,
  unknown,
}

/// Everything the home screen shows, derived from one [WeatherBundle].
class WeatherView {
  final WeatherBundle bundle;
  final FusedWeather current;
  final List<FusedWeather> hourly;
  final Nowcast nowcast;

  const WeatherView(this.bundle, this.current, this.hourly, this.nowcast);

  /// Pure derivation: bundle → fusion → nowcast. Also used for cached data,
  /// evaluated at the time of the fetch so the result is reproducible.
  static WeatherView? fromBundle(WeatherBundle b) {
    const fusion = FusionEngine();
    final current = fusion.fuseCurrent(b.readings, b.fetchedAt);
    if (current == null) return null;
    final hourly = fusion.fuseHourly(b.readings, b.fetchedAt, hours: 12);
    final trend = b.barometerTrendHpa3h == null
        ? null
        : PressureTrend(b.barometerTrendHpa3h!, measured: true);
    final nowcast = const NowcastEngine()
        .build(current: current, hourly: hourly, barometerTrend: trend);
    return WeatherView(b, current, hourly, nowcast);
  }
}

class WeatherState {
  final WeatherView? view;
  final bool loading;
  final bool offline;
  final AppErrorKind? error;

  const WeatherState({this.view, this.loading = false, this.offline = false, this.error});

  /// Data older than two refresh periods is flagged as stale in the UI.
  bool isStale(DateTime now) =>
      view != null &&
      now.toUtc().difference(view!.bundle.fetchedAt) > const Duration(minutes: 20);
}

class WeatherController extends Notifier<WeatherState> {
  static const refreshInterval = Duration(minutes: 10);
  bool _busy = false;
  bool _queued = false;

  @override
  WeatherState build() {
    final timer = Timer.periodic(refreshInterval, (_) => refresh());
    final sub = ref.read(connectivityServiceProvider).onlineChanges.listen((online) {
      if (!online) {
        state = WeatherState(
            view: state.view, loading: state.loading, offline: true, error: state.error);
      } else if (state.offline || state.error != null) {
        refresh(); // Network is back: retry automatically.
      }
    });
    ref.onDispose(() {
      timer.cancel();
      sub.cancel();
    });
    // Refetch when sources or the chosen place change.
    ref.listen(settingsProvider.select((s) => s.fetchKey), (_, __) => refresh());

    final cached = ref.read(weatherRepositoryProvider).loadCached();
    Future.microtask(refresh);
    return WeatherState(
      view: cached == null ? null : WeatherView.fromBundle(cached),
      loading: true,
    );
  }

  void _fail(AppErrorKind kind, {bool offline = false}) {
    // Keep showing the last good data; only the banner changes.
    state = WeatherState(view: state.view, offline: offline, error: kind);
  }

  Future<void> refresh() async {
    if (_busy) {
      _queued = true;
      return;
    }
    _busy = true;
    state = WeatherState(
        view: state.view, loading: true, offline: state.offline, error: state.error);
    try {
      final settings = ref.read(settingsProvider);

      if (!await ref.read(connectivityServiceProvider).isOnline()) {
        _fail(AppErrorKind.noNetwork, offline: true);
        return;
      }

      // 1. Where?
      final Place place;
      if (settings.useGps) {
        try {
          final p = await ref.read(locationServiceProvider).current();
          place = Place(point: p, fromGps: true);
        } on LocationFailure catch (f) {
          _fail(switch (f.kind) {
            LocationFailureKind.serviceDisabled => AppErrorKind.locationServiceOff,
            LocationFailureKind.denied => AppErrorKind.locationDenied,
            LocationFailureKind.deniedForever => AppErrorKind.locationDeniedForever,
            LocationFailureKind.timeout => AppErrorKind.locationTimeout,
            LocationFailureKind.unknown => AppErrorKind.locationUnknown,
          });
          return;
        }
      } else if (settings.manualPlace != null) {
        place = settings.manualPlace!;
      } else {
        _fail(AppErrorKind.noLocationChosen);
        return;
      }

      // 2. Phone barometer (optional, never blocks the refresh).
      final now = DateTime.now().toUtc();
      final baro = ref.read(barometerServiceProvider);
      final stationHpa = await baro.readOnce();
      double? trendHpa3h;
      if (stationHpa != null) {
        // Only meaningful for where the phone is, i.e. in GPS mode.
        final history = await baro.addSample(
            stationHpa, now, settings.useGps ? place.point : null);
        if (settings.useGps) {
          trendHpa3h = PressureTrend.fromSamples(history, now)?.hpaPer3h;
        }
      }

      // 3. Weather sources — only a coarsened position leaves the device.
      final result = await ref
          .read(weatherRepositoryProvider)
          .fetchAll(place.point.rounded(2), settings.enabledSources);
      if (result.readings.isEmpty) {
        _fail(result.attempted == 0
            ? AppErrorKind.noSourcesEnabled
            : AppErrorKind.allSourcesFailed);
        return;
      }

      // 4. Fuse, nowcast, cache.
      final bundle = WeatherBundle(
        place: place,
        readings: result.readings,
        fetchedAt: now,
        failedSources: result.failed,
        stationPressureHpa: settings.useGps ? stationHpa : null,
        barometerTrendHpa3h: trendHpa3h,
      );
      final view = WeatherView.fromBundle(bundle);
      if (view == null) {
        _fail(AppErrorKind.allSourcesFailed);
        return;
      }
      await ref.read(weatherRepositoryProvider).saveCache(bundle);
      state = WeatherState(view: view);
    } catch (_) {
      _fail(AppErrorKind.unknown);
    } finally {
      _busy = false;
      if (_queued) {
        _queued = false;
        unawaited(refresh());
      }
    }
  }
}

final weatherControllerProvider =
    NotifierProvider<WeatherController, WeatherState>(WeatherController.new);
