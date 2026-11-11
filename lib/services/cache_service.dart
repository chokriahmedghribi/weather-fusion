import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_bundle.dart';

/// Last successful refresh, stored on the device only.
class CacheService {
  static const _key = 'weather_bundle_v1';
  final SharedPreferences prefs;
  CacheService(this.prefs);

  WeatherBundle? load() {
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return WeatherBundle.fromJson(
          (jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null; // Corrupt or old format: behave as if there is no cache.
    }
  }

  Future<void> save(WeatherBundle bundle) =>
      prefs.setString(_key, jsonEncode(bundle.toJson()));

  Future<void> clear() => prefs.remove(_key);
}
