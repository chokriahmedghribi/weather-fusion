import 'dart:math' as math;

import '../core/weather_condition.dart';
import '../models/fused_weather.dart';
import '../models/nowcast.dart';
import 'pressure_trend.dart';

/// Rule-based short-term forecast (next 1–6 hours). Pure Dart.
///
/// Base = the fused hourly forecast of the sources.
/// Correction = the pressure tendency MEASURED by the phone barometer:
/// falling pressure raises the rain probability, rising pressure lowers it.
/// A tendency that only comes from the sources' own forecasts is displayed
/// but never applied as a correction (it is already inside those forecasts,
/// applying it again would count the same evidence twice).
class NowcastEngine {
  const NowcastEngine();

  static const maxLeadHours = 6;

  Nowcast build({
    required FusedWeather current,
    required List<FusedWeather> hourly,
    PressureTrend? barometerTrend,
  }) {
    final trend = barometerTrend ?? _modelTrend(current, hourly);
    final adjust = (trend != null && trend.measured)
        ? switch (trend.tendency) {
            PressureTendency.fallingFast => 25.0,
            PressureTendency.falling => 12.0,
            PressureTendency.steady => 0.0,
            PressureTendency.rising => -8.0,
            PressureTendency.risingFast => -15.0,
          }
        : 0.0;

    final steps = <NowcastStep>[];
    for (final f in hourly) {
      final lead =
          math.max(1, (f.time.difference(current.time).inMinutes / 60).ceil());
      if (lead > maxLeadHours) break;

      // The barometer says less and less about later hours.
      final decay = lead <= 3 ? 1.0 : 0.5;
      final basePop = f.precipProbPct;
      final pop =
          basePop == null ? null : (basePop + adjust * decay).clamp(0.0, 100.0);

      var condition = f.condition;
      if (pop != null && pop >= 60 && !condition.isPrecipitation) {
        final t = f.temperatureC;
        condition = (t != null && t <= 0.5)
            ? WeatherCondition.snow
            : WeatherCondition.rain;
      } else if (pop != null &&
          pop < 15 &&
          adjust < 0 &&
          (condition == WeatherCondition.drizzle ||
              condition == WeatherCondition.rain)) {
        condition = WeatherCondition.cloudy;
      }

      // Confidence shrinks with lead time; a barometer that contradicts the
      // sources lowers it, one that confirms them raises it slightly.
      var confidence = f.confidence * (1 - 0.05 * lead);
      if (adjust != 0 && basePop != null) {
        final confirms = (adjust > 0) == (basePop >= 40);
        confidence += confirms ? 0.05 : -0.10;
      }

      steps.add(NowcastStep(
        time: f.time,
        leadHours: lead,
        condition: condition,
        temperatureC: f.temperatureC,
        precipProbPct: pop?.toDouble(),
        windSpeedMs: f.windSpeedMs,
        windDirDeg: f.windDirDeg,
        confidence: confidence.clamp(0.05, 0.95).toDouble(),
      ));
    }

    return Nowcast(steps: steps, trend: trend, summary: _summarize(current, steps));
  }

  PressureTrend? _modelTrend(FusedWeather current, List<FusedWeather> hourly) {
    final p0 = current.pressureHpa;
    if (p0 == null) return null;
    for (final f in hourly) {
      final hours = f.time.difference(current.time).inMinutes / 60;
      if (hours >= 2.5 && f.pressureHpa != null) {
        return PressureTrend((f.pressureHpa! - p0) / hours * 3, measured: false);
      }
    }
    return null;
  }

  NowcastSummary _summarize(FusedWeather current, List<NowcastStep> steps) {
    if (steps.isEmpty) return NowcastSummary.unavailable;
    final wetNow = current.condition.isPrecipitation;
    var maxPop = 0.0;
    var maxWind = 0.0;
    for (final s in steps) {
      maxPop = math.max(maxPop, s.precipProbPct ?? 0);
      maxWind = math.max(maxWind, s.windSpeedMs ?? 0);
    }
    if (!wetNow) {
      final wetAhead = steps.any((s) => s.condition.isPrecipitation);
      if (maxPop >= 60 || (wetAhead && maxPop >= 40)) return NowcastSummary.rainLikely;
      if (maxPop >= 35 || wetAhead) return NowcastSummary.rainPossible;
    } else if (!steps.last.condition.isPrecipitation &&
        (steps.last.precipProbPct ?? 0) < 35) {
      return NowcastSummary.clearing;
    }
    final w0 = current.windSpeedMs;
    if (w0 != null && maxWind >= w0 + 4) return NowcastSummary.windIncreasing;
    return NowcastSummary.stable;
  }
}
