import 'package:flutter/material.dart' show ThemeMode;

import '../core/units.dart';
import 'geo.dart';

class AppSettings {
  final TempUnit tempUnit;
  final WindUnit windUnit;
  final String localeCode; // 'ar' or 'en'
  final ThemeMode themeMode;
  final Set<String> enabledSources;
  final bool onboardingDone;
  final bool useGps;
  final Place? manualPlace;

  const AppSettings({
    this.tempUnit = TempUnit.celsius,
    this.windUnit = WindUnit.kmh,
    this.localeCode = 'ar',
    this.themeMode = ThemeMode.system,
    this.enabledSources = const {'open_meteo', 'met_norway', 'open_weather'},
    this.onboardingDone = false,
    this.useGps = false,
    this.manualPlace,
  });

  /// Changes whenever something that requires a new fetch changes.
  String get fetchKey =>
      '${(enabledSources.toList()..sort()).join(',')}|$useGps|'
      '${manualPlace?.point.lat},${manualPlace?.point.lon}';

  AppSettings copyWith({
    TempUnit? tempUnit,
    WindUnit? windUnit,
    String? localeCode,
    ThemeMode? themeMode,
    Set<String>? enabledSources,
    bool? onboardingDone,
    bool? useGps,
    Place? manualPlace,
  }) =>
      AppSettings(
        tempUnit: tempUnit ?? this.tempUnit,
        windUnit: windUnit ?? this.windUnit,
        localeCode: localeCode ?? this.localeCode,
        themeMode: themeMode ?? this.themeMode,
        enabledSources: enabledSources ?? this.enabledSources,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        useGps: useGps ?? this.useGps,
        manualPlace: manualPlace ?? this.manualPlace,
      );

  Map<String, dynamic> toJson() => {
        'tempUnit': tempUnit.name,
        'windUnit': windUnit.name,
        'locale': localeCode,
        'theme': themeMode.name,
        'sources': enabledSources.toList(),
        'onboarded': onboardingDone,
        'useGps': useGps,
        'place': manualPlace?.toJson(),
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    const d = AppSettings();
    return AppSettings(
      tempUnit: TempUnit.values.asNameMap()[j['tempUnit']] ?? d.tempUnit,
      windUnit: WindUnit.values.asNameMap()[j['windUnit']] ?? d.windUnit,
      localeCode: j['locale'] as String? ?? d.localeCode,
      themeMode: ThemeMode.values.asNameMap()[j['theme']] ?? d.themeMode,
      enabledSources:
          (j['sources'] as List?)?.cast<String>().toSet() ?? d.enabledSources,
      onboardingDone: j['onboarded'] as bool? ?? false,
      useGps: j['useGps'] as bool? ?? false,
      manualPlace: j['place'] == null
          ? null
          : Place.fromJson((j['place'] as Map).cast<String, dynamic>()),
    );
  }
}
