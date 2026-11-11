import 'dart:async';
import 'dart:convert';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/geo.dart';
import '../nowcast/pressure_trend.dart';

/// Reads the phone barometer (when the device has one) and keeps a short
/// local history so a pressure tendency can be computed.
///
/// Honest limits:
/// * Many phones have no barometer → [readOnce] returns null, UI says so.
/// * Samples are only taken while the app is open (no background service).
/// * This is STATION pressure at the phone's altitude, not sea-level
///   pressure, so it is used for the tendency only. History is reset when
///   the phone moves, because a change of altitude looks like weather.
class BarometerService {
  static const _samplesKey = 'baro_samples_v1';
  static const _pointKey = 'baro_point_v1';
  final SharedPreferences prefs;
  BarometerService(this.prefs);

  Future<double?> readOnce() async {
    try {
      final event = await barometerEventStream()
          .first
          .timeout(const Duration(seconds: 3));
      final p = event.pressure;
      // Physically plausible range on Earth's surface.
      return (p.isFinite && p > 300 && p < 1100) ? p : null;
    } catch (_) {
      return null; // No sensor, no permission, or no event in time.
    }
  }

  List<PressureSample> samples() {
    final raw = prefs.getString(_samplesKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => PressureSample.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Stores a sample and returns the updated history (last 6 hours).
  Future<List<PressureSample>> addSample(
      double hpa, DateTime now, GeoPoint? where) async {
    var list = samples();
    if (where != null) {
      final rawPoint = prefs.getString(_pointKey);
      if (rawPoint != null) {
        final last = GeoPoint.fromJson(
            (jsonDecode(rawPoint) as Map).cast<String, dynamic>());
        final movedKm = last.distanceKmTo(where);
        final climbedM = (last.altitudeM != null && where.altitudeM != null)
            ? (last.altitudeM! - where.altitudeM!).abs()
            : 0.0;
        if (movedKm > 0.5 || climbedM > 30) list = [];
      }
      await prefs.setString(_pointKey, jsonEncode(where.toJson()));
    }
    final cutoff = now.toUtc().subtract(const Duration(hours: 6));
    list = list.where((s) => s.time.isAfter(cutoff)).toList();
    if (list.isEmpty ||
        now.toUtc().difference(list.last.time) >= const Duration(minutes: 4)) {
      list.add(PressureSample(now, hpa));
    }
    await prefs.setString(
        _samplesKey, jsonEncode(list.map((s) => s.toJson()).toList()));
    return list;
  }
}
