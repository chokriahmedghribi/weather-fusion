import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class SettingsRepository {
  static const _key = 'settings_v1';
  final SharedPreferences prefs;
  SettingsRepository(this.prefs);

  AppSettings load() {
    final raw = prefs.getString(_key);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings s) => prefs.setString(_key, jsonEncode(s.toJson()));
}
